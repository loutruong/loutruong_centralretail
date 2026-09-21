@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

REM =========================================================================
REM  ENTRY POINT - this is the ONLY file to run (double-click or Task Scheduler).
REM
REM  00_master_flow.bat  (this file)  ->  01_sub_flow.bat  <notebook>    (sub flow, one call per notebook)
REM                                          -> jupyter nbconvert --execute 02_auto\<notebook>
REM                                          -> git commit + push when the notebook succeeded
REM
REM  The flows are the CALL :RUN_FLOW lines in the EXECUTION FLOW section below.
REM  Excel cleanup is handled inside the notebooks by auto_lib.paste_to_sheet (close + quit in
REM  a finally block, pid watchdog force-closes a lingering EXCEL.EXE), so no kill step lives here.
REM =========================================================================

REM =========================================================================
REM CONFIGURATION & LOGGING SETUP
REM =========================================================================
TITLE AUTOMATION: Initializing...

REM --- 1. DEFINE CODE PATHS ---
SET "MASTER_DIR=D:\OneDrive - Central Group\Stella's files - 1. HAND OVER\03. REPORT DAILY\01_code\loutruong\03_batch_run"
SET "LOG_FILE_DIR=D:\Automation_Logs"

REM --- 2. FLOW COUNTERS (filled in automatically while the flows run) ---
SET "FLOWS_RUN=0"
SET "FAILED_FLOWS="

REM --- 3. SAFE TIMESTAMP GENERATION (PowerShell: identical on every regional date/time format) ---
SET "TIMESTAMP="
FOR /F "usebackq delims=" %%i IN (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) DO SET "TIMESTAMP=%%i"
IF NOT DEFINED TIMESTAMP SET "TIMESTAMP=%RANDOM%"
SET "LOG_FILE_NAME=%LOG_FILE_DIR%\Automation_Log_%TIMESTAMP%.txt"

REM Ensure the log directory exists
IF NOT EXIST "%LOG_FILE_DIR%" MKDIR "%LOG_FILE_DIR%"

REM --- Console Start Confirmation ---
ECHO =========================================================================
ECHO Starting Automation Flow at %TIME%
ECHO Log file: "%LOG_FILE_NAME%"
ECHO =========================================================================

REM --- Log Start ---
ECHO ========================================================================= > "%LOG_FILE_NAME%"
ECHO STARTING AUTOMATION FLOW >> "%LOG_FILE_NAME%"
ECHO Start Time (General): %DATE% %TIME% >> "%LOG_FILE_NAME%"
ECHO ------------------------------------------------------------------------- >> "%LOG_FILE_NAME%"

REM =========================================================================
REM EXECUTION FLOW
REM Each line: CALL :RUN_FLOW  notebook-file-name  label
REM A failed flow is logged as FAILED and the next flow still runs.
REM
REM To add a flow: add one CALL :RUN_FLOW line below (notebook file name + label).
REM To pause a flow: put @REM in front of its line (flows are numbered as they run).
REM above to match the new total number of active flows.
REM =========================================================================
CALL :RUN_FLOW "01_slp_perf.ipynb" "SLP_PERF"
CALL :RUN_FLOW "02_slp_byr_perf.ipynb" "SLP_BYR_PERF"
@REM CALL :RUN_FLOW "03_slp_perf_tet.ipynb" "SLP_PERF_TET"          Tet campaign only - enable during the Tet window
CALL :RUN_FLOW "04_vc_convert_xls_csv.ipynb" "VC_CONVERT_XLS_CSV"

REM =========================================================================
REM FINAL STATUS (POST-RUN)
REM =========================================================================
TITLE AUTOMATION: Final status...

ECHO. >> "%LOG_FILE_NAME%"
IF "!FAILED_FLOWS!"=="" (
    SET "MASTER_RC=0"
    ECHO FINAL STATUS: ALL !FLOWS_RUN! FLOWS SUCCEEDED >> "%LOG_FILE_NAME%"
    ECHO.
    ECHO FINAL STATUS: ALL !FLOWS_RUN! FLOWS SUCCEEDED
) ELSE (
    SET "MASTER_RC=1"
    ECHO FINAL STATUS: FAILED FLOWS:!FAILED_FLOWS! - check the log for SCRIPT_RESULT: FAILED lines >> "%LOG_FILE_NAME%"
    ECHO.
    ECHO FINAL STATUS: FAILED FLOWS:!FAILED_FLOWS! - check the log for SCRIPT_RESULT: FAILED lines
)
ECHO End Time (General): %DATE% %TIME% >> "%LOG_FILE_NAME%"
ECHO ========================================================================= >> "%LOG_FILE_NAME%"

ECHO.
ECHO Automation completed. Detailed log file created at: "%LOG_FILE_NAME%"
TITLE AUTOMATION: Finished

REM CRITICAL: This PAUSE command will keep the window open so you can read the output.
PAUSE

ENDLOCAL & EXIT /B %MASTER_RC%


REM =========================================================================
REM SUBROUTINE: run one flow, log its start/end time and SUCCESS / FAILED
REM =========================================================================
:RUN_FLOW
SET /A FLOWS_RUN+=1
SET "FLOW_NUM=%FLOWS_RUN%"
SET "FLOW_NB=%~1"
SET "FLOW_LABEL=%~2"
TITLE AUTOMATION: Running Flow %FLOW_NUM% (%FLOW_LABEL%)
ECHO.
ECHO *************************************************************************
ECHO * Starting Flow %FLOW_NUM%: %FLOW_LABEL% (May take a moment)
ECHO *************************************************************************
ECHO. >> "%LOG_FILE_NAME%"
ECHO Starting Flow %FLOW_NUM%: %FLOW_LABEL% >> "%LOG_FILE_NAME%"
ECHO Flow %FLOW_NUM% Start Time: %DATE% %TIME% >> "%LOG_FILE_NAME%"
REM 01_sub_flow.bat does the actual Python execution for this notebook.
CALL "%MASTER_DIR%\01_sub_flow.bat" "%FLOW_NB%" >> "%LOG_FILE_NAME%" 2>&1
SET "FLOW_RC=%ERRORLEVEL%"
ECHO Flow %FLOW_NUM% End Time: %DATE% %TIME% >> "%LOG_FILE_NAME%"
IF "%FLOW_RC%"=="0" (
    ECHO Flow %FLOW_NUM% STATUS: SUCCESS >> "%LOG_FILE_NAME%"
    ECHO * Flow %FLOW_NUM% Complete at %TIME% - SUCCESS
) ELSE (
    SET "FAILED_FLOWS=!FAILED_FLOWS! %FLOW_NUM%"
    ECHO Flow %FLOW_NUM% STATUS: FAILED - exit code %FLOW_RC% >> "%LOG_FILE_NAME%"
    ECHO * Flow %FLOW_NUM% FAILED - exit code %FLOW_RC% - see the log
)
ECHO ------------------------------------------------------------------------- >> "%LOG_FILE_NAME%"
ECHO *************************************************************************
EXIT /B 0
