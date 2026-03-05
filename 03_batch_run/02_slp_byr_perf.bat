@ECHO OFF
SETLOCAL

REM Define the base path to your Anaconda installation
SET "ANACONDA_BASE_DIR=C:\Users\tt20368267\AppData\Local\anaconda3"

REM --- CORRECTED NOTEBOOK PATH ---
REM DO NOT use quotes here
SET NOTEBOOK_PATH=D:\OneDrive - Central Group\Stella's files - 1. HAND OVER\3. REPORT DAILY\01_code\loutruong\03_batch_run\02_slp_byr_perf.ipynb

REM --- Activate the base environment ---
CALL "%ANACONDA_BASE_DIR%\Scripts\activate.bat"

REM --- Run the shell command ---
REM --- Use quotes around the variable to safely handle spaces and apostrophes ---
CALL jupyter nbconvert --to notebook --execute "%NOTEBOOK_PATH%" --inplace

REM --- Deactivate and Exit Cleanly ---
CALL conda deactivate
ENDLOCAL