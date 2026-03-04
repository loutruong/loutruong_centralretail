@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

REM =========================================================================
REM ** REMOVED: EXCEL PROCESS CLEANUP (PRE-RUN) **
REM The Python script's robust 'finally' block now handles cleanup,
REM making this force-kill step unnecessary and unsafe.
REM =========================================================================

REM =========================================================================
REM CONFIGURATION & LOGGING SETUP
REM =========================================================================
TITLE AUTOMATION: Initializing...

REM --- 1. SET THE EXPLICIT PATH TO YOUR PYTHON EXECUTABLE (Keeping this for completeness, though unused) ---
SET "PYTHON_EXEC=C:\Users\tt20368267\AppData\Local\anaconda3\python.exe"

REM --- 2. DEFINE CODE PATHS ---
SET "MASTER_DIR=D:\OneDrive - Central Group\Stella's files - 1. HAND OVER\3. REPORT DAILY\01_Code sql\loutruong\02_batch_run"
SET "LOG_FILE_DIR=D:\Automation_Logs"

REM --- 3. SAFE TIMESTAMP GENERATION (avoids regional format errors) ---
FOR /F "tokens=1-4 delims=/ " %%a IN ('date /t') DO (
    SET current_date=%%c%%a%%b
)
REM Added :~0,-2 to remove milliseconds, making the time format safer
FOR /F "tokens=1-3 delims=.:" %%a IN ("%time%") DO (
    SET current_time=%%a%%b%%c
)
SET "TIMESTAMP=%current_date%%current_time%"
SET "LOG_FILE_NAME=%LOG_FILE_DIR%\Automation_Log%TIMESTAMP%.txt"

REM Ensure the log directory exists
IF NOT EXIST "%LOG_FILE_DIR%" MKDIR "%LOG_FILE_DIR%"

REM --- Console Start Confirmation ---
ECHO =========================================================================
ECHO Starting Automation Flow at %TIME%
ECHO =========================================================================

REM --- Log Start ---
ECHO ========================================================================= > "%LOG_FILE_NAME%"
ECHO STARTING AUTOMATION FLOW >> "%LOG_FILE_NAME%"
ECHO Start Time (General): %DATE% %TIME% >> "%LOG_FILE_NAME%"
ECHO Total Flows to Run: 3 >> "%LOG_FILE_NAME%"
ECHO ------------------------------------------------------------------------- >> "%LOG_FILE_NAME%"

REM =========================================================================
REM EXECUTION FLOW
REM =========================================================================

REM --- FLOW 1: 01_slp_perf.bat ---
TITLE AUTOMATION: Running Flow 1 of 3 (SLP_PERF)
ECHO.
ECHO *************************************************************************
ECHO * Starting Flow 1: 01_SLP_PERF (May take a moment)
ECHO *************************************************************************
ECHO. >> "%LOG_FILE_NAME%"
ECHO Starting Flow 1: 01_SLP_PERF >> "%LOG_FILE_NAME%"
ECHO Flow 1 Start Time: %DATE% %TIME% >> "%LOG_FILE_NAME%"
REM The actual Python execution happens inside this bat file.
CALL "%MASTER_DIR%\01_slp_perf.bat" >> "%LOG_FILE_NAME%" 2>&1
ECHO Flow 1 End Time: %DATE% %TIME% >> "%LOG_FILE_NAME%"
ECHO ------------------------------------------------------------------------- >> "%LOG_FILE_NAME%"
ECHO *************************************************************************
ECHO * Flow 1 Complete at %TIME%
ECHO *************************************************************************

REM --- FLOW 2: 02_slp_byr_perf.bat ---
TITLE AUTOMATION: Running Flow 2 of 3 (SLP_BYR_PERF)
ECHO.
ECHO *************************************************************************
ECHO * Starting Flow 2: 02_SLP_BYR_PERF (May take a moment)
ECHO *************************************************************************
ECHO. >> "%LOG_FILE_NAME%"
ECHO Starting Flow 2: 02_SLP_BYR_PERF >> "%LOG_FILE_NAME%"
ECHO Flow 2 Start Time: %DATE% %TIME% >> "%LOG_FILE_NAME%"
CALL "%MASTER_DIR%\02_slp_byr_perf.bat" >> "%LOG_FILE_NAME%" 2>&1
ECHO Flow 2 End Time: %DATE% %TIME% >> "%LOG_FILE_NAME%"
ECHO ------------------------------------------------------------------------- >> "%LOG_FILE_NAME%"
ECHO *************************************************************************
ECHO * Flow 2 Complete at %TIME%
ECHO *************************************************************************

REM --- FLOW 3: 03_slp_perf_tet.bat ---
TITLE AUTOMATION: Running Flow 3 of 3 (SLP_PERF_TET)
ECHO.
ECHO *************************************************************************
ECHO * Starting Flow 3: 03_SLP_PERF_TET (May take a moment)
ECHO *************************************************************************
ECHO. >> "%LOG_FILE_NAME%"
ECHO Starting Flow 3: 03_SLP_PERF_TET >> "%LOG_FILE_NAME%"
ECHO Flow 3 Start Time: %DATE% %TIME% >> "%LOG_FILE_NAME%"
CALL "%MASTER_DIR%\03_slp_perf_tet.bat" >> "%LOG_FILE_NAME%" 2>&1
ECHO Flow 3 End Time: %DATE% %TIME% >> "%LOG_FILE_NAME%"
ECHO ------------------------------------------------------------------------- >> "%LOG_FILE_NAME%"
ECHO *************************************************************************
ECHO * Flow 3 Complete at %TIME%
ECHO *************************************************************************

REM =========================================================================
REM FINAL CLEANUP (POST-RUN)
REM =========================================================================
TITLE AUTOMATION: Final cleanup...

REM --- Log End ---
ECHO. >> "%LOG_FILE_NAME%"
ECHO FINAL STATUS: ALL 3 FLOWS FINISHED >> "%LOG_FILE_NAME%"
ECHO End Time (General): %DATE% %TIME% >> "%LOG_FILE_NAME%"
ECHO ========================================================================= >> "%LOG_FILE_NAME%"

REM ** REMOVED: EXCEL PROCESS CLEANUP (POST-RUN) **
REM This section has been removed because the robust Python cleanup 
REM (using xl.Quit() and pythoncom.CoUninitialize()) is now responsible 
REM for closing the EXCEL.EXE process cleanly.
ECHO Final cleanup complete (handled by Python script).

ECHO.
ECHO Automation completed. Detailed log file created at: "%LOG_FILE_NAME%"
TITLE AUTOMATION: Finished!

REM CRITICAL: This PAUSE command will keep the window open so you can read the output.
PAUSE

ENDLOCAL

EXIT /B