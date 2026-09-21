"""DataFrame -> Excel tracker sheet (notebooks 01 - 03): Open > Delete > Write > Refresh > Save > Close.
win32com, ctypes and subprocess import inside the functions that need them, so this also works on Linux."""
import gc
import os
import traceback
from dataclasses import dataclass, field
from time import perf_counter, sleep

from .log import log

XL_CALCULATION_MANUAL = -4135
XL_CALCULATION_AUTOMATIC = -4105
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
STILL_ACTIVE = 259


@dataclass
class ExcelJob:
    """Which sheet to refill and how patient to be with Excel/OneDrive; sheet_path/sheet_name are required,
    every other field is a tuning knob, e.g. ExcelJob(..., refresh_timeout=900)."""

    sheet_path: str
    sheet_name: str
    header_aliases: dict = field(default_factory=dict)   # query column -> sheet header text
    strict_header_check: bool = False   # True = stop the run on a header mismatch
    open_retries: int = 5               # open attempts while OneDrive/another process holds the file
    open_retry_wait: float = 15         # seconds between open attempts
    load_wait: float = 3                # seconds to settle after opening
    paste_chunk_rows: int = 50000       # rows per COM call, keeps memory flat
    refresh_after_paste: bool = True    # refresh queries/pivots after the paste
    refresh_timeout: float = 600        # max seconds to wait for the refresh
    refresh_settle_wait: float = 2      # seconds to settle after the refresh
    excel_exit_timeout: float = 120     # seconds before force-closing EXCEL.EXE


# --- Helper functions ---
def column_to_letter(col_num):
    """Converts a column number (e.g., 1) into its Excel letter (e.g., 'A')."""
    string = ""
    while col_num > 0:
        col_num, remainder = divmod(col_num - 1, 26)
        string = chr(65 + remainder) + string
    return string


def prepare_data(df):
    """Makes the DataFrame safe for COM: dates as 'YYYY-MM-DD' text, NULL/NaN as blank cells,
    native Python types only, and text starting with '=' escaped so Excel never treats it as a formula."""
    df_clean = df.copy()
    for col in df_clean.select_dtypes(include=["datetime", "datetimetz"]).columns:
        df_clean[col] = df_clean[col].dt.strftime("%Y-%m-%d")
    df_clean = df_clean.astype(object).where(df_clean.notna(), "")
    for col in df_clean.columns:
        is_formula = df_clean[col].map(lambda v: isinstance(v, str) and v.startswith("="))
        if is_formula.any():
            df_clean.loc[is_formula, col] = "'" + df_clean.loc[is_formula, col]
    return df_clean


def start_excel():
    """Starts a dedicated, hidden Excel instance (DispatchEx = never hijacks an Excel the user has open)."""
    import win32com.client as win32

    xl = win32.DispatchEx("Excel.Application")
    xl.Visible = False
    xl.DisplayAlerts = False
    xl.ScreenUpdating = False
    xl.EnableEvents = False     # no Worksheet_Change / Workbook macros firing on every paste
    try:
        xl.AutoRecover.Enabled = False   # AutoRecover of a 400k-row workbook can block COM for many minutes
    except Exception:
        pass
    return xl


def excel_pid(xl):
    """Process id of this Excel instance (Windows only); None on any error, which switches the exit
    watchdog off."""
    try:
        import ctypes
        import ctypes.wintypes

        pid = ctypes.wintypes.DWORD()
        ctypes.windll.user32.GetWindowThreadProcessId(xl.Hwnd, ctypes.byref(pid))
        return pid.value or None
    except Exception:
        return None


def process_alive(pid):
    """True while the process with this id is still running (Windows only)."""
    import ctypes
    import ctypes.wintypes

    kernel32 = ctypes.windll.kernel32
    handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not handle:
        return False
    try:
        code = ctypes.wintypes.DWORD()
        kernel32.GetExitCodeProcess(handle, ctypes.byref(code))
        return code.value == STILL_ACTIVE
    finally:
        kernel32.CloseHandle(handle)


