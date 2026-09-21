@ECHO OFF
SETLOCAL

REM 01_sub_flow.bat - SUB FLOW (worker): runs ONE notebook, called by 00_master_flow.bat for
REM   every flow; run it by hand for a single flow: 01_sub_flow.bat 03_slp_perf_tet.ipynb
REM Steps: activate Anaconda -> jupyter nbconvert --execute --inplace -> git commit + push
REM   (git only when the notebook exited 0). Exit code = nbconvert exit code (0 = success).

REM --- CONFIGURATION ---
SET "ANACONDA_BASE_DIR=C:\Users\tt20368267\AppData\Local\anaconda3"

SET "BASE_PATH=D:\OneDrive - Central Group\Stella's files - 1. HAND OVER\03. REPORT DAILY\01_code\loutruong\02_auto"

SET "FILE_NAME=%~1"

REM Exit code of this script: 0 = notebook ran to the end, anything else = it failed
SET "RC=1"

REM --- Validate the argument before doing anything else ---
IF "%FILE_NAME%"=="" (
    ECHO Usage: 01_sub_flow.bat notebook-file-name.ipynb
    EXIT /B 2
)
IF NOT EXIST "%BASE_PATH%\%FILE_NAME%" (
    ECHO SCRIPT_RESULT: FAILED; notebook not found: "%BASE_PATH%\%FILE_NAME%"
    EXIT /B 2
)

ECHO [%DATE% %TIME%] Runner start: %FILE_NAME%

REM --- Activate Environment ---
CALL "%ANACONDA_BASE_DIR%\Scripts\activate.bat"
IF ERRORLEVEL 1 (
    ECHO SCRIPT_RESULT: FAILED; could not activate Anaconda at "%ANACONDA_BASE_DIR%"
    GOTO :END
)

REM --- Run Notebook ---
REM Combine the Base Path and File Name using quotes to handle spaces/apostrophes
REM --ExecutePreprocessor.timeout=-1 : a long DWH query or Excel refresh must never be killed by a per-cell timeout
CALL jupyter nbconvert --to notebook --execute "%BASE_PATH%\%FILE_NAME%" --inplace --ExecutePreprocessor.timeout=-1
SET "RC=%ERRORLEVEL%"

IF NOT "%RC%"=="0" (
    ECHO SCRIPT_RESULT: FAILED; %FILE_NAME% exited with code %RC% - nothing committed to git
    GOTO :DEACTIVATE
)
ECHO [%DATE% %TIME%] %FILE_NAME% finished with exit code 0

REM --- GIT OPERATIONS (only after a successful run) ---
cd /d "%BASE_PATH%"

git add "%FILE_NAME%"
git commit -a -m "Auto run %FILE_NAME% %DATE% %TIME%"
git push -u loutruong_centralretail main:main
IF ERRORLEVEL 1 ECHO WARNING: git push failed - the notebook ran fine, the commit stays local until the next push

:DEACTIVATE
REM --- Cleanup ---
CALL conda deactivate

:END
ECHO [%DATE% %TIME%] Runner end: %FILE_NAME% (exit code %RC%)
@REM PAUSE
ENDLOCAL & EXIT /B %RC%
