﻿# App.ps1 — Limpiador de PC (interfaz con pestañas, modo oscuro) — portable, Windows PowerShell 5.1+
# Pestañas: Limpiador · Recursos · Top 100 archivos pesados

# --- Auto-elevacion a administrador ---
$pr = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
  if ($PSCommandPath) { Start-Process powershell "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`"" -Verb RunAs }
  return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
try { Add-Type -Namespace Win -Name Dwm -MemberDefinition '[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attr, int[] val, int size);' -ErrorAction SilentlyContinue } catch {}

$baseDir = $PSScriptRoot
if (-not $baseDir) { if ($MyInvocation.MyCommand.Path) { $baseDir = Split-Path $MyInvocation.MyCommand.Path } }
if (-not $baseDir) { try { $baseDir = Split-Path ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) } catch {} }
$PS1 = Join-Path $baseDir 'Limpiador.ps1'
$EXCLUIR = 'Windows|Microsoft Office|SQL Server|Common Files'

$BG  = [System.Drawing.Color]::FromArgb(24,24,27)
$BG2 = [System.Drawing.Color]::FromArgb(40,40,46)
$FG  = [System.Drawing.Color]::FromArgb(230,230,230)
$ACC = [System.Drawing.Color]::FromArgb(90,170,230)
$fuente = New-Object System.Drawing.Font('Segoe UI',10)

function Format-Size([long]$b) {
  if ($b -ge 1GB) { return ('{0:N2} GB' -f ($b/1GB)) }
  if ($b -ge 1MB) { return ('{0:N1} MB' -f ($b/1MB)) }
  if ($b -ge 1KB) { return ('{0:N0} KB' -f ($b/1KB)) }
  return "$b B"
}

function Describe-File($name, $path) {
  $n = "$name".ToLower(); $p = "$path".ToLower()
  switch -Regex ($n) {
    '^hiberfil\.sys$'  { return 'Hibernación de Windows' }
    '^pagefile\.sys$'  { return 'Memoria virtual (paginación)' }
    '^swapfile\.sys$'  { return 'Archivo de intercambio' }
    '\.ost$'           { return 'Buzón de Outlook sin conexión' }
    '\.pst$'           { return 'Correo de Outlook' }
    '\.vhdx?\.zst$'    { return 'Disco virtual comprimido' }
    '\.vhdx?$'         { return 'Disco virtual (VM/WSL)' }
    '\.(zip|7z|rar|tar|gz|tgz|bz2|xz)$' { return 'Archivo comprimido' }
    '\.(iso|img)$'     { return 'Imagen de disco' }
    '\.dmp$'           { return 'Volcado de memoria (crash)' }
    '\.(mp4|mkv|avi|mov|wmv|flv)$'      { return 'Vídeo' }
    '\.(db|sqlite|mdf|ldf|bak)$'        { return 'Base de datos / backup' }
    '\.(exe|msi)$'     { return 'Instalador / ejecutable' }
    '\.ppkg$'          { return 'Paquete de aprovisionamiento' }
    '\.log$'           { return 'Registro (log)' }
  }
  if ($p -match 'claude')        { return 'Datos de Claude' }
  if ($p -match 'snagit')        { return 'Snagit (capturas)' }
  if ($p -match 'onedrive')      { return 'En OneDrive' }
  if ($p -match '\\recovery\\')  { return 'Recuperación de Windows' }
  if ($p -match '\\teams')       { return 'Microsoft Teams' }
  if ($p -match '\\temp\\|\\tmp\\') { return 'Temporal' }
  if ($p -match 'node_modules')  { return 'Dependencias de desarrollo' }
  return ''
}

