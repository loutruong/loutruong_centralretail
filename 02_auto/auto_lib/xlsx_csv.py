"""Monthly .xlsx -> UTF-8 CSV + BigQuery schema.json (notebook 04): Read > Standardize > Write > Schema >
Clean. Every cell is read as text and every schema column is STRING, so BigQuery always gets a safe landing
zone. After a successful run the output folder mirrors the workbooks - one CSV per monthly workbook, nothing
left over - so it never has to be emptied by hand."""
import hashlib
import json
import os
import re
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from time import perf_counter, sleep

import pandas as pd

from .log import log

# Vietnamese Đ/đ is a letter of its own, not D plus an accent, so stripping accents would drop it: it is
# mapped by hand (Ð/ð are the look-alike letters some exports use instead)
D_STROKE = str.maketrans({"Đ": "D", "đ": "d", "Ð": "D", "ð": "d"})
SWAP_ATTEMPTS = 5       # tries to swap a finished file in while OneDrive / antivirus still holds the old one
SWAP_WAIT = 1.0         # seconds between those tries


def hide_broken_zstandard():
    """pandas probes the optional `zstandard` lib on every to_csv(); the Anaconda copy imports but has no
    __version__, so probing raises ImportError. We never write .zst, so hide it here (called before every
    CSV write) and pandas behaves as if it were not installed."""
    try:
        import zstandard as _zstd
        if not getattr(_zstd, "__version__", None):
            raise ImportError("zstandard has no __version__")
    except Exception:
        sys.modules["zstandard"] = None


@dataclass
class CsvJob:
    """Which folder to convert and how; src_path is required, every other field is a tuning knob, e.g.
    CsvJob(src_path=src_path, skip_unchanged=True)."""

    src_path: str
    out_folder: str = "csv"                  # output sub folder, created if missing
    file_pattern: str = "*.xlsx"             # only monthly raw files
    month_pattern: str = r"\d{4}[-_]\d{2}"   # YYYY-MM in the file name, - or _ separator
    sheet_name: int | str = 0                # first sheet of every workbook
    month_col: str = "source_month"          # extra column: source file's month
    csv_encoding: str = "utf-8"              # what BigQuery expects
    schema_file: str = "schema.json"         # BigQuery schema (all STRING)
    skip_unchanged: bool = False             # True = convert only workbooks that changed since the last run
    remove_stale: bool = True                # True = delete CSVs whose workbook is gone; False = only warn
    state_file: str = "_convert_state.json"  # skip_unchanged only: what every CSV was built from


# --- Helper functions ---
def bq_name(col):
    """Converts a raw header (e.g., 'Mã Voucher') into a clean, SQL-friendly name (e.g., 'ma_voucher')."""
    s = unicodedata.normalize("NFKD", str(col).strip().translate(D_STROKE))
    s = s.encode("ascii", "ignore").decode("ascii")   # drop VN accents
    s = re.sub(r"[^0-9A-Za-z_]+", "_", s).strip("_").lower()
    return s if s and not s[0].isdigit() else "col_" + s


def schema_names(columns):
    """BigQuery names for the template columns, de-duplicated with _1, _2, ... suffixes that are never
    handed out twice."""
    names, used = [], set()
    for c in columns:
        base = name = bq_name(c)
        suffix = 0
        while name in used:
            suffix += 1
            name = f"{base}_{suffix}"
        used.add(name)
        names.append(name)
    return names


def file_month(xlsx, month_pattern=CsvJob.month_pattern):
    """Returns 'YYYY-MM' from the file name (e.g., '2025-04' from '2025_04-CRV_Raw'), or None if not found."""
    m = re.search(month_pattern, Path(xlsx).stem)
    return m.group().replace("_", "-") if m else None


def list_workbooks(src, file_pattern=CsvJob.file_pattern):
    """The workbooks to convert, in name order, without Excel's '~$' lock files."""
    return [f for f in sorted(Path(src).glob(file_pattern)) if not f.name.startswith("~$")]


