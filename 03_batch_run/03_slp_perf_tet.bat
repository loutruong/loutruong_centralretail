@ECHO OFF
REM Kept for compatibility - the logic lives in run_notebook.bat
CALL "%~dp0run_notebook.bat" "03_slp_perf_tet.ipynb"
EXIT /B %ERRORLEVEL%