function Get-Categoria($dn) {
  $t = "$dn".ToLower()
  if ($t -match 'microsoft|office|onedrive|teams|visual c\+\+|\.net| sql |odbc|ole db|edge|copilot|windows') { return 'Microsoft' }
  if ($t -match 'chrome|brave|firefox|opera|navegador|vivaldi') { return 'Navegadores' }
  if ($t -match 'forticlient|globalprotect|ivanti|anydesk|teamviewer|vpn|pulse|secure access|remote') { return 'Acceso remoto y seguridad' }
  if ($t -match 'git|dbeaver|azure data|node|python|java|docker|postman|visual studio|sublime|eclipse|sdk|putty') { return 'Desarrollo' }
  if ($t -match '\bhp\b|hewlett|epson|canon|logi|logitech|intel|nvidia|realtek|driver|controlador|printer|scanner|fnmt|autofirma') { return 'Equipo (drivers y utilidades)' }
  if ($t -match '7-zip|winrar|notepad|vlc|adobe|acrobat|reader|snagit|zoom|skype|spotify|office') { return 'Aplicaciones' }
  return 'Otros'
}

# --- Trabajos en segundo plano ---
$global:limpBg = New-Object System.Collections.ArrayList
function Run-Bg($code, [object[]]$arguments, $onDone) {
  $rs = [runspacefactory]::CreateRunspace(); $rs.Open()
  $p = [powershell]::Create(); $p.Runspace = $rs
  [void]$p.AddScript($code)
  foreach ($a in $arguments) { [void]$p.AddArgument($a) }
  $h = $p.BeginInvoke()
  [void]$global:limpBg.Add([pscustomobject]@{ P = $p; H = $h; R = $rs; D = $onDone })
}

# =================== FORM ===================
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Limpiador de PC'
$form.Size = New-Object System.Drawing.Size(980, 680)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $BG; $form.ForeColor = $FG; $form.Font = $fuente
$form.MinimumSize = New-Object System.Drawing.Size(860, 560)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = 'Fill'; $tabs.SizeMode = 'Fixed'
$tabs.ItemSize = New-Object System.Drawing.Size(150, 30)
$tabs.DrawMode = 'OwnerDrawFixed'
$tabs.BackColor = $BG; $tabs.ForeColor = $FG
$tabs.Add_DrawItem({
  param($sender, $e)
  try {
    $cBG2 = [System.Drawing.Color]::FromArgb(40,40,46); $cBG = [System.Drawing.Color]::FromArgb(24,24,27)
    $cFG = [System.Drawing.Color]::FromArgb(230,230,230); $cACC = [System.Drawing.Color]::FromArgb(90,170,230)
    $sel = ($e.Index -eq $sender.SelectedIndex)
    if ($sel) { $back = $cBG2 } else { $back = $cBG }
    $brB = New-Object System.Drawing.SolidBrush($back); $e.Graphics.FillRectangle($brB, $e.Bounds)
    if ($sel) { $penA = New-Object System.Drawing.Pen($cACC, 2); $e.Graphics.DrawLine($penA, $e.Bounds.Left, $e.Bounds.Bottom-1, $e.Bounds.Right, $e.Bounds.Bottom-1); $penA.Dispose() }
    $brT = New-Object System.Drawing.SolidBrush($cFG)
    $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
    $rf = New-Object System.Drawing.RectangleF($e.Bounds.X, $e.Bounds.Y, $e.Bounds.Width, $e.Bounds.Height)
    $e.Graphics.DrawString($sender.TabPages[$e.Index].Text, $sender.Font, $brT, $rf, $sf)
    $brB.Dispose(); $brT.Dispose(); $sf.Dispose()
  } catch {}
})
$form.Controls.Add($tabs)

function New-Tab($titulo) {
  $t = New-Object System.Windows.Forms.TabPage
  $t.Text = $titulo; $t.BackColor = $BG; $t.ForeColor = $FG; $t.UseVisualStyleBackColor = $false
  $t.Padding = New-Object System.Windows.Forms.Padding(12)
  $tabs.TabPages.Add($t); return $t
}
function New-Lbl($txt, $x, $y) {
  $l = New-Object System.Windows.Forms.Label
  $l.Text = $txt; $l.AutoSize = $true; $l.ForeColor = $FG
  $l.Location = New-Object System.Drawing.Point($x, $y); return $l
}
function Style-Btn($b) { $b.FlatStyle = 'Flat'; $b.BackColor = $BG2; $b.ForeColor = $FG; $b.FlatAppearance.BorderColor = $ACC }

