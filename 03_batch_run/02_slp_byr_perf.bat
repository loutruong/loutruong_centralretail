@ECHO OFF
REM Kept for compatibility - the logic lives in run_notebook.bat
CALL "%~dp0run_notebook.bat" "02_slp_byr_perf.ipynb"
EXIT /B %ERRORLEVEL%