def wait_for_excel_exit(pid, timeout_seconds):
    """Waits until this EXCEL.EXE has exited, force-closing it after the timeout so a stuck Excel can
    never stall the batch (safe: the workbook is already saved and closed). Does nothing when the pid
    is unknown (not on Windows)."""
    if not pid:
        return
    import subprocess

    deadline = perf_counter() + timeout_seconds
    while process_alive(pid):
        if perf_counter() >= deadline:
            log(f"!! EXCEL.EXE (pid {pid}) still running {timeout_seconds}s after Quit - force closing it.")
            subprocess.run(["taskkill", "/PID", str(pid), "/F"], capture_output=True)
            return
        sleep(1)
    log(f"EXCEL.EXE (pid {pid}) has exited.")


def set_calculation(xl, mode):
    """Manual during clear + paste (recalculates once, not per chunk); automatic again before save."""
    try:
        xl.Calculation = mode
    except Exception as e:
        log(f"!! Could not change calculation mode: {e}")


def open_workbook(xl, path, retries, wait_seconds):
    """Opens the workbook, retrying while OneDrive/another process still holds the file; refuses a
    read-only copy."""
    if not os.path.isfile(path):
        raise FileNotFoundError(f"Workbook not found: {path}")
    retries = max(1, int(retries))
    for attempt in range(1, retries + 1):
        try:
            wb = xl.Workbooks.Open(path)
            break
        except Exception as e:
            if attempt == retries:
                raise
            log(f"!! Open attempt {attempt}/{retries} failed ({type(e).__name__}). "
                f"Retrying in {wait_seconds}s.")
            sleep(wait_seconds)
    if wb.ReadOnly:
        wb.Close(SaveChanges=False)
        raise PermissionError(f"Workbook opened READ-ONLY (locked by another user or process): {path}")
    try:
        wb.AutoSaveOn = False   # never let OneDrive AutoSave persist a half-finished run
    except Exception:
        pass                    # older Excel/non-cloud file: property doesn't exist, nothing to switch off
    log(f"Opened '{wb.Name}'.")
    return wb


def get_sheet(wb, name):
    """Grabs the specific worksheet object."""
    try:
        return wb.Sheets(name)
    except Exception as e:
        raise LookupError(f"Could not find sheet '{name}' in '{wb.Name}'. Please check the name.") from e


def check_header(ws, columns, aliases, strict):
    """Compares the sheet header (row 1) with the query columns (or their alias) so data never lands
    under the wrong header."""
    header = ws.Range(ws.Cells(1, 1), ws.Cells(1, len(columns))).Value
    if not isinstance(header, (tuple, list)):      # a 1-column range comes back as a scalar
        header = ((header,),)
    excel_header = [str(h).strip().upper() if h is not None else "" for h in header[0]]
    query_header = [str(c).strip().upper() for c in columns]
    aliases = {str(k).strip().upper(): str(v).strip().upper() for k, v in aliases.items()}
    mismatch = [q for q, x in zip(query_header, excel_header) if x not in (q, aliases.get(q))]
    if mismatch:
        message = (f"Header mismatch in sheet '{ws.Name}'.\n"
                   f"    Excel : {excel_header}\n"
                   f"    Query : {query_header}")
        if strict:
            raise ValueError(message)
        log(f"!! {message}")


def clear_sheet(ws):
    """Clears everything below the header row so no stale rows survive a shorter refresh."""
    used = ws.UsedRange
    last_row = used.Row + used.Rows.Count - 1
    last_col = used.Column + used.Columns.Count - 1
    if last_row < 2:
        log(f"Sheet '{ws.Name}' is empty or only contains a header row. No data was cleared.")
        return
    ws.Range(ws.Cells(2, 1), ws.Cells(last_row, last_col)).ClearContents()
    log(f"Cleared data from Row 2 to {last_row} (Columns A to {column_to_letter(last_col)}) in sheet "
        f"'{ws.Name}'.")


def paste_dataframe(ws, df_clean, chunk_rows):
    """Pastes the DataFrame from A2 downward in chunks. Returns the number of rows pasted."""
    num_rows, num_cols = df_clean.shape
    if num_rows == 0:
        log("DataFrame is empty. Nothing to paste.")
        return 0
    values = df_clean.values.tolist()
    for start in range(0, num_rows, chunk_rows):
        chunk = values[start:start + chunk_rows]
        first_row = 2 + start
        last_row = first_row + len(chunk) - 1
        ws.Range(ws.Cells(first_row, 1), ws.Cells(last_row, num_cols)).Value = chunk
        log(f"    pasted rows {first_row:,} - {last_row:,}")
    log(f"Successfully pasted {num_rows} rows into sheet '{ws.Name}', starting at A2.")
    return num_rows