# =================== PESTAÑA 1: LIMPIADOR ===================
$tabLimp = New-Tab 'Limpiador'
$tabLimp.Controls.Add((New-Lbl 'Programa a eliminar:' 12 16))

$txtN = New-Object System.Windows.Forms.TextBox
$txtN.Location = New-Object System.Drawing.Point(160,13); $txtN.Width = 330
$txtN.BackColor = $BG2; $txtN.ForeColor = $FG; $txtN.BorderStyle = 'FixedSingle'
$tabLimp.Controls.Add($txtN)
$btnBuscar = New-Object System.Windows.Forms.Button
$btnBuscar.Text = 'Buscar'; $btnBuscar.Location = New-Object System.Drawing.Point(500,11); $btnBuscar.Width = 100; Style-Btn $btnBuscar
$tabLimp.Controls.Add($btnBuscar)
$btnTodos = New-Object System.Windows.Forms.Button
$btnTodos.Text = 'Ver todos'; $btnTodos.Location = New-Object System.Drawing.Point(610,11); $btnTodos.Width = 100; Style-Btn $btnTodos
$tabLimp.Controls.Add($btnTodos)

$tree = New-Object System.Windows.Forms.TreeView
$tree.Location = New-Object System.Drawing.Point(12,48); $tree.Size = New-Object System.Drawing.Size(935, 380)
$tree.BackColor = $BG2; $tree.ForeColor = $FG; $tree.BorderStyle = 'FixedSingle'
$tree.HideSelection = $false; $tree.CheckBoxes = $true; $tree.Anchor = 'Top,Bottom,Left'
$tabLimp.Controls.Add($tree)
$tree.Add_AfterCheck({
  param($s, $e)
  try { if ("$($e.Action)" -ne 'Unknown' -and $e.Node.Nodes.Count -gt 0) { foreach ($c in $e.Node.Nodes) { $c.Checked = $e.Node.Checked } } } catch {}
})

$btnDes = New-Object System.Windows.Forms.Button
$btnDes.Text = 'Desinstalar (y limpiar residuos)'; $btnDes.Location = New-Object System.Drawing.Point(12,434); $btnDes.Width = 240; Style-Btn $btnDes; $btnDes.Anchor='Bottom,Left'
$tabLimp.Controls.Add($btnDes)
$btnCarp = New-Object System.Windows.Forms.Button
$btnCarp.Text = 'Listar carpetas'; $btnCarp.Location = New-Object System.Drawing.Point(262,434); $btnCarp.Width = 150; Style-Btn $btnCarp; $btnCarp.Anchor='Bottom,Left'
$tabLimp.Controls.Add($btnCarp)
$btnCache = New-Object System.Windows.Forms.Button
$btnCache.Text = 'Limpiar cache'; $btnCache.Location = New-Object System.Drawing.Point(422,434); $btnCache.Width = 150; Style-Btn $btnCache; $btnCache.Anchor='Bottom,Left'
$tabLimp.Controls.Add($btnCache)

$outL = New-Object System.Windows.Forms.TextBox
$outL.Location = New-Object System.Drawing.Point(12,470); $outL.Multiline = $true; $outL.ScrollBars = 'Vertical'; $outL.ReadOnly = $true
$outL.Size = New-Object System.Drawing.Size(935, 115)
$outL.BackColor = [System.Drawing.Color]::FromArgb(16,16,18); $outL.ForeColor = [System.Drawing.Color]::FromArgb(130,230,150)
$outL.Font = New-Object System.Drawing.Font('Consolas', 9); $outL.BorderStyle = 'FixedSingle'; $outL.Anchor = 'Bottom,Left'
$tabLimp.Controls.Add($outL)