def read_workbook(xlsx, sheet_name=CsvJob.sheet_name):
    """Reads the first sheet as text (no type guessing) and warns about blank headers."""
    df = pd.read_excel(xlsx, sheet_name=sheet_name, dtype=str).fillna("")
    unnamed = [c for c in df.columns if str(c).startswith("Unnamed:")]
    if unnamed:
        log(f"  !! {xlsx.name}: {len(unnamed)} blank header cell(s) -> {unnamed}")
    return df


def read_month(xlsx, month, job):
    """One monthly workbook as text plus its source-month column; a read error names the workbook."""
    try:
        df = read_workbook(xlsx, job.sheet_name)
    except Exception as e:
        raise RuntimeError(f"Could not read '{xlsx.name}': {e}") from e
    df[job.month_col] = month
    return df


def align_to_template(df, template, name):
    """Re-aligns a workbook's columns to the template: missing ones come back blank, extra ones are
    dropped, and both are reported."""
    if list(df.columns) == template:
        return df
    extra = [c for c in df.columns if c not in template]
    absent = [c for c in template if c not in df.columns]
    log(f"  !! {name}: columns differ - extra {extra}, missing {absent}. Re-aligned to the template.")
    return df.reindex(columns=template, fill_value="")


def swap_in(tmp_path, final_path):
    """os.replace with a little patience: OneDrive or an antivirus scan can hold the old file for a moment.
    A file that stays locked (e.g. open in Excel) still fails the run, with the usual PermissionError."""
    for attempt in range(1, SWAP_ATTEMPTS + 1):
        try:
            os.replace(tmp_path, final_path)
            return
        except PermissionError:
            if attempt == SWAP_ATTEMPTS:
                raise
            log(f"  !! '{final_path.name}' is in use (attempt {attempt}/{SWAP_ATTEMPTS}) - "
                f"retrying in {SWAP_WAIT:g}s")
            sleep(SWAP_WAIT)


def write_csv(df, csv_path, encoding=CsvJob.csv_encoding):
    """Writes to a temp file first, then swaps it in, so a crash can never leave a half-written CSV behind.
    The swap replaces a CSV that is already there: a month never needs deleting before it is converted."""
    hide_broken_zstandard()
    tmp_path = csv_path.with_suffix(".csv.tmp")
    df.to_csv(tmp_path, index=False, encoding=encoding, lineterminator="\n")
    swap_in(tmp_path, csv_path)


def write_schema(template, out, schema_file=CsvJob.schema_file, encoding=CsvJob.csv_encoding):
    """Builds the BigQuery schema (every column STRING, de-duplicated names) and returns the names; leaves
    an existing schema.json untouched when no workbook was read this run."""
    if template is None:
        log("No workbook was read this run. Existing schema.json (if any) is left untouched.")
        return []
    names = schema_names(template)
    schema = [{"name": n, "type": "STRING"} for n in names]
    (out / schema_file).write_text(json.dumps(schema, indent=2), encoding=encoding)
    log(f"Wrote {len(names)} columns to '{schema_file}' in '{out}'.")
    return names


def delete_files(paths):
    """Deletes the files it can and returns their names; one that is locked (open in Excel, still syncing) is
    reported and left for the next run."""
    deleted = []
    for path in paths:
        try:
            path.unlink()
            deleted.append(path.name)
        except OSError as e:
            log(f"  !! could not delete '{path.name}' ({type(e).__name__}: {e}) - close it if it is open; "
                f"the next run tries again.")
    return deleted


def sweep_output_folder(out, xlsx_files, month_pattern=CsvJob.month_pattern, remove=CsvJob.remove_stale):
    """Makes the folder mirror the workbooks: CSVs with no matching workbook (they'd be loaded to BigQuery as
    duplicates) and temp files an interrupted run left behind are deleted - or, when remove is False, the
    CSVs are only reported. Nothing else in the folder is touched, and nothing at all when no monthly workbook
    was found, so an empty or half-synced source folder can never wipe the CSVs. Returns the stale CSV names
    that are still in the folder."""
    monthly = [f for f in xlsx_files if file_month(f, month_pattern) is not None]
    expected_csv = {f"{f.stem}.csv".casefold() for f in monthly}
    stale = sorted(p for p in out.glob("*.csv") if p.is_file() and p.name.casefold() not in expected_csv)
    stale_csv = [p.name for p in stale]
    if not expected_csv:
        if stale_csv:
            log(f"!! No monthly workbook found - {len(stale_csv)} CSV file(s) in '{out.name}' left as is.")
        return stale_csv
    if not remove:
        if stale_csv:
            log(f"!! {len(stale_csv)} CSV file(s) in '{out.name}' have no matching workbook - "
                f"review before loading: {stale_csv}")
        return stale_csv

    deleted = delete_files(stale)
    if deleted:
        log(f"Removed {len(deleted)} stale CSV file(s) with no matching workbook: {deleted} - "
            f"if they were already uploaded (e.g. to the GCS lake), delete them there too.")
    temp_deleted = delete_files(sorted(p for p in out.glob("*.csv.tmp") if p.is_file()))
    if temp_deleted:
        log(f"Removed {len(temp_deleted)} temp file(s) left by an interrupted run: {temp_deleted}")
    return [name for name in stale_csv if name not in deleted]


