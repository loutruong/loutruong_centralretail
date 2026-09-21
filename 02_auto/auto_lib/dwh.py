"""Oracle DWH -> pandas DataFrame (notebooks 01 - 03): .env settings, Thick-mode client, query.
oracledb and dotenv are imported inside the functions that need them, so this also works without them."""
import os
from time import perf_counter

import pandas as pd

from .log import log

REQUIRED_ENV = ("DWH_HOST", "DWH_PORT", "DWH_NAME", "DWH_USER", "DWH_PASSWORD")


def load_env() -> dict:
    """Loads the .env file and returns the five DWH_* settings; fails fast, without printing the
    password, when any of them is missing or empty."""
    try:
        from dotenv import load_dotenv
    except ImportError:
        log("!! python-dotenv is not installed - reading the DWH_* settings from the environment only.")
    else:
        load_dotenv()
    env = {key: os.getenv(key) for key in REQUIRED_ENV}
    missing = [key for key in REQUIRED_ENV if not env[key]]
    if missing:
        raise EnvironmentError(
            f"Missing variables in .env: {', '.join(missing)}")
    return env


def init_oracle_client_once(lib_dir: str) -> None:
    """Loads the Oracle Instant Client (Thick mode) once per kernel, so the Config cell is safe to re-run."""
    import oracledb

    if hasattr(oracledb, "is_thin_mode") and not oracledb.is_thin_mode():
        log("Oracle Client already initialised in this kernel.")
        return
    if not os.path.isdir(lib_dir):
        raise FileNotFoundError(
            f"Oracle Instant Client folder not found: {lib_dir}")
    oracledb.init_oracle_client(lib_dir=lib_dir)
    log("Initialization successful.")


def fetch_dataframe(sql: str, *, arraysize: int = 10000, allow_empty: bool = False,
                    env: dict | None = None) -> pd.DataFrame:
    """Runs the query and returns a DataFrame, always closing the connection/cursor. An empty result is
    refused (unless allow_empty) so an unfinished DWH load can never wipe the sheet. Any error is logged
    as the SCRIPT_RESULT: FAILED line and re-raised."""
    started = perf_counter()
    try:
        import oracledb

        if env is None:
            env = load_env()
        with oracledb.connect(user=env["DWH_USER"], password=env["DWH_PASSWORD"], host=env["DWH_HOST"],
                              port=int(env["DWH_PORT"]), service_name=env["DWH_NAME"]) as connection:
            with connection.cursor() as cursor:
                cursor.arraysize = arraysize          # fewer round trips for big result sets
                cursor.prefetchrows = arraysize + 1
                cursor.execute(sql)
                columns = [col[0] for col in cursor.description]
                rows = cursor.fetchall()
        df = pd.DataFrame(rows, columns=columns)
        log(f"Fetched {len(df):,} rows x {len(df.columns)} columns in {perf_counter() - started:,.1f}s.")
        if df.empty and not allow_empty:
            raise ValueError("Query returned 0 rows - refusing to wipe the sheet. "
                             "Check the DWH load, or set allow_empty_result = True.")
        return df
    except Exception as e:
        log(f"SCRIPT_RESULT: FAILED; ERROR: {type(e).__name__}: {e}")
        raise