function Llenar-Arbol($nombres, $busqueda) {
  $tree.BeginUpdate(); $tree.Nodes.Clear()
  if ($busqueda) {
    $cat = $tree.Nodes.Add("Resultados de la busqueda ($($nombres.Count))")
    foreach ($nm in $nombres) { [void]$cat.Nodes.Add("$nm") }
    $cat.Expand()
  } else {
    $grupos = @{}
    foreach ($nm in $nombres) {
      $c = Get-Categoria $nm
      if (-not $grupos.ContainsKey($c)) { $grupos[$c] = New-Object System.Collections.ArrayList }
      [void]$grupos[$c].Add($nm)
    }
    foreach ($c in ($grupos.Keys | Sort-Object)) {
      $node = $tree.Nodes.Add("$c  ($($grupos[$c].Count))")
      foreach ($nm in ($grupos[$c] | Sort-Object)) { [void]$node.Nodes.Add("$nm") }
    }
  }
  $tree.EndUpdate()
}
function Prog-Seleccionado {
  $n = $tree.SelectedNode
  if ($n -and $n.Parent -and $n.Nodes.Count -eq 0) { return $n.Text }
  return ''
}
function Todas-Hojas {
  $out = New-Object System.Collections.ArrayList
  foreach ($cat in $tree.Nodes) { foreach ($leaf in $cat.Nodes) { [void]$out.Add($leaf.Text) } }
  return $out
}
function Cargar-Todos {
  $outL.Text = 'Cargando la lista de programas instalados...'; $tree.Nodes.Clear(); $global:esBusqueda = $false
  Run-Bg {
    $claves = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
              'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
              'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    Get-ChildItem $claves -ErrorAction SilentlyContinue | ForEach-Object {
      $dn = $_.GetValue('DisplayName'); $sc = $_.GetValue('SystemComponent')
      if ($dn -and $sc -ne 1) { $dn }
    } | Sort-Object -Unique
  } @() {
    param($res)
    $items = @($res | Where-Object { $_ -and "$_".Trim() })
    Llenar-Arbol $items $false
    $outL.Text = "$($items.Count) programas instalados, agrupados por categoria. Despliega una categoria y elige, o busca por nombre."
  }
}
$btnTodos.Add_Click({ Cargar-Todos })
$btnBuscar.Add_Click({
  $n = $txtN.Text.Trim()
  if ($n.Length -lt 3) { Cargar-Todos; return }
  $tree.Nodes.Clear(); $outL.Text = 'Buscando...'; $btnBuscar.Enabled = $false; $global:esBusqueda = $true
  Run-Bg {
    param($ps1, $n, $ex)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ps1 -Nombre $n -Excluir $ex -Listar 2>$null
  } @($PS1, $n, $EXCLUIR) {
    param($res)
    $btnBuscar.Enabled = $true
    $items = @($res | Where-Object { $_ -and "$_".Trim() })
    if ($items.Count -eq 0) { $tree.Nodes.Clear(); $outL.Text = "Nada instalado se parece. Se podran limpiar residuos sueltos al pulsar Simular." }
    else { Llenar-Arbol $items $true; $outL.Text = "$($items.Count) coincidencia(s). Elige una o marca 'Todas'." }
  }
})

function Prog-Marcados {
  $out = New-Object System.Collections.ArrayList
  foreach ($cat in $tree.Nodes) { foreach ($leaf in $cat.Nodes) { if ($leaf.Checked) { [void]$out.Add($leaf.Text) } } }
  return $out
}
function Es-Cache($p) { return ("$p" -match '(?i)(\\|/)(cache|caches|gpucache|code ?cache|codecache|crashpad|temp|tmp|logs?|dumps?|webcache|inetcache)(\\|/|$)') }
function Habilitar-Acc($on) { $btnDes.Enabled = $on; $btnCarp.Enabled = $on; $btnCache.Enabled = $on }

