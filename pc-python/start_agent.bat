@echo off
title KaironAgent Baslatici
cd /d "%~dp0"
if exist .venv\Scripts\python.exe (
    start "" ".venv\Scripts\python.exe" run_agent.py
) else (
    start "" python run_agent.py
)
exit
