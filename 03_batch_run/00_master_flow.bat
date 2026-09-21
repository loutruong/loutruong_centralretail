@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

REM 00_master_flow.bat - ENTRY POINT: the only file to run (double-click or Task Scheduler).
REM Calls 01_sub_flow.bat once per notebook (CALL :RUN_FLOW below), which runs jupyter
REM   nbconvert, then git commit + push on success.
REM To add a flow: add a CALL :RUN_FLOW line below. To pause one: put @REM in front of it.
REM Flow numbers in the log = the notebook file prefix (01, 02, 04...); the final line counts the flows run.

REM --- CONFIGURATION & LOGGING SETUP ---
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

REM --- EXECUTION FLOW ---
CALL :RUN_FLOW "01_slp_perf.ipynb" "SLP_PERF"
CALL :RUN_FLOW "02_slp_byr_perf.ipynb" "SLP_BYR_PERF"
@REM CALL :RUN_FLOW "03_slp_perf_tet.ipynb" "SLP_PERF_TET"          Tet campaign only - enable during the Tet window
CALL :RUN_FLOW "04_vc_convert_xls_csv.ipynb" "VC_CONVERT_XLS_CSV"

REM --- FINAL STATUS (POST-RUN) ---
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

PAUSE

ENDLOCAL & EXIT /B %MASTER_RC%


REM --- SUBROUTINE: run one flow, log its start/end time and SUCCESS / FAILED ---
:RUN_FLOW
SET /A FLOWS_RUN+=1
SET "FLOW_NB=%~1"
SET "FLOW_NUM=%FLOW_NB:~0,2%"
SET "FLOW_LABEL=%~2"
TITLE AUTOMATION: Running Flow %FLOW_NUM% (%FLOW_LABEL%)
ECHO.
ECHO *************************************************************************
ECHO * Starting Flow %FLOW_NUM%: %FLOW_LABEL% (May take a moment)
ECHO *************************************************************************
ECHO. >> "%LOG_FILE_NAME%"
ECHO Starting Flow %FLOW_NUM%: %FLOW_LABEL% >> "%LOG_FILE_NAME%"
ECHO Flow %FLOW_NUM% Start Time: %DATE% %TIME% >> "%LOG_FILE_NAME%"
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
