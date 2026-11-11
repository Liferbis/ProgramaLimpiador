@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
color 0B
title  Limpiador de programas
mode con: cols=80 lines=34 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0EstiloConsola.ps1"

for /f %%A in ('echo prompt $E^| cmd') do set "ESC=%%A"
set "C=!ESC![96m"
set "V=!ESC![92m"
set "A=!ESC![93m"
set "G=!ESC![90m"
set "B=!ESC![46m!ESC![30m"
set "R=!ESC![0m"

net session >nul 2>&1 || ( powershell -Command "Start-Process '%~f0' -Verb RunAs" & exit /b )

set "PS1=%~dp0Limpiador.ps1"
if not exist "%PS1%" ( echo No encuentro Limpiador.ps1 en esta carpeta. & pause & exit /b )
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

set "TMP=!NOMBRE!" & set "LEN=0"
:lenloop
if defined TMP ( set "TMP=!TMP:~1!" & set /a LEN+=1 & goto lenloop )
if !LEN! LSS 3 ( echo. & echo           !A!Pon al menos 3 letras, que con menos esto se lia.!R! & echo. & pause & goto inicio )

set "LNOMBRE=!NOMBRE!"
set "LEXCLUIR=!EXCLUIR!"
set "LPROG="

echo.
echo           !G!Buscando «!NOMBRE!» (busqueda aproximada) …!R!
set "i=0"
for /f "usebackq delims=" %%L in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%PS1%' -Nombre $env:LNOMBRE -Excluir $env:LEXCLUIR -Listar" 2^>nul`) do (
  set /a i+=1
  set "OPT[!i!]=%%L"
)

if !i! EQU 0 goto sinprograma
if !i! EQU 1 ( set "LPROG=!OPT[1]!" & goto preparado )

:elegir
cls
echo.
echo           !C!Programas que se parecen a «!NOMBRE!»:!R!
echo.
for /l %%n in (1,1,!i!) do echo              %%n^)  !OPT[%%n]!
echo              !V!T^)  Todas!R!
echo.
set /p "SEL=          Elige un numero o T  ›  "
if /i "!SEL!"=="T" (
  set "LPROG="
  for /l %%n in (1,1,!i!) do ( if defined LPROG ( set "LPROG=!LPROG!^|!OPT[%%n]!" ) else ( set "LPROG=!OPT[%%n]!" ) )
  goto preparado
)
set "CHO=!OPT[%SEL%]!"
if not defined CHO goto elegir
set "LPROG=!CHO!"
goto preparado

:sinprograma
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $n=$env:LNOMBRE; $pat='(^|[^\p{L}\p{N}])'+[regex]::Escape($n)+'([^\p{L}\p{N}]|$)'; $dl=$env:USERPROFILE+'\Downloads'; $b=$env:ProgramFiles,${env:ProgramFiles(x86)},$env:ProgramData,$env:APPDATA,$env:LOCALAPPDATA,$dl; $f=Get-ChildItem $b -Recurse -Depth 2 -Force | ? Name -match $pat | Select -First 1; if($f){exit 0}else{exit 2}"
if !ERRORLEVEL! GEQ 2 goto noexiste
set "LPROG="

:preparado
echo.
echo           !C!›  Analizando «!NOMBRE!» …!R!
if defined LPROG echo           !G!Elegido: !LPROG!!R!
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%PS1%' -Nombre $env:LNOMBRE -Excluir $env:LEXCLUIR -Programas $env:LPROG | %% { '          ' + $_ }"

echo.
echo           !A!Esto es lo que se desinstalaria y se borraria.!R!
echo.
set /p "SEG=          Escribe !V!SI!R! para continuar  ·  Enter para cancelar  ›  "
if /i not "!SEG!"=="SI" goto inicio

echo.
echo           !C!›  Desinstalando y limpiando …!R!
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%PS1%' -Nombre $env:LNOMBRE -Excluir $env:LEXCLUIR -Programas $env:LPROG -Ejecutar | %% { '          ' + $_ }"

echo.
echo           !C!›  Comprobacion final …!R!
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%PS1%' -Nombre $env:LNOMBRE -Excluir $env:LEXCLUIR -Programas $env:LPROG | %% { '          ' + $_ }"
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
