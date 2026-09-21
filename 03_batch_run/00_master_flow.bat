@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

REM =========================================================================
REM ** EXCEL PROCESS CLEANUP IS HANDLED BY auto_lib.paste_to_sheet **
REM Every notebook closes its workbook and quits its own hidden Excel
REM instance in a try/finally block, on success AND on failure, and a
REM watchdog force-closes that EXCEL.EXE (by pid) if it lingers, so no
REM force-kill step is needed here (and none would be safe).
REM =========================================================================

REM =========================================================================
REM CONFIGURATION & LOGGING SETUP
REM =========================================================================
TITLE AUTOMATION: Initializing...

REM --- 1. DEFINE CODE PATHS ---
SET "MASTER_DIR=D:\OneDrive - Central Group\Stella's files - 1. HAND OVER\03. REPORT DAILY\01_code\loutruong\03_batch_run"
SET "LOG_FILE_DIR=D:\Automation_Logs"

REM --- 2. FLOWS TO RUN (enable / disable a flow by editing the CALL lines in the EXECUTION FLOW section) ---
SET "TOTAL_FLOWS=2"
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
ECHO Total Flows to Run: %TOTAL_FLOWS% >> "%LOG_FILE_NAME%"
ECHO ------------------------------------------------------------------------- >> "%LOG_FILE_NAME%"

REM =========================================================================
REM EXECUTION FLOW
REM Each line: CALL :RUN_FLOW  flow-number  notebook-file-name  label
REM A failed flow is logged as FAILED and the next flow still runs.
REM
REM To add a flow: add one CALL :RUN_FLOW line below with the next flow
REM number, the notebook file name and a label, then bump TOTAL_FLOWS
REM above to match the new total number of active flows.
REM =========================================================================
CALL :RUN_FLOW 1 "01_slp_perf.ipynb" "SLP_PERF"
CALL :RUN_FLOW 2 "02_slp_byr_perf.ipynb" "SLP_BYR_PERF"
@REM CALL :RUN_FLOW 3 "03_slp_perf_tet.ipynb" "SLP_PERF_TET"
@REM CALL :RUN_FLOW 3 "05_28thgamebirthday.ipynb" "GAME28THBIRTHDAY"   (notebook must live in 02_auto first)

REM =========================================================================
REM FINAL STATUS (POST-RUN)
REM =========================================================================
TITLE AUTOMATION: Final status...

ECHO. >> "%LOG_FILE_NAME%"
IF "!FAILED_FLOWS!"=="" (
    SET "MASTER_RC=0"
    ECHO FINAL STATUS: ALL %TOTAL_FLOWS% FLOWS SUCCEEDED >> "%LOG_FILE_NAME%"
    ECHO.
    ECHO FINAL STATUS: ALL %TOTAL_FLOWS% FLOWS SUCCEEDED
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
SET "FLOW_NUM=%~1"
SET "FLOW_NB=%~2"
SET "FLOW_LABEL=%~3"
TITLE AUTOMATION: Running Flow %FLOW_NUM% of %TOTAL_FLOWS% (%FLOW_LABEL%)
ECHO.
ECHO *************************************************************************
ECHO * Starting Flow %FLOW_NUM%: %FLOW_LABEL% (May take a moment)
ECHO *************************************************************************
ECHO. >> "%LOG_FILE_NAME%"
ECHO Starting Flow %FLOW_NUM%: %FLOW_LABEL% >> "%LOG_FILE_NAME%"
ECHO Flow %FLOW_NUM% Start Time: %DATE% %TIME% >> "%LOG_FILE_NAME%"
REM run_notebook.bat does the actual Python execution for this notebook.
CALL "%MASTER_DIR%\run_notebook.bat" "%FLOW_NB%" >> "%LOG_FILE_NAME%" 2>&1
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
