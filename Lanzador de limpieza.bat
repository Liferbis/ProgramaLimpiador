@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
color 0B
title  Limpiador de programas
mode con: cols=80 lines=34 >nul

:: Secuencia ESC para colores ANSI
for /f %%A in ('echo prompt $E^| cmd') do set "ESC=%%A"
set "C=!ESC![96m"
set "V=!ESC![92m"
set "A=!ESC![93m"
set "G=!ESC![90m"
set "B=!ESC![46m!ESC![30m"
set "R=!ESC![0m"

:: --- Auto-elevacion a administrador ---
net session >nul 2>&1 || (
  powershell -Command "Start-Process '%~f0' -Verb RunAs"
  exit /b
)

set "PS1=%~dp0Limpiador.ps1"
if not exist "%PS1%" (
  echo No encuentro Limpiador.ps1 en esta carpeta.
  pause & exit /b
)
set "EXCLUIR=Windows|Microsoft Office|SQL Server|Common Files"

:inicio
cls
echo.
echo.
echo         !C!──────────────────────────────────────────────────!R!
echo.
echo           !B!  LIMPIADOR DE PROGRAMAS  !R!
echo.
echo           !G!Desinstala una app y elimina todo su rastro!R!
echo.
echo         !C!──────────────────────────────────────────────────!R!
echo.
echo.
echo           !G!Protegido (no se toca):!R!
echo           !G!!EXCLUIR!!R!
echo.
echo.
set /p "NOMBRE=          !C!Programa a eliminar!R!  !G!(Enter = salir)!R!  ›  "
if "!NOMBRE!"=="" exit /b

set "LNOMBRE=!NOMBRE!"
set "LEXCLUIR=!EXCLUIR!"

:: --- 0. Comprobacion rapida: existe o no ---
echo.
echo           !G!Buscando «!NOMBRE!» …!R!
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $n=$env:LNOMBRE; $x=$env:LEXCLUIR; $u=Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall' | ? { $_.GetValue('DisplayName') -match $n -and $_.GetValue('DisplayName') -notmatch $x }; $dl=$env:USERPROFILE+'\Downloads'; $b=$env:ProgramFiles,${env:ProgramFiles(x86)},$env:ProgramData,$env:APPDATA,$env:LOCALAPPDATA,$dl; $f=Get-ChildItem $b -Recurse -Depth 2 -Force | ? Name -match $n | Select -First 1; if($u -or $f){exit 0}else{exit 2}"
if !ERRORLEVEL! GEQ 2 goto noexiste

:: --- 1. Comprobacion + vista previa ---
echo.
echo           !C!›  Analizando «!NOMBRE!» …!R!
echo           !G!Escaneo completo del disco, puede tardar un poco.!R!
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%PS1%' -Nombre $env:LNOMBRE -Excluir $env:LEXCLUIR | %% { '          ' + $_ }"

echo.
echo           !A!Esto es lo que se desinstalaria y se borraria.!R!
echo.
set /p "SEG=          Escribe !V!SI!R! para continuar  ·  Enter para cancelar  ›  "
if /i not "!SEG!"=="SI" goto inicio

:: --- 2. Ejecucion real ---
echo.
echo           !C!›  Desinstalando y limpiando «!NOMBRE!» …!R!
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%PS1%' -Nombre $env:LNOMBRE -Excluir $env:LEXCLUIR -Ejecutar | %% { '          ' + $_ }"

:: --- 3. Comprobacion final ---
echo.
echo           !C!›  Comprobacion final …!R!
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%PS1%' -Nombre $env:LNOMBRE -Excluir $env:LEXCLUIR | %% { '          ' + $_ }"
echo.
echo           !V!✓  Si arriba pone «0 residuos» y ningun desinstalador, esta limpio.!R!
echo.
echo.
pause
goto inicio

:noexiste
echo.
echo           !A!¿Es para pillar o es que no sabes escribir?!R!
echo           !G!Aqui no hay ni rastro de «!NOMBRE!»: ni instalado, ni residuos.!R!
echo           !G!Miralo bien y vuelve a probar.!R!
echo.
echo.
pause
goto inicio
