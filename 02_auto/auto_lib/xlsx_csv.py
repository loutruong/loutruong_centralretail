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

D_STROKE = str.maketrans({"Đ": "D", "đ": "d", "Ð": "D", "ð": "d"})
SWAP_ATTEMPTS = 5
SWAP_WAIT = 1.0
DATE_TEXT = r"\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:\.\d+)?"


def hide_broken_zstandard():
    try:
        import zstandard as _zstd
        if not getattr(_zstd, "__version__", None):
            raise ImportError("zstandard has no __version__")
    except Exception:
        sys.modules["zstandard"] = None


@dataclass
class CsvJob:
    src_path: str
    out_folder: str = "csv"
    file_pattern: str = "*.xlsx"
    month_pattern: str = r"\d{4}[-_]\d{2}"
    sheet_name: int | str = 0
    month_col: str = "source_month"
    csv_encoding: str = "utf-8"
    schema_file: str = "schema.json"
    skip_unchanged: bool = False
    remove_stale: bool = True
    state_file: str = "_convert_state.json"
    date_cols: tuple | None = None


def bq_name(col):
    s = unicodedata.normalize("NFKD", str(col).strip().translate(D_STROKE))
    s = s.encode("ascii", "ignore").decode("ascii")
    s = re.sub(r"[^0-9A-Za-z_]+", "_", s).strip("_").lower()
    return s if s and not s[0].isdigit() else "col_" + s


def schema_names(columns):
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
    m = re.search(month_pattern, Path(xlsx).stem)
    return m.group().replace("_", "-") if m else None


def list_workbooks(src, file_pattern=CsvJob.file_pattern):
    return [f for f in sorted(Path(src).glob(file_pattern)) if not f.name.startswith("~$")]


def read_workbook(xlsx, sheet_name=CsvJob.sheet_name):
    df = pd.read_excel(xlsx, sheet_name=sheet_name, dtype=str).fillna("")
    unnamed = [c for c in df.columns if str(c).startswith("Unnamed:")]
    if unnamed:
        log(f"  !! {xlsx.name}: {len(unnamed)} blank header cell(s) -> {unnamed}")
    return df


def date_columns(job):
    if job.date_cols is None:
        return None
    return (job.date_cols,) if isinstance(job.date_cols, str) else tuple(job.date_cols)


def undo_date_formats(df, date_cols, name):
    from datetime import datetime
    from openpyxl.utils.datetime import to_excel

    for col in df.columns:
        if col in date_cols:
            continue
        looks_like_date = df[col].str.fullmatch(DATE_TEXT)
        if not looks_like_date.any():
            continue
        numbers = {}
        for text in df.loc[looks_like_date, col].unique():
            number = to_excel(datetime.fromisoformat(text))
            numbers[text] = str(int(number)) if number == int(number) else repr(number)
        df.loc[looks_like_date, col] = df.loc[looks_like_date, col].map(numbers)
        log(f"  !! {name}: {int(looks_like_date.sum()):,} number(s) in '{col}' have a date format in Excel - "
            f"written as numbers")
    return df


def read_month(xlsx, month, job):
    try:
        df = read_workbook(xlsx, job.sheet_name)
    except Exception as e:
        raise RuntimeError(f"Could not read '{xlsx.name}': {e}") from e
    if job.date_cols is not None:
        df = undo_date_formats(df, date_columns(job), xlsx.name)
    df[job.month_col] = month
    return df


def align_to_template(df, template, name):
    if list(df.columns) == template:
        return df
    extra = [c for c in df.columns if c not in template]
    absent = [c for c in template if c not in df.columns]
    log(f"  !! {name}: columns differ - extra {extra}, missing {absent}. Re-aligned to the template.")
    return df.reindex(columns=template, fill_value="")


def swap_in(tmp_path, final_path):
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
    hide_broken_zstandard()
    tmp_path = csv_path.with_suffix(".csv.tmp")
    df.to_csv(tmp_path, index=False, encoding=encoding, lineterminator="\n")
    swap_in(tmp_path, csv_path)


def write_schema(template, out, schema_file=CsvJob.schema_file, encoding=CsvJob.csv_encoding):
    if template is None:
        log("No workbook was read this run. Existing schema.json (if any) is left untouched.")
        return []
    names = schema_names(template)
    schema = [{"name": n, "type": "STRING"} for n in names]
    (out / schema_file).write_text(json.dumps(schema, indent=2), encoding=encoding)
    log(f"Wrote {len(names)} columns to '{schema_file}' in '{out}'.")
    return names


def delete_files(paths):
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


def job_signature(job):
    try:
        code = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()[:16]
    except OSError:
        code = "unknown"
    try:
        import openpyxl
        reader = openpyxl.__version__
    except Exception:
        reader = "unknown"
    date_cols = date_columns(job)
    return {"sheet_name": job.sheet_name, "month_col": job.month_col, "month_pattern": job.month_pattern,
            "csv_encoding": job.csv_encoding, "date_cols": None if date_cols is None else list(date_cols),
            "pandas": pd.__version__, "openpyxl": reader, "code": code}


def load_state(path, signature):
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
        usable = (state["signature"] == signature and isinstance(state["template_source"], str)
                  and isinstance(state["template"], list) and len(state["template"]) > 0
                  and all(isinstance(c, str) for c in state["template"]) and isinstance(state["files"], dict))
    except (OSError, ValueError, KeyError, TypeError):
        return None
    return state if usable else None


def save_state(path, state):
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    tmp_path.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")
    swap_in(tmp_path, path)


def drop_state(path):
    try:
        path.unlink(missing_ok=True)
    except OSError as e:
        log(f"!! Could not delete '{path.name}' ({type(e).__name__}: {e}) - delete it by hand.")


def source_unchanged(record, source_stat):
    try:
        return record["size"] == source_stat.st_size and record["mtime_ns"] == source_stat.st_mtime_ns
    except (KeyError, TypeError):
        return False


def csv_intact(record, csv_path):
    try:
        return csv_path.is_file() and record["csv_size"] == csv_path.stat().st_size
    except (KeyError, TypeError, OSError):
        return False


def can_keep(state, xlsx, source_stat, csv_path):
    try:
        record = state["files"][xlsx.name]
    except (KeyError, TypeError):
        return False
    return source_unchanged(record, source_stat) and csv_intact(record, csv_path)


def convert_folder(job: CsvJob) -> int:
    try:
        src = Path(job.src_path)
        if not src.is_dir():
            raise FileNotFoundError(f"Source folder not found: {job.src_path}")
        out = src / job.out_folder
        out.mkdir(exist_ok=True)
        xlsx_files = list_workbooks(src, job.file_pattern)
        log(f"Found {len(xlsx_files)} workbook(s) in '{src.name}'.")

        state_path = out / job.state_file
        track = job.skip_unchanged
        if track:
            signature = job_signature(job)
            state = load_state(state_path, signature)
        else:
            signature = state = None
            drop_state(state_path)

        template = None
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
            source_stat = xlsx.stat()  # before the read: a save during the run is caught next run
            df = None

            if template is None:
                if can_keep(state, xlsx, source_stat, csv_path) and state["template_source"] == xlsx.name:
                    template = state["template"]
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
                        save_state(state_path, state)  # before any CSV is replaced
                unknown = [c for c in date_columns(job) or () if c not in template]
                if unknown:
                    raise ValueError(f"date_cols names {unknown}, but the workbooks have no such column. "
                                     f"Their columns: {template}")

            if can_keep(state, xlsx, source_stat, csv_path):
                log(f"  {xlsx.name:28} unchanged, CSV kept")
                kept.append(xlsx.name)
                continue

            if df is None:
                df = read_month(xlsx, month, job)
            df = align_to_template(df, template, xlsx.name)

            if state is not None and xlsx.name in state["files"]:
                del state["files"][xlsx.name]
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

        names = write_schema(template, out, job.schema_file, job.csv_encoding)
        sweep_output_folder(out, xlsx_files, job.month_pattern, job.remove_stale)
        if state is not None:
            gone = [name for name in state["files"] if name not in converted and name not in kept]
            if gone:
                for name in gone:
                    del state["files"][name]
                save_state(state_path, state)

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
