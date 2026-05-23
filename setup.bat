@echo off
echo Starting setup...
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/33bnm3-sudo/setup/main/setup.ps1 | iex"
pause