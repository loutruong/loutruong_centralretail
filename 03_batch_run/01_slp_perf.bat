@ECHO OFF
SETLOCAL

REM --- CONFIGURATION ---
SET "ANACONDA_BASE_DIR=C:\Users\tt20368267\AppData\Local\anaconda3"

REM Define the Global Base Path (No trailing slash)
SET "BASE_PATH=D:\OneDrive - Central Group\Stella's files - 1. HAND OVER\3. REPORT DAILY\01_code\loutruong\02_auto"

REM Define the specific file
SET "FILE_NAME=01_slp_perf.ipynb"

REM --- Activate Environment ---
CALL "%ANACONDA_BASE_DIR%\Scripts\activate.bat"

REM --- Run Notebook ---
REM Combine the Base Path and File Name using quotes to handle spaces/apostrophes
CALL jupyter nbconvert --to notebook --execute "%BASE_PATH%\%FILE_NAME%" --inplace

REM --- GIT OPERATIONS ---
REM Move to the base directory
cd /d "%BASE_PATH%"

git add "%FILE_NAME%"
git commit -a -m "Push"
git push -u loutruong_centralretail main:main

REM --- Cleanup ---
CALL conda deactivate
ENDLOCAL
@REM PAUSE
EXIT /B