"""Monthly .xlsx -> UTF-8 CSV + BigQuery schema.json (notebook 04): Read > Standardize > Write > Schema.
Every cell is read as text and every schema column is STRING, so BigQuery always gets a safe landing zone."""
import json
import os
import re
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from time import perf_counter

import pandas as pd

from .log import log


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
    skip_unchanged: bool = False             # True = skip if the CSV is already newer than the .xlsx


# --- Helper functions ---
def bq_name(col):
    """Converts a raw header (e.g., 'Mã Voucher') into a clean, SQL-friendly name (e.g., 'ma_voucher')."""
    s = unicodedata.normalize("NFKD", str(col).strip())
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


def is_up_to_date(xlsx, csv_path):
    """True when the CSV already exists and is newer than the workbook, so the workbook can be skipped."""
    return csv_path.exists() and csv_path.stat().st_mtime >= xlsx.stat().st_mtime


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


def align_to_template(df, template, name):
    """Re-aligns a workbook's columns to the template: missing ones come back blank, extra ones are
    dropped, and both are reported."""
    if list(df.columns) == template:
        return df
    extra = [c for c in df.columns if c not in template]
    absent = [c for c in template if c not in df.columns]
    log(f"  !! {name}: columns differ - extra {extra}, missing {absent}. Re-aligned to the template.")
    return df.reindex(columns=template, fill_value="")


def write_csv(df, csv_path, encoding=CsvJob.csv_encoding):
    """Writes to a temp file first, then swaps it in, so a crash can never leave a half-written CSV behind."""
    hide_broken_zstandard()
    tmp_path = csv_path.with_suffix(".csv.tmp")
    df.to_csv(tmp_path, index=False, encoding=encoding, lineterminator="\n")
    os.replace(tmp_path, csv_path)


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


def warn_stale_csv(out, xlsx_files, month_pattern=CsvJob.month_pattern):
    """Warns about CSVs with no matching workbook (they'd be loaded to BigQuery as duplicates)."""
    expected_csv = {f"{f.stem}.csv" for f in xlsx_files if file_month(f, month_pattern) is not None}
    stale_csv = sorted(p.name for p in out.glob("*.csv") if p.name not in expected_csv)
    if stale_csv:
        log(f"!! {len(stale_csv)} CSV file(s) in '{out.name}' have no matching workbook - "
            f"review before loading: {stale_csv}")
    return stale_csv


# --- The whole run ---
def convert_folder(job: CsvJob) -> int:
    """Converts every monthly workbook of job.src_path into <out_folder>/<name>.csv, writes schema.json and
    returns the rows converted; any error is logged as SCRIPT_RESULT: FAILED and re-raised."""
    try:
        # --- Folder controller ---
        src = Path(job.src_path)
        if not src.is_dir():
            raise FileNotFoundError(f"Source folder not found: {job.src_path}")
        out = src / job.out_folder
        out.mkdir(exist_ok=True)
        xlsx_files = list_workbooks(src, job.file_pattern)
        log(f"Found {len(xlsx_files)} workbook(s) in '{src.name}'.")

        # --- Convert each workbook ---
        template = None      # first file's column layout; later files must match it
        total_rows = 0
        converted = []
        skipped = []
        started = perf_counter()
        for xlsx in xlsx_files:
            month = file_month(xlsx, job.month_pattern)
            if month is None:
                log(f"  !! {xlsx.name}: no YYYY-MM in name, skipping")
                skipped.append(xlsx.name)
                continue

            csv_path = out / f"{xlsx.stem}.csv"
            if job.skip_unchanged and template is not None and is_up_to_date(xlsx, csv_path):
                log(f"  {xlsx.name:28} up to date, skipped")
                skipped.append(xlsx.name)
                continue

            try:
                df = read_workbook(xlsx, job.sheet_name)
            except Exception as e:
                raise RuntimeError(f"Could not read '{xlsx.name}': {e}") from e

            df[job.month_col] = month
            if template is None:
                template = list(df.columns)
            else:
                df = align_to_template(df, template, xlsx.name)

            write_csv(df, csv_path, job.csv_encoding)
            log(f"  {xlsx.name:28} {len(df):>8,} rows")
            total_rows += len(df)
            converted.append(xlsx.name)

        log(f"Converted {len(converted)} file(s), skipped {len(skipped)} file(s) in "
            f"{perf_counter() - started:,.1f}s.")

        # --- Schema + stale CSV check ---
        names = write_schema(template, out, job.schema_file, job.csv_encoding)
        warn_stale_csv(out, xlsx_files, job.month_pattern)

        # --- Summary ---
        if converted:
            log(f"Done -> {out}")
            log(f"Columns: {', '.join(names)}")
            log(f"SCRIPT_RESULT: SUCCESS; ROWS_PROCESSED: {total_rows}")
        else:
            log("Nothing was converted.")
            log("SCRIPT_RESULT: SUCCESS; ROWS_PROCESSED: 0")
        return total_rows

    except Exception as e:
        log(f"SCRIPT_RESULT: FAILED; ERROR: {type(e).__name__}: {e}")
        raise
