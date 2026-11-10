# Limpiador.ps1 — Desinstala un programa y barre sus residuos (rapido y eficaz)
param(
  [Parameter(Mandatory)][string]$Nombre,    # Patrón regex: 'ClipGrab' o 'K-Lite|KLCodec'
  [string]$Excluir = 'Windows|Microsoft Office|SQL Server|Common Files',  # Nunca tocar
  [switch]$Profundo,                          # Extra: tambien dentro de Windows y mas hondo (lento)
  [switch]$Ejecutar                           # Sin esto = simulación
)

$ErrorActionPreference = 'SilentlyContinue'
$objetivos = [System.Collections.Generic.List[string]]::new()
function Add-Obj($p) { if ($p -and $p -notmatch $Excluir) { $objetivos.Add($p) } }

# Carpetas pesadas / de sistema que no merece la pena recorrer
$skip = '\\(Windows|WinSxS|\$Recycle\.Bin|System Volume Information|Config\.Msi|Package Cache|DriverStore)\\'
$hondo = 4
if ($Profundo) { $skip = '\\(\$Recycle\.Bin|System Volume Information)\\'; $hondo = 12 }

# --- 0. Desinstalacion oficial ---
"`n=== Desinstaladores registrados ==="
$desinst = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall' |
  ? { $_.GetValue('DisplayName') -match $Nombre -and $_.GetValue('DisplayName') -notmatch $Excluir }

foreach ($d in $desinst) {
  $nom = $d.GetValue('DisplayName')
  $cmd = $d.GetValue('QuietUninstallString'); if (-not $cmd) { $cmd = $d.GetValue('UninstallString') }
  if (-not $cmd) { continue }
  if ($cmd -match 'msiexec') {
    $cmd = $cmd -replace '/I','/X' -replace '/i','/X'
    if ($cmd -notmatch '/q') { $cmd += ' /qn /norestart' }
  }
  if ($Ejecutar) { "Desinstalando: $nom"; Start-Process cmd.exe -ArgumentList "/c $cmd" -Wait }
  else { "Desinstalaria: $nom  ->  $cmd" }
}
if (-not $desinst) { "(ninguno coincide; se limpian solo residuos)" }

# --- 1. Procesos vivos que queden ---
Get-Process | ? { $_.Path -match $Nombre } | % {
  "Proceso: $($_.ProcessName)"
  if ($Ejecutar) { Stop-Process -Id $_.Id -Force }
}

# --- 2. Archivos: rutas habituales (hondo) + resto del disco (podado) ---
$bases = $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, $env:APPDATA,
         $env:LOCALAPPDATA, "$env:LOCALAPPDATA\Temp", "$env:USERPROFILE\Downloads",
         "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Documents", $env:PUBLIC,
         "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
         "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
Get-ChildItem $bases -Recurse -Depth 5 -Force | ? Name -match $Nombre |
  Select -Expand FullName | % { Add-Obj $_ }

# Todas las unidades fijas, saltando carpetas de sistema pesadas
$raices = @("$env:SystemDrive\")   # Solo C: (no toca pendrives ni unidades externas)
foreach ($root in $raices) {
  Get-ChildItem $root -Force | % {
    if ($_.PSIsContainer) {
      if ($_.FullName -notmatch $skip) {
        if ($_.Name -match $Nombre) { Add-Obj $_.FullName }
        Get-ChildItem $_.FullName -Recurse -Depth $hondo -Force |
          ? { $_.FullName -notmatch $skip -and $_.Name -match $Nombre } |
          Select -Expand FullName | % { Add-Obj $_ }
      }
    } elseif ($_.Name -match $Nombre) { Add-Obj $_.FullName }
  }
}

# --- 3. Registro: software, clases y asociaciones ---
Get-ChildItem 'HKCU:\Software','HKLM:\SOFTWARE','HKLM:\SOFTWARE\WOW6432Node',
  'HKCU:\Software\Classes','HKLM:\SOFTWARE\Classes' -Recurse -Depth 2 |
  ? PSChildName -match $Nombre | Select -Expand PSPath | % { Add-Obj ($_ -replace '^.*::') }

# --- 4. Desinstaladores + caché MSI (claves huérfanas) ---
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall' |
  ? { $_.GetValue('DisplayName') -match $Nombre } | Select -Expand PSPath | % { Add-Obj ($_ -replace '^.*::') }

# --- 5. Servicios, tareas y arranque (solo aviso) ---
Get-CimInstance Win32_Service | ? { "$($_.Name)$($_.PathName)" -match $Nombre } |
  % { "Servicio (revisar a mano): $($_.Name)" }
Get-ScheduledTask | ? { "$($_.TaskName)$($_.Actions.Execute)" -match $Nombre } |
  % { "Tarea (revisar a mano): $($_.TaskPath)$($_.TaskName)" }
Get-CimInstance Win32_StartupCommand | ? Command -match $Nombre | % { "Inicio: $($_.Name)" }

# --- Resultado ---
$lista = $objetivos | Sort -Unique
"`n=== $($lista.Count) residuos para '$Nombre' (excluyendo: $Excluir) ==="
$lista

if ($Ejecutar) {
  "`n>>> BORRANDO RESIDUOS <<<"
  $lista | Remove-Item -Recurse -Force -Verbose
} else {
  "`n(Simulación. Repite con -Ejecutar para desinstalar y borrar.)"
}

# Codigo de salida: 2 = no existe (ni desinstalador ni residuos)
if (-not $desinst -and $lista.Count -eq 0) { exit 2 } else { exit 0 }
