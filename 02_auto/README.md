# 02_auto - daily report notebooks

Thin notebooks that only hold the configuration (SQL, paths, sheet names); the work itself is done by the shared package `auto_lib` next to them.

```
02_auto/
  01_slp_perf.ipynb             DWH -> Supplier_Performance_Tracker.xlsx, sheet perf_raw_di
  02_slp_byr_perf.ipynb         DWH -> same workbook, sheet byr_perf_raw_di
  03_slp_perf_tet.ipynb         DWH (Tet 2025 / Tet 2026 windows) -> sheet perf_raw_di_tet
  04_vc_convert_xls_csv.ipynb   monthly voucher .xlsx -> UTF-8 CSV + BigQuery schema.json
  auto_lib/
    log.py                      log(): timestamped print
    dwh.py                      load_env(), init_oracle_client_once(), fetch_dataframe()
    excel.py                    ExcelJob + paste_to_sheet(): Open > Delete > Write > Refresh > Save > Close
    xlsx_csv.py                 CsvJob + convert_folder(): Read > Standardize > Write > Schema
03_batch_run/
  00_master_flow.bat            MASTER - the only file to run: every flow in order + final status
  01_sub_flow.bat <notebook>    SUB FLOW called by the master, one notebook per call (nbconvert, then git)
```

## Run

- All flows: double-click `03_batch_run\00_master_flow.bat`, wait for `FINAL STATUS`, press a key. Log: `D:\Automation_Logs\Automation_Log_<timestamp>.txt`. One flow: `03_batch_run\01_sub_flow.bat 03_slp_perf_tet.ipynb`.
- In VS Code: open the notebook, kernel `base`, Run All (the first cell finds `auto_lib` from the notebook folder).
- Every run logs `SCRIPT_RESULT: SUCCESS; ROWS_PROCESSED: N` or `SCRIPT_RESULT: FAILED; ERROR: ...`.

## Change something

- SQL, sheet name, workbook path, header aliases: the "Declaration of variables" cell of that notebook.
- Tuning knobs (retries, waits, timeouts, chunk size, strict header check, ...): listed in the same cell with their defaults; pass one to `al.ExcelJob(...)` / `al.CsvJob(...)` as a keyword argument to change it.
- New flow: copy a notebook, change its variables cell, add one `CALL :RUN_FLOW "<notebook>" "<LABEL>"` line in `00_master_flow.bat`. To pause a flow (e.g. the Tet one outside the Tet window) put `@REM` in front of its line.
- After editing `auto_lib`, restart the kernel (a running kernel keeps the version it imported first).

## Machine-specific settings (change when the repo moves to another PC or user)

- `.env` at the repo root: `DWH_HOST, DWH_PORT, DWH_NAME, DWH_USER, DWH_PASSWORD` (never printed, never commit it).
- `01_sub_flow.bat`: `ANACONDA_BASE_DIR`, `BASE_PATH`, git remote `loutruong_centralretail`. `00_master_flow.bat`: `MASTER_DIR`, `LOG_FILE_DIR`.
- Notebooks: `instant_client_path` (Config cell), `sheet_path` / `src_path` (variables cell).
