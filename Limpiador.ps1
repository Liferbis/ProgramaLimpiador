# Limpiador.ps1 — Desinstala un programa y barre sus residuos (rapido y eficaz)
# Coincidencia SIN distinguir mayusculas y APROXIMADA (tolera erratas: 'clipgab' encuentra 'ClipGrab').
param(
  [Parameter(Mandatory)][string]$Nombre,     # Lo que escribe el usuario (puede tener erratas)
  [string]$Excluir = 'Windows|Microsoft Office|SQL Server|Common Files',
  [string]$Programas = '',                    # DisplayName(s) exactos elegidos, separados por | (uno o varios)
  [switch]$Listar,                            # Solo lista programas instalados que se PARECEN a $Nombre y sale
  [switch]$Regex,                             # Tratar $Nombre como regex (uso avanzado)
  [switch]$Profundo,                          # Extra: tambien dentro de Windows y mas hondo (lento)
  [switch]$Ejecutar                           # Sin esto = simulacion
)

$ErrorActionPreference = 'SilentlyContinue'
if ($Nombre.Trim().Length -lt 3) { "Nombre demasiado corto: pon al menos 3 caracteres."; exit 3 }

$claves = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
          'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
          'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'

# --- Utilidades de coincidencia difusa (compatibles con PowerShell 5.1) ---
function Norm($s){ ($s -replace '[^\p{L}\p{N}]','').ToLower() }
function Marca($name){
  $c = $name -replace '\(.*?\)',' '
  $c = $c -replace '[\d][\d\.\-_]*',' '
  $c = $c -replace '(?i)\b(x64|x86|bit|basic|pro|professional|premium|enterprise|edition|pack|version|free|setup|installer)\b',' '
  ($c -replace '\s+',' ').Trim()
}
function Lev($a,$b){
  $n = $a.Length; $m = $b.Length
  if ($n -eq 0) { return $m }
  if ($m -eq 0) { return $n }
  $prev = New-Object 'int[]' ($m + 1)
  $cur  = New-Object 'int[]' ($m + 1)
  for ($j = 0; $j -le $m; $j++) { $prev[$j] = $j }
  for ($i = 1; $i -le $n; $i++) {
    $cur[0] = $i
    for ($j = 1; $j -le $m; $j++) {
      $cost = 1; if ($a[$i-1] -eq $b[$j-1]) { $cost = 0 }
      $del = $prev[$j] + 1
      $ins = $cur[$j-1] + 1
      $sub = $prev[$j-1] + $cost
      $min = $del
      if ($ins -lt $min) { $min = $ins }
      if ($sub -lt $min) { $min = $sub }
      $cur[$j] = $min
    }
    $tmp = $prev; $prev = $cur; $cur = $tmp
  }
  return $prev[$m]
}
$termN  = Norm $Nombre
$umbral = [math]::Max(2, [int][math]::Floor($termN.Length * 0.34))
function Puntua($name){
  $b = Marca $name
  $best = 999
  foreach ($p in @($b) + ($b -split '\s+')) {
    $pn = Norm $p
    if ($pn.Length -lt 2) { continue }
    if ($pn.Contains($termN) -or $termN.Contains($pn)) { return 0 }
    $dd = Lev $termN $pn
    if ($dd -lt $best) { $best = $dd }
  }
  $best
}

# --- Modo LISTAR: programas instalados parecidos a $Nombre (lista corta y simple) ---
if ($Listar) {
  Get-ChildItem $claves | ? { $_.GetValue('DisplayName') -and $_.GetValue('DisplayName') -notmatch $Excluir } |
    % { [pscustomobject]@{ N = $_.GetValue('DisplayName'); S = (Puntua $_.GetValue('DisplayName')) } } |
    ? { $_.S -le $umbral } | Sort-Object S, N | Group-Object N | % { $_.Group[0] } |
    Select-Object -First 9 | % { $_.N }
  exit 0
}

# --- Programas objetivo (elegidos en el menu) ---
if ($Programas) { $nombresSel = @($Programas -split '\|' | ? { $_ }) } else { $nombresSel = @() }
if ($nombresSel) { $sel = @(Get-ChildItem $claves | ? { $nombresSel -contains $_.GetValue('DisplayName') }) } else { $sel = @() }

# --- Tokens para residuos ---
$fuentes = if ($nombresSel) { $nombresSel } else { @($Nombre) }
$tok = [System.Collections.Generic.List[string]]::new()
foreach ($f in $fuentes) { $b = Marca $f; if ($b) { $tok.Add($b) }; $fw = ($b -split '\s+')[0]; if ($fw) { $tok.Add($fw) } }
$tokens = $tok | ? { $_.Trim().Length -ge 3 } | Select-Object -Unique
if ($Regex) { $pat = $Nombre }
elseif ($tokens) { $pat = '(^|[^\p{L}\p{N}])(' + (($tokens | % { [regex]::Escape($_) }) -join '|') + ')([^\p{L}\p{N}]|$)' }
else { $pat = '(^|[^\p{L}\p{N}])' + [regex]::Escape($Nombre) + '([^\p{L}\p{N}]|$)' }