$btnDes.Add_Click({
  $marc = Prog-Marcados
  if ($marc.Count -eq 0) { $outL.Text = 'Marca al menos un programa (casilla del arbol).'; return }
  $r = [System.Windows.Forms.MessageBox]::Show("Vas a DESINSTALAR y limpiar residuos de $($marc.Count) programa(s). Es permanente. Continuar?", 'Confirmar', 'YesNo', 'Warning')
  if ($r -ne 'Yes') { return }
  $prog = (@($marc) -join '|'); $n = "$($marc[0])"
  $outL.Text = 'Desinstalando y limpiando...'; Habilitar-Acc $false
  Run-Bg {
    param($ps1, $n, $ex, $prog)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ps1 -Nombre $n -Excluir $ex -Programas $prog -Ejecutar 2>&1
  } @($PS1, $n, $EXCLUIR, $prog) {
    param($res); Habilitar-Acc $true; $outL.Text = (@($res) -join "`r`n")
  }
})

$btnCarp.Add_Click({
  $marc = Prog-Marcados
  if ($marc.Count -eq 0) { $outL.Text = 'Marca al menos un programa.'; return }
  $prog = (@($marc) -join '|'); $n = "$($marc[0])"; $outL.Text = 'Buscando carpetas...'; Habilitar-Acc $false
  Run-Bg {
    param($ps1, $n, $ex, $prog)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ps1 -Nombre $n -Excluir $ex -Programas $prog -SoloRutas 2>$null
  } @($PS1, $n, $EXCLUIR, $prog) {
    param($res)
    Habilitar-Acc $true
    $paths = @($res | Where-Object { $_ -and "$_".Trim() })
    $cache = @($paths | Where-Object { Es-Cache $_ })
    $datos = @($paths | Where-Object { -not (Es-Cache $_) })
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("== Datos / instalacion ($($datos.Count)) ==")
    foreach ($d in $datos) { [void]$sb.AppendLine("  $d") }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("== Cache / temporales ($($cache.Count)) ==")
    foreach ($c in $cache) { [void]$sb.AppendLine("  $c") }
    $outL.Text = $sb.ToString()
  }
})

$btnCache.Add_Click({
  $marc = Prog-Marcados
  if ($marc.Count -eq 0) { $outL.Text = 'Marca al menos un programa.'; return }
  $prog = (@($marc) -join '|'); $n = "$($marc[0])"; $outL.Text = 'Localizando cache...'; Habilitar-Acc $false
  Run-Bg {
    param($ps1, $n, $ex, $prog)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ps1 -Nombre $n -Excluir $ex -Programas $prog -SoloRutas 2>$null
  } @($PS1, $n, $EXCLUIR, $prog) {
    param($res)
    Habilitar-Acc $true
    $paths = @($res | Where-Object { $_ -and "$_".Trim() })
    $cache = @($paths | Where-Object { Es-Cache $_ })
    if ($cache.Count -eq 0) { $outL.Text = 'No se han encontrado carpetas de cache para lo marcado.'; return }
    $r = [System.Windows.Forms.MessageBox]::Show("Se borraran $($cache.Count) elementos de cache. El programa NO se desinstala. Continuar?", 'Limpiar cache', 'YesNo', 'Warning')
    if ($r -ne 'Yes') { $outL.Text = 'Cancelado.'; return }
    $outL.Text = 'Borrando cache...'; Habilitar-Acc $false
    Run-Bg {
      param($lst)
      $lst | ForEach-Object { $ruta = $_; try { Remove-Item -LiteralPath $ruta -Recurse -Force -ErrorAction Stop; "OK  $ruta" } catch { "NO  $ruta" } }
    } (,$cache) {
      param($r2); Habilitar-Acc $true; $outL.Text = ("Limpieza de cache:`r`n" + (@($r2) -join "`r`n"))
    }
  }
})

