@echo off
powershell -Command "Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0GestionePuntiRipristino.ps1\"' -Verb RunAs"