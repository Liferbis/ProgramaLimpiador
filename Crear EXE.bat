@echo off
echo Compilando App.exe con ps2exe (requiere internet la primera vez)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "try{ Install-PackageProvider NuGet -Force -ErrorAction SilentlyContinue | Out-Null }catch{}; if(-not (Get-Module -ListAvailable ps2exe)){ Set-PSRepository PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue; Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber }; Import-Module ps2exe; Invoke-ps2exe '%~dp0App.ps1' '%~dp0App.exe' -noConsole -requireAdmin -title 'Limpiador de PC' -product 'Limpiador de PC'"
if exist "%~dp0App.exe" ( echo. & echo LISTO: App.exe creado en esta carpeta. ) else ( echo. & echo No se pudo crear App.exe. Revisa la conexion o los permisos. )
pause
