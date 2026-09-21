"""The one print of the package: every line goes through log(), so the batch log has timestamps."""
from datetime import datetime


def log(message: str) -> None:
    """Prints with a timestamp so the batch log (Automation_Log*.txt) shows how long each step takes."""
    print(f"[{datetime.now():%Y-%m-%d %H:%M:%S}] {message}", flush=True)