# =================== PESTAÑA 2: RECURSOS ===================
$tabRec = New-Tab 'Recursos'
$txtRec = New-Object System.Windows.Forms.TextBox
$txtRec.Multiline = $true; $txtRec.ReadOnly = $true; $txtRec.ScrollBars = 'Vertical'
$txtRec.Dock = 'Fill'; $txtRec.BorderStyle = 'None'
$txtRec.BackColor = $BG; $txtRec.ForeColor = $FG
$txtRec.Font = New-Object System.Drawing.Font('Consolas', 11); $txtRec.Text = 'Cargando...'
$tabRec.Controls.Add($txtRec)

function Get-Estatico {
  $cs   = Get-CimInstance Win32_ComputerSystem
  $os   = Get-CimInstance Win32_OperatingSystem
  $bios = Get-CimInstance Win32_BIOS
  $cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
  $gpu  = Get-CimInstance Win32_VideoController | Where-Object { $_.Name } | Select-Object -First 1
  $arr  = Get-CimInstance Win32_PhysicalMemoryArray | Select-Object -First 1
  $mods = @(Get-CimInstance Win32_PhysicalMemory)
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("Equipo:    $($cs.Name)")
  if ($cs.PartOfDomain) { [void]$sb.AppendLine("Dominio:   $($cs.Domain)") } else { [void]$sb.AppendLine("Grupo:     $($cs.Workgroup)  (no en dominio)") }
  [void]$sb.AppendLine("Usuario:   $($cs.UserName)")
  [void]$sb.AppendLine("Modelo:    $("$($cs.Manufacturer) $($cs.Model)".Trim())")
  [void]$sb.AppendLine("N/Serie:   $("$($bios.SerialNumber)".Trim())")
  [void]$sb.AppendLine("BIOS:      $($bios.SMBIOSBIOSVersion)  ($("$($bios.Manufacturer)".Trim()))")
  [void]$sb.AppendLine("SO:        $($os.Caption)  build $($os.BuildNumber)  ($($os.OSArchitecture))")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("CPU:       $("$($cpu.Name)".Trim())")
  [void]$sb.AppendLine("           $($cpu.NumberOfCores) nucleos / $($cpu.NumberOfLogicalProcessors) hilos  -  $([math]::Round($cpu.MaxClockSpeed/1000,2)) GHz")
  if ($gpu) { [void]$sb.AppendLine("GPU:       $($gpu.Name)") }
  [void]$sb.AppendLine("")
  if ($arr) { $slots = $arr.MemoryDevices } else { $slots = $mods.Count }
  [void]$sb.AppendLine("RAM:       $($mods.Count) de $slots slots ocupados")
  foreach ($m in $mods) {
    switch ([int]$m.SMBIOSMemoryType) {
      20 { $tipo='DDR' } 21 { $tipo='DDR2' } 24 { $tipo='DDR3' } 26 { $tipo='DDR4' } 34 { $tipo='DDR5' } default { $tipo="tipo $($m.SMBIOSMemoryType)" }
    }
    if ($m.ConfiguredClockSpeed) { $sp = $m.ConfiguredClockSpeed } else { $sp = $m.Speed }
    [void]$sb.AppendLine(("  [{0}]  {1}  {2}  {3} MHz  {4}" -f $m.DeviceLocator, (Format-Size ([long]$m.Capacity)), $tipo, $sp, "$($m.Manufacturer)".Trim()))
  }
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("Discos fisicos:")
  foreach ($dd in Get-CimInstance Win32_DiskDrive) {
    if ("$($dd.InterfaceType)" -eq 'USB' -or "$($dd.MediaType)" -match 'removable|external') { $ubic = 'EXTRAIBLE/USB' } else { $ubic = 'INTERNO' }
    [void]$sb.AppendLine(("  [{0}]  {1}  ({2}, {3})" -f $ubic, "$($dd.Model)".Trim(), (Format-Size ([long]$dd.Size)), $dd.InterfaceType))
  }
  return $sb.ToString()
}
function Update-Recursos {
  if (-not $global:recEstatico) { try { $global:recEstatico = Get-Estatico } catch { $global:recEstatico = '' } }
  $os  = Get-CimInstance Win32_OperatingSystem
  $cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
  $ramTot = $os.TotalVisibleMemorySize * 1KB
  $ramUso = $ramTot - ($os.FreePhysicalMemory * 1KB)
  if ($ramTot) { $pRam = [math]::Round(($ramUso / $ramTot) * 100) } else { $pRam = 0 }
  $up = (Get-Date) - $os.LastBootUpTime
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine($global:recEstatico)
  [void]$sb.AppendLine("------------------------------------------------------------")
  [void]$sb.AppendLine("Uso en vivo:")
  [void]$sb.AppendLine("  CPU:   $([int]$cpu) %")
  [void]$sb.AppendLine("  RAM:   $(Format-Size $ramUso) / $(Format-Size $ramTot)  ($pRam %)")
  [void]$sb.AppendLine(("  Encendido hace:  {0}h {1}m" -f [int]$up.TotalHours, $up.Minutes))
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("Unidades:")
  foreach ($d in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=2 OR DriveType=3') {
    if ($d.DriveType -eq 2) { $et = 'EXTRAIBLE/USB' } else { $et = 'INTERNO    ' }
    $us = $d.Size - $d.FreeSpace
    if ($d.Size) { $pd = [math]::Round(($us / $d.Size) * 100) } else { $pd = 0 }
    [void]$sb.AppendLine(("  {0}  {1}  {2} / {3}  ({4}% usado, {5} libre)" -f $et, $d.DeviceID, (Format-Size $us), (Format-Size $d.Size), $pd, (Format-Size $d.FreeSpace)))
  }
  $txtRec.Text = $sb.ToString()
}
$timRec = New-Object System.Windows.Forms.Timer
$timRec.Interval = 2000
$timRec.Add_Tick({ try { Update-Recursos } catch {} })