$objetivos = [System.Collections.Generic.List[string]]::new()
function Add-Obj($p) { if ($p -and $p -notmatch $Excluir) { $objetivos.Add($p) } }
$skip = '\\(Windows|WinSxS|\$Recycle\.Bin|System Volume Information|Config\.Msi|Package Cache|DriverStore)\\'
$hondo = 4
if ($Profundo) { $skip = '\\(\$Recycle\.Bin|System Volume Information)\\'; $hondo = 12 }

# --- 0. Desinstalacion oficial (solo los programas elegidos) ---
"`n=== Desinstaladores registrados ==="
foreach ($d in $sel) {
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
if (-not $sel) { "(ninguno instalado coincide; se limpian solo residuos)" }

# --- 1. Procesos: solo los del propio programa (nunca sistema ni Claude) ---
$procProtegidos = 'claude|cowork|chrome-native-host|explorer|svchost|csrss|wininit|winlogon|services|lsass|dwm|System|Idle|conhost|powershell|cmd'
Get-Process | ? { $_.Name -match $pat -and $_.Name -notmatch $procProtegidos -and $_.Path -notmatch '\\Windows\\' } | % {
  "Proceso: $($_.ProcessName)"
  if ($Ejecutar) { Stop-Process -Id $_.Id -Force }
}

# --- 2. Archivos: rutas habituales (hondo) + resto de C: (podado) ---
$bases = $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, $env:APPDATA,
         $env:LOCALAPPDATA, "$env:LOCALAPPDATA\Temp", "$env:USERPROFILE\Downloads",
         "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Documents", $env:PUBLIC,
         "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
         "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
Get-ChildItem $bases -Recurse -Depth 5 -Force | ? Name -match $pat | Select -Expand FullName | % { Add-Obj $_ }

foreach ($root in @("$env:SystemDrive\")) {
  Get-ChildItem $root -Force | % {
    if ($_.PSIsContainer) {
      if ($_.FullName -notmatch $skip) {
        if ($_.Name -match $pat) { Add-Obj $_.FullName }
        Get-ChildItem $_.FullName -Recurse -Depth $hondo -Force |
          ? { $_.FullName -notmatch $skip -and $_.Name -match $pat } | Select -Expand FullName | % { Add-Obj $_ }
      }
    } elseif ($_.Name -match $pat) { Add-Obj $_.FullName }
  }
}

# --- 3. Registro ---
Get-ChildItem 'HKCU:\Software','HKLM:\SOFTWARE','HKLM:\SOFTWARE\WOW6432Node',
  'HKCU:\Software\Classes','HKLM:\SOFTWARE\Classes' -Recurse -Depth 2 |
  ? PSChildName -match $pat | Select -Expand PSPath | % { Add-Obj ($_ -replace '^.*::') }

# --- 4. Desinstaladores huerfanos que coincidan ---
Get-ChildItem $claves | ? { $_.GetValue('DisplayName') -match $pat } |
  Select -Expand PSPath | % { Add-Obj ($_ -replace '^.*::') }

# --- 5. Servicios, tareas y arranque (solo aviso) ---
Get-CimInstance Win32_Service | ? { $_.Name -match $pat } | % { "Servicio (revisar a mano): $($_.Name)" }
Get-ScheduledTask | ? { $_.TaskName -match $pat } | % { "Tarea (revisar a mano): $($_.TaskPath)$($_.TaskName)" }
Get-CimInstance Win32_StartupCommand | ? { $_.Caption -match $pat } | % { "Inicio: $($_.Name)" }

# --- Resultado ---
$lista = $objetivos | Sort -Unique
"`n=== $($lista.Count) residuos para '$Nombre' (excluyendo: $Excluir) ==="
$lista

if ($Ejecutar) {
  try {
    $log = Join-Path $PSScriptRoot ("Limpieza_{0}_{1}.log" -f ($Nombre -replace '[^\w]','_'), (Get-Date -Format 'yyyyMMdd_HHmmss'))
    "Limpieza de '$Nombre' - $(Get-Date)" | Out-File $log
    "Desinstalados: " + (($sel | % { $_.GetValue('DisplayName') }) -join '; ') | Out-File $log -Append
    "Borrado:" | Out-File $log -Append; $lista | Out-File $log -Append
  } catch {}
  "`n>>> BORRANDO RESIDUOS <<<"
  $lista | Remove-Item -Recurse -Force -Verbose
} else {
  "`n(Simulacion. Repite con -Ejecutar para desinstalar y borrar.)"
}

if ($sel.Count -eq 0 -and $lista.Count -eq 0) { exit 2 } else { exit 0 }
