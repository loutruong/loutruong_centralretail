@ECHO OFF
REM Kept for compatibility - the logic lives in run_notebook.bat
CALL "%~dp0run_notebook.bat" "01_slp_perf.ipynb"
EXIT /B %ERRORLEVEL%