# =================== PESTAÑA 3: TOP 100 PESADOS ===================
$tabTop = New-Tab 'Top 100 pesados'
$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = 'Escanear C:'; $btnScan.Location = New-Object System.Drawing.Point(12,12); $btnScan.Width = 130; Style-Btn $btnScan
$tabTop.Controls.Add($btnScan)
$lblScan = New-Lbl 'Pulsa Escanear. Omite Windows y archivos de sistema para ir rapido.' 155 18
$tabTop.Controls.Add($lblScan)

$lv = New-Object System.Windows.Forms.ListView
$lv.Location = New-Object System.Drawing.Point(12,48); $lv.Size = New-Object System.Drawing.Size(945, 525)
$lv.View = 'Details'; $lv.FullRowSelect = $true; $lv.GridLines = $true
$lv.BackColor = $BG2; $lv.ForeColor = $FG; $lv.Anchor = 'Top,Bottom,Left'
[void]$lv.Columns.Add('#', 36)
[void]$lv.Columns.Add('Tamaño', 90)
[void]$lv.Columns.Add('Descripción', 185)
[void]$lv.Columns.Add('Archivo', 235)
[void]$lv.Columns.Add('Ruta', 360)
$tabTop.Controls.Add($lv)
$btnAbrir = New-Object System.Windows.Forms.Button
$btnAbrir.Text = 'Abrir carpeta'; $btnAbrir.Location = New-Object System.Drawing.Point(12,580); $btnAbrir.Width = 130; Style-Btn $btnAbrir; $btnAbrir.Anchor = 'Bottom,Left'
$tabTop.Controls.Add($btnAbrir)
$btnAbrir.Add_Click({
  if ($lv.SelectedItems.Count -gt 0) {
    $ruta = $lv.SelectedItems[0].SubItems[4].Text
    if (Test-Path $ruta) { Start-Process explorer.exe "/select,`"$ruta`"" }
  }
})
$btnScan.Add_Click({
  $btnScan.Enabled = $false; $lblScan.Text = 'Escaneando C:... (en segundo plano, no se cuelga)'; $lv.Items.Clear()
  Run-Bg {
    $skip = '(?i)\\(Windows|WinSxS|\$Recycle\.Bin|System Volume Information|Config\.Msi)(\\|$)'
    $top = New-Object System.Collections.Generic.List[System.Object]
    $thr = [long]0
    $stack = New-Object System.Collections.Stack
    $stack.Push('C:\')
    while ($stack.Count -gt 0) {
      $dir = $stack.Pop()
      if ("$dir" -match $skip) { continue }
      try {
        $di = New-Object System.IO.DirectoryInfo $dir
        if ($di.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { continue }
        foreach ($sd in $di.GetDirectories()) { $stack.Push($sd.FullName) }
        foreach ($fi in $di.GetFiles()) {
          $len = $fi.Length
          if ($top.Count -lt 100 -or $len -gt $thr) {
            $top.Add((New-Object psobject -Property @{ FullName = $fi.FullName; Length = $len }))
            if ($top.Count -ge 220) {
              $keep = $top | Sort-Object Length -Descending | Select-Object -First 100
              $top = New-Object System.Collections.Generic.List[System.Object]
              foreach ($k in $keep) { $top.Add($k) }
              $thr = $top[$top.Count-1].Length
            }
          }
        }
      } catch { continue }
    }
    $top | Sort-Object Length -Descending | Select-Object -First 100
  } @() {
    param($res)
    $btnScan.Enabled = $true
    $arr = @($res)
    $lv.BeginUpdate(); $lv.Items.Clear()
    $i = 0
    foreach ($f in $arr) {
      $i++
      $nom = [System.IO.Path]::GetFileName($f.FullName)
      $it = New-Object System.Windows.Forms.ListViewItem([string]$i)
      [void]$it.SubItems.Add((Format-Size ([long]$f.Length)))
      [void]$it.SubItems.Add((Describe-File $nom $f.FullName))
      [void]$it.SubItems.Add($nom)
      [void]$it.SubItems.Add($f.FullName)
      [void]$lv.Items.Add($it)
    }
    $lv.EndUpdate()
    $lblScan.Text = "Listo: $($arr.Count) archivos mas pesados de C: (sin Windows ni sistema)."
  }
})

# =================== Timer global de 2º plano ===================
$poll = New-Object System.Windows.Forms.Timer
$poll.Interval = 300
$poll.Add_Tick({
  if ($global:limpBg.Count -eq 0) { return }
  $pend = @($global:limpBg.ToArray())
  foreach ($j in $pend) {
    if ($j.H.IsCompleted) {
      try { $out = $j.P.EndInvoke($j.H) } catch { $out = @("Error: $($_.Exception.Message)") }
      try { & $j.D $out } catch {}
      $j.P.Dispose(); $j.R.Close(); $j.R.Dispose()
      [void]$global:limpBg.Remove($j)
    }
  }
})
$poll.Start()

function Ajustar-Anchos {
  try { $w = $tabLimp.ClientSize.Width; if ($w -gt 60) { $tree.Width = $w - 24; $outL.Width = $w - 24 } } catch {}
  try { $wt = $tabTop.ClientSize.Width; if ($wt -gt 60) { $lv.Width = $wt - 24 } } catch {}
}
$form.Add_Resize({ try { Ajustar-Anchos } catch {} })
$form.Add_Shown({
  try { $dark = @(1); [Win.Dwm]::DwmSetWindowAttribute($form.Handle, 20, $dark, 4) | Out-Null; [Win.Dwm]::DwmSetWindowAttribute($form.Handle, 19, $dark, 4) | Out-Null } catch {}
  try { Update-Recursos } catch {}
  $timRec.Start(); Cargar-Todos; try { Ajustar-Anchos } catch {}
})
$form.Add_FormClosing({ $poll.Stop(); $timRec.Stop() })
[void]$form.ShowDialog()
