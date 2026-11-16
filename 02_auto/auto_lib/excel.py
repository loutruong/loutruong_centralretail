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
    sheet_path: str
    sheet_name: str
    header_aliases: dict = field(default_factory=dict)
    strict_header_check: bool = False
    open_retries: int = 5
    open_retry_wait: float = 15
    load_wait: float = 3
    paste_chunk_rows: int = 50000
    refresh_after_paste: bool = True
    refresh_timeout: float = 600
    refresh_settle_wait: float = 2
    excel_exit_timeout: float = 120


def column_to_letter(col_num):
    string = ""
    while col_num > 0:
        col_num, remainder = divmod(col_num - 1, 26)
        string = chr(65 + remainder) + string
    return string


def prepare_data(df):
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
    import win32com.client as win32

    xl = win32.DispatchEx("Excel.Application")
    xl.Visible = False
    xl.DisplayAlerts = False
    xl.ScreenUpdating = False
    xl.EnableEvents = False
    try:
        xl.AutoRecover.Enabled = False
    except Exception:
        pass
    return xl


def excel_pid(xl):
    try:
        import ctypes
        import ctypes.wintypes

        pid = ctypes.wintypes.DWORD()
        ctypes.windll.user32.GetWindowThreadProcessId(xl.Hwnd, ctypes.byref(pid))
        return pid.value or None
    except Exception:
        return None


def process_alive(pid):
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
    try:
        xl.Calculation = mode
    except Exception as e:
        log(f"!! Could not change calculation mode: {e}")


def open_workbook(xl, path, retries, wait_seconds):
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
        wb.AutoSaveOn = False
    except Exception:
        pass
    log(f"Opened '{wb.Name}'.")
    return wb


def get_sheet(wb, name):
    try:
        return wb.Sheets(name)
    except Exception as e:
        raise LookupError(f"Could not find sheet '{name}' in '{wb.Name}'. Please check the name.") from e


def check_header(ws, columns, aliases, strict):
    header = ws.Range(ws.Cells(1, 1), ws.Cells(1, len(columns))).Value
    if not isinstance(header, (tuple, list)):
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
    try:
        for cn in wb.Connections:
            for kind in ("OLEDBConnection", "ODBCConnection"):
                try:
                    if getattr(cn, kind).Refreshing:
                        return True
                except Exception:
                    pass
    except Exception:
        pass
    return False


def refresh_workbook(xl, wb, timeout_seconds, settle_seconds):
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
    # no CoUninitialize() here: pywin32 owns COM init/release
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


def paste_to_sheet(df, job: ExcelJob) -> int:
    xl = wb = ws = None
    pid = None
    rows_processed = 0
    started = perf_counter()

    try:
        xl = start_excel()
        pid = excel_pid(xl)
        wb = open_workbook(xl, job.sheet_path, job.open_retries, job.open_retry_wait)
        sleep(job.load_wait)
        ws = get_sheet(wb, job.sheet_name)
        check_header(ws, df.columns, job.header_aliases, job.strict_header_check)

        set_calculation(xl, XL_CALCULATION_MANUAL)
        clear_sheet(ws)
        rows_processed = paste_dataframe(ws, prepare_data(df), job.paste_chunk_rows)
        set_calculation(xl, XL_CALCULATION_AUTOMATIC)
        xl.Calculate()
        log("Recalculated workbook.")

        if job.refresh_after_paste:
            refresh_workbook(xl, wb, job.refresh_timeout, job.refresh_settle_wait)

        wb.Save()
        log(f"Saved '{wb.Name}'.")
        log(f"SCRIPT_RESULT: SUCCESS; ROWS_PROCESSED: {rows_processed}; "
            f"ELAPSED_SECONDS: {perf_counter() - started:,.0f}")

    except Exception as e:
        log(f"SCRIPT_RESULT: FAILED; ERROR: {type(e).__name__}: {e}")
        # free the COM objects the traceback holds, so EXCEL.EXE can exit now
        exc, seen = e, set()
        while exc is not None and id(exc) not in seen:
            seen.add(id(exc))
            traceback.clear_frames(exc.__traceback__)
            exc = exc.__cause__ or exc.__context__
        raise

    finally:
        close_excel(xl, wb)
        ws = wb = xl = None
        gc.collect()
        wait_for_excel_exit(pid, job.excel_exit_timeout)

    return rows_processed