# --- skip_unchanged: remembering which workbook version every CSV was built from ---
def job_signature(job):
    """Everything besides the workbook that shapes a CSV: the knobs, pandas, the Excel reader and this file
    itself. CSVs are only kept while it stays the same, so changing a knob, updating Anaconda or editing this
    module rebuilds every CSV once."""
    try:
        code = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()[:16]
    except OSError:
        code = "unknown"
    try:
        import openpyxl
        reader = openpyxl.__version__
    except Exception:
        reader = "unknown"
    return {"sheet_name": job.sheet_name, "month_col": job.month_col, "month_pattern": job.month_pattern,
            "csv_encoding": job.csv_encoding, "pandas": pd.__version__, "openpyxl": reader, "code": code}


def load_state(path, signature):
    """Last run's record, or None when there is none, it cannot be read, or it was written with other
    settings / another version of this file - then nothing is trusted and every CSV is rebuilt."""
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
        usable = (state["signature"] == signature and isinstance(state["template_source"], str)
                  and isinstance(state["template"], list) and len(state["template"]) > 0
                  and all(isinstance(c, str) for c in state["template"]) and isinstance(state["files"], dict))
    except (OSError, ValueError, KeyError, TypeError):
        return None
    return state if usable else None


def save_state(path, state):
    """Writes the record through a temp file, like the CSVs, so it is never half-written."""
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    tmp_path.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")
    swap_in(tmp_path, path)


def drop_state(path):
    """Deletes the record: a run that does not keep it up to date would leave it describing replaced CSVs."""
    try:
        path.unlink(missing_ok=True)
    except OSError as e:
        log(f"!! Could not delete '{path.name}' ({type(e).__name__}: {e}) - delete it by hand.")


def source_unchanged(record, source_stat):
    """True when the workbook still has exactly the size and modified time it had when its CSV was built."""
    try:
        return record["size"] == source_stat.st_size and record["mtime_ns"] == source_stat.st_mtime_ns
    except (KeyError, TypeError):
        return False


def csv_intact(record, csv_path):
    """True when the CSV is still in the folder at the size it was written (not deleted, not edited)."""
    try:
        return csv_path.is_file() and record["csv_size"] == csv_path.stat().st_size
    except (KeyError, TypeError, OSError):
        return False


def can_keep(state, xlsx, source_stat, csv_path):
    """True when the record says this CSV was built from exactly this workbook version and is still intact.
    The date of the CSV is never compared with the date of the workbook: a workbook replaced by an older
    copy has changed too."""
    try:
        record = state["files"][xlsx.name]
    except (KeyError, TypeError):
        return False
    return source_unchanged(record, source_stat) and csv_intact(record, csv_path)


