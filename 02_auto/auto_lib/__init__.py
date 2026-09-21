"""auto_lib - shared logic behind the 02_auto notebooks (dwh.py, excel.py, xlsx_csv.py, log.py).
oracledb, win32com, ctypes, subprocess and dotenv import inside functions, so this also works without them."""
__version__ = "2.0.0"

from .log import log
from .dwh import load_env, init_oracle_client_once, fetch_dataframe
from .excel import ExcelJob, paste_to_sheet
from .xlsx_csv import CsvJob, convert_folder

__all__ = [
    "__version__",
    "log",
    "load_env",
    "init_oracle_client_once",
    "fetch_dataframe",
    "ExcelJob",
    "paste_to_sheet",
    "CsvJob",
    "convert_folder",
]