def still_refreshing(wb):
    """True while any OLEDB/ODBC connection is still refreshing; False when Excel can't tell us."""
    try:
        for cn in wb.Connections:
            for kind in ("OLEDBConnection", "ODBCConnection"):
                try:
                    if getattr(cn, kind).Refreshing:
                        return True
                except Exception:
                    pass        # this connection type has no such property
    except Exception:
        pass                    # no Connections collection - nothing to wait for
    return False


def refresh_workbook(xl, wb, timeout_seconds, settle_seconds):
    """Refreshes all queries/pivots and waits until they are really finished, so Save() never happens
    mid-refresh."""
    wb.RefreshAll()
    xl.CalculateUntilAsyncQueriesDone()
    deadline = perf_counter() + timeout_seconds
    while still_refreshing(wb):
        if perf_counter() >= deadline:
            log(f"!! Background queries still running after {timeout_seconds}s. Continuing anyway.")
            break
        sleep(2)
    sleep(settle_seconds)
    log("Done Refresh")


def close_excel(xl, wb):
    """Closes the workbook WITHOUT saving (Save() runs only on success) and quits Excel; called from a
    finally block so a failed run never leaves a hidden EXCEL.EXE. No CoUninitialize(): pywin32 owns COM
    init/release, and calling it here would break any Excel call made later in the same kernel."""
    if wb is not None:
        try:
            wb.Close(SaveChanges=False)
        except Exception as e:
            log(f"!! Could not close the workbook cleanly: {e}")
    if xl is not None:
        try:
            xl.Quit()
        except Exception as e:
            log(f"!! Could not quit Excel cleanly: {e}")
    log("Excel closed.")


# --- The whole run ---
def paste_to_sheet(df, job: ExcelJob) -> int:
    """Replaces the sheet's data rows (row 2 down, header untouched) with df, refreshes, saves and closes;
    returns the row count and logs SCRIPT_RESULT. The workbook is saved only when every step succeeded."""
    xl = wb = ws = None
    pid = None
    rows_processed = 0
    started = perf_counter()

    try:
        # 1. Open
        xl = start_excel()
        pid = excel_pid(xl)
        wb = open_workbook(xl, job.sheet_path, job.open_retries, job.open_retry_wait)
        sleep(job.load_wait)
        ws = get_sheet(wb, job.sheet_name)
        check_header(ws, df.columns, job.header_aliases, job.strict_header_check)

        # 2. Delete + 3. Write, calculation frozen so Excel recalculates once, not after every chunk
        set_calculation(xl, XL_CALCULATION_MANUAL)
        clear_sheet(ws)
        rows_processed = paste_dataframe(ws, prepare_data(df), job.paste_chunk_rows)
        set_calculation(xl, XL_CALCULATION_AUTOMATIC)
        xl.Calculate()
        log("Recalculated workbook.")

        # 4. Refresh (after the paste, so pivots / queries see the new raw data)
        if job.refresh_after_paste:
            refresh_workbook(xl, wb, job.refresh_timeout, job.refresh_settle_wait)

        # 5. Save - the only place the workbook is ever saved
        wb.Save()
        log(f"Saved '{wb.Name}'.")
        log(f"SCRIPT_RESULT: SUCCESS; ROWS_PROCESSED: {rows_processed}; "
            f"ELAPSED_SECONDS: {perf_counter() - started:,.0f}")

    except Exception as e:
        log(f"SCRIPT_RESULT: FAILED; ERROR: {type(e).__name__}: {e}")
        # The traceback (and any chained cause) keeps the helper frames - and their COM objects - alive while
        # the notebook shows the error. Clearing them here lets EXCEL.EXE exit now instead of waiting for the
        # watchdog; the printed message and stack are unaffected.
        exc, seen = e, set()
        while exc is not None and id(exc) not in seen:
            seen.add(id(exc))
            traceback.clear_frames(exc.__traceback__)
            exc = exc.__cause__ or exc.__context__
        raise

    finally:
        # 6. Close
        close_excel(xl, wb)
        ws = wb = xl = None     # drop every COM reference so EXCEL.EXE can actually exit
        gc.collect()
        wait_for_excel_exit(pid, job.excel_exit_timeout)

    return rows_processed