# --- The whole run ---
def convert_folder(job: CsvJob) -> int:
    """Converts every monthly workbook of job.src_path into <out_folder>/<name>.csv (replacing the CSV that is
    already there), writes schema.json, removes what no longer belongs in the folder and returns the rows
    converted; any error is logged as SCRIPT_RESULT: FAILED and re-raised."""
    try:
        # --- Folder controller ---
        src = Path(job.src_path)
        if not src.is_dir():
            raise FileNotFoundError(f"Source folder not found: {job.src_path}")
        out = src / job.out_folder
        out.mkdir(exist_ok=True)
        xlsx_files = list_workbooks(src, job.file_pattern)
        log(f"Found {len(xlsx_files)} workbook(s) in '{src.name}'.")

        # --- Last run's record (skip_unchanged only) ---
        state_path = out / job.state_file
        track = job.skip_unchanged      # keep the record up to date during this run
        if track:
            signature = job_signature(job)
            state = load_state(state_path, signature)
        else:
            signature = state = None
            drop_state(state_path)      # every CSV is replaced below, so an old record would be wrong

        # --- Convert each workbook ---
        template = None      # first file's column layout; later files must match it
        total_rows = 0
        converted = []
        kept = []
        skipped = []
        started = perf_counter()
        for xlsx in xlsx_files:
            month = file_month(xlsx, job.month_pattern)
            if month is None:
                log(f"  !! {xlsx.name}: no YYYY-MM in name, skipping")
                skipped.append(xlsx.name)
                continue

            csv_path = out / f"{xlsx.stem}.csv"
            source_stat = xlsx.stat()    # taken before the read, so a save during the run is caught next time
            df = None

            if template is None:         # first workbook: its columns are the template
                if can_keep(state, xlsx, source_stat, csv_path) and state["template_source"] == xlsx.name:
                    template = state["template"]     # same workbook as last run: no need to read it again
                else:
                    df = read_month(xlsx, month, job)
                    template = list(df.columns)
                    if track and not all(isinstance(c, str) for c in template):
                        log("  !! a column header is not text - skip_unchanged is ignored for this folder")
                        track, state = False, None
                        drop_state(state_path)
                    elif state is not None and state["template"] != template:
                        log("  !! the column layout changed since the last run - every CSV is rebuilt")
                        state = None
                    if track and (state is None or state["template_source"] != xlsx.name):
                        if state is None:
                            state = {"signature": signature, "template": template, "files": {}}
                        state["template_source"] = xlsx.name
                        save_state(state_path, state)   # before any CSV is replaced: it never overclaims

            if can_keep(state, xlsx, source_stat, csv_path):
                log(f"  {xlsx.name:28} unchanged, CSV kept")
                kept.append(xlsx.name)
                continue

            if df is None:
                df = read_month(xlsx, month, job)
            df = align_to_template(df, template, xlsx.name)

            if state is not None and xlsx.name in state["files"]:
                del state["files"][xlsx.name]           # its CSV is about to be replaced
                save_state(state_path, state)
            write_csv(df, csv_path, job.csv_encoding)
            if state is not None:
                state["files"][xlsx.name] = {"size": source_stat.st_size, "mtime_ns": source_stat.st_mtime_ns,
                                             "csv_size": csv_path.stat().st_size, "rows": len(df)}
                save_state(state_path, state)
            log(f"  {xlsx.name:28} {len(df):>8,} rows")
            total_rows += len(df)
            converted.append(xlsx.name)

        kept_note = f", kept {len(kept)} unchanged" if job.skip_unchanged else ""
        log(f"Converted {len(converted)} file(s){kept_note}, skipped {len(skipped)} file(s) in "
            f"{perf_counter() - started:,.1f}s.")
        if converted and kept:
            log(f"CSV files written this run: {[Path(name).stem + '.csv' for name in converted]}")

        # --- Schema + clean-up: the folder ends up holding exactly one CSV per monthly workbook ---
        names = write_schema(template, out, job.schema_file, job.csv_encoding)
        sweep_output_folder(out, xlsx_files, job.month_pattern, job.remove_stale)
        if state is not None:
            gone = [name for name in state["files"] if name not in converted and name not in kept]
            if gone:                     # workbooks that were removed or renamed since the last run
                for name in gone:
                    del state["files"][name]
                save_state(state_path, state)

        # --- Summary ---
        if converted:
            log(f"Done -> {out}")
            log(f"Columns: {', '.join(names)}")
            log(f"SCRIPT_RESULT: SUCCESS; ROWS_PROCESSED: {total_rows}")
        else:
            log("Every CSV is already up to date." if kept else "Nothing was converted.")
            log("SCRIPT_RESULT: SUCCESS; ROWS_PROCESSED: 0")
        return total_rows

    except Exception as e:
        log(f"SCRIPT_RESULT: FAILED; ERROR: {type(e).__name__}: {e}")
        raise
