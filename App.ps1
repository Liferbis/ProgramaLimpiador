# App.ps1 — Limpiador de PC (interfaz con pestañas) — portable, requiere Windows PowerShell 5.1+
# Pestañas: Limpiador · Recursos · Top 100 archivos pesados

# --- Auto-elevacion a administrador ---
$pr = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Start-Process powershell "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`"" -Verb RunAs
  return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$PS1 = Join-Path $PSScriptRoot 'Limpiador.ps1'
$EXCLUIR = 'Windows|Microsoft Office|SQL Server|Common Files'

# Colores
$BG   = [System.Drawing.Color]::FromArgb(28,28,30)
$BG2  = [System.Drawing.Color]::FromArgb(40,40,44)
$FG   = [System.Drawing.Color]::Gainsboro
$ACC  = [System.Drawing.Color]::FromArgb(90,180,230)
$fuente = New-Object System.Drawing.Font('Segoe UI',10)

function Format-Size([long]$b) {
  if ($b -ge 1GB) { return ('{0:N2} GB' -f ($b/1GB)) }
  if ($b -ge 1MB) { return ('{0:N1} MB' -f ($b/1MB)) }
  if ($b -ge 1KB) { return ('{0:N0} KB' -f ($b/1KB)) }
  return "$b B"
}

# --- Infraestructura de trabajos en segundo plano (UI fluida) ---
$script:bg = New-Object System.Collections.ArrayList
function Run-Bg($code, [object[]]$arguments, $onDone) {
  $rs = [runspacefactory]::CreateRunspace(); $rs.Open()
  $p = [powershell]::Create(); $p.Runspace = $rs
  [void]$p.AddScript($code)
  foreach ($a in $arguments) { [void]$p.AddArgument($a) }
  $h = $p.BeginInvoke()
  [void]$script:bg.Add([pscustomobject]@{ P = $p; H = $h; R = $rs; D = $onDone })
}

# =================== FORM ===================
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Limpiador de PC'
$form.Size = New-Object System.Drawing.Size(960, 640)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $BG; $form.ForeColor = $FG; $form.Font = $fuente
$form.MinimumSize = New-Object System.Drawing.Size(820, 540)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = 'Fill'; $tabs.Padding = New-Object System.Drawing.Point(14, 6)
$form.Controls.Add($tabs)

# ---------- Helpers de estilo ----------
function New-Tab($titulo) {
  $t = New-Object System.Windows.Forms.TabPage
  $t.Text = $titulo; $t.BackColor = $BG; $t.ForeColor = $FG; $t.Padding = '12,12,12,12'
  $tabs.TabPages.Add($t); return $t
}
function Style-Btn($b) { $b.FlatStyle='Flat'; $b.BackColor=$BG2; $b.ForeColor=$FG; $b.FlatAppearance.BorderColor=$ACC }

# =================== PESTAÑA 1: LIMPIADOR ===================
$tabLimp = New-Tab 'Limpiador'

$lblN = New-Object System.Windows.Forms.Label
$lblN.Text = 'Programa a eliminar:'; $lblN.AutoSize = $true; $lblN.Location = '12,16'
$tabLimp.Controls.Add($lblN)

$txtN = New-Object System.Windows.Forms.TextBox
$txtN.Location = '150,13'; $txtN.Width = 320; $txtN.BackColor = $BG2; $txtN.ForeColor = $FG
$tabLimp.Controls.Add($txtN)

$btnBuscar = New-Object System.Windows.Forms.Button
$btnBuscar.Text = 'Buscar'; $btnBuscar.Location = '480,11'; $btnBuscar.Width = 100; Style-Btn $btnBuscar
$tabLimp.Controls.Add($btnBuscar)

$lstM = New-Object System.Windows.Forms.ListBox
$lstM.Location = '12,48'; $lstM.Size = New-Object System.Drawing.Size(568, 150)
$lstM.BackColor = $BG2; $lstM.ForeColor = $FG; $lstM.BorderStyle = 'FixedSingle'
$tabLimp.Controls.Add($lstM)

$chkTodas = New-Object System.Windows.Forms.CheckBox
$chkTodas.Text = 'Todas las coincidencias'; $chkTodas.AutoSize = $true; $chkTodas.Location = '12,205'
$tabLimp.Controls.Add($chkTodas)

$btnSim = New-Object System.Windows.Forms.Button
$btnSim.Text = 'Simular'; $btnSim.Location = '300,202'; $btnSim.Width = 130; Style-Btn $btnSim
$tabLimp.Controls.Add($btnSim)
$btnLimp = New-Object System.Windows.Forms.Button
$btnLimp.Text = 'Desinstalar y limpiar'; $btnLimp.Location = '440,202'; $btnLimp.Width = 140; Style-Btn $btnLimp
$tabLimp.Controls.Add($btnLimp)

$outL = New-Object System.Windows.Forms.TextBox
$outL.Location = '12,240'; $outL.Multiline = $true; $outL.ScrollBars = 'Vertical'; $outL.ReadOnly = $true
$outL.Size = New-Object System.Drawing.Size(915, 320)
$outL.BackColor = [System.Drawing.Color]::Black; $outL.ForeColor = [System.Drawing.Color]::LightGreen
$outL.Font = New-Object System.Drawing.Font('Consolas', 9)
$outL.Anchor = 'Top,Bottom,Left,Right'
$tabLimp.Controls.Add($outL)

$btnBuscar.Add_Click({
  $n = $txtN.Text.Trim()
  if ($n.Length -lt 3) { $outL.Text = 'Pon al menos 3 letras.'; return }
  $lstM.Items.Clear(); $outL.Text = 'Buscando...'; $btnBuscar.Enabled = $false
  Run-Bg {
    param($ps1, $n, $ex)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ps1 -Nombre $n -Excluir $ex -Listar 2>$null
  } @($PS1, $n, $EXCLUIR) {
    param($res)
    $btnBuscar.Enabled = $true
    $items = @($res | Where-Object { $_ -and "$_".Trim() })
    if ($items.Count -eq 0) { $outL.Text = "Nada instalado se parece a `"$n`". (Se podran limpiar residuos sueltos al pulsar Simular.)" }
    else { foreach ($it in $items) { [void]$lstM.Items.Add("$it") }; $outL.Text = "$($items.Count) coincidencia(s). Elige una o marca 'Todas'." }
  }
})

function Invoke-Limpiador($ejecutar) {
  $n = $txtN.Text.Trim()
  if ($n.Length -lt 3) { $outL.Text = 'Pon al menos 3 letras.'; return }
  $prog = ''
  if ($chkTodas.Checked) { $prog = (@($lstM.Items) -join '|') }
  elseif ($lstM.SelectedItem) { $prog = "$($lstM.SelectedItem)" }
  $outL.Text = if ($ejecutar) { 'Desinstalando y limpiando...' } else { 'Analizando...' }
  $btnSim.Enabled = $false; $btnLimp.Enabled = $false
  Run-Bg {
    param($ps1, $n, $ex, $prog, $ejec)
    if ($ejec) { & powershell -NoProfile -ExecutionPolicy Bypass -File $ps1 -Nombre $n -Excluir $ex -Programas $prog -Ejecutar 2>&1 }
    else { & powershell -NoProfile -ExecutionPolicy Bypass -File $ps1 -Nombre $n -Excluir $ex -Programas $prog 2>&1 }
  } @($PS1, $n, $EXCLUIR, $prog, [bool]$ejecutar) {
    param($res)
    $btnSim.Enabled = $true; $btnLimp.Enabled = $true
    $outL.Text = (@($res) -join "`r`n")
  }
}
$btnSim.Add_Click({ Invoke-Limpiador $false })
$btnLimp.Add_Click({
  $r = [System.Windows.Forms.MessageBox]::Show('Esto desinstala y BORRA residuos de forma permanente. Continuar?', 'Confirmar', 'YesNo', 'Warning')
  if ($r -eq 'Yes') { Invoke-Limpiador $true }
})

# =================== PESTAÑA 2: RECURSOS ===================
$tabRec = New-Tab 'Recursos'
$lblRec = New-Object System.Windows.Forms.Label
$lblRec.Location = '12,12'; $lblRec.AutoSize = $true
$lblRec.Font = New-Object System.Drawing.Font('Consolas', 11)
$lblRec.Text = 'Cargando...'
$tabRec.Controls.Add($lblRec)

function Update-Recursos {
  $os  = Get-CimInstance Win32_OperatingSystem
  $cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
  $ramTot = $os.TotalVisibleMemorySize * 1KB
  $ramLibre = $os.FreePhysicalMemory * 1KB
  $ramUso = $ramTot - $ramLibre
  $pRam = [math]::Round(($ramUso / $ramTot) * 100)
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("CPU:  $([int]$cpu) %")
  [void]$sb.AppendLine("RAM:  $(Format-Size $ramUso) / $(Format-Size $ramTot)  ($pRam %)")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("Discos:")
  foreach ($d in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3') {
    $us = $d.Size - $d.FreeSpace
    $pd = if ($d.Size) { [math]::Round(($us / $d.Size) * 100) } else { 0 }
    [void]$sb.AppendLine(("  {0}  {1} / {2}  ({3}% usado, {4} libre)" -f $d.DeviceID, (Format-Size $us), (Format-Size $d.Size), $pd, (Format-Size $d.FreeSpace)))
  }
  $lblRec.Text = $sb.ToString()
}
$timRec = New-Object System.Windows.Forms.Timer
$timRec.Interval = 2000
$timRec.Add_Tick({ try { Update-Recursos } catch {} })

# =================== PESTAÑA 3: TOP 100 PESADOS ===================
$tabTop = New-Tab 'Top 100 pesados'
$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = 'Escanear C:'; $btnScan.Location = '12,12'; $btnScan.Width = 130; Style-Btn $btnScan
$tabTop.Controls.Add($btnScan)
$lblScan = New-Object System.Windows.Forms.Label
$lblScan.Location = '155,18'; $lblScan.AutoSize = $true; $lblScan.Text = 'Pulsa Escanear (tarda; se ejecuta en segundo plano).'
$tabTop.Controls.Add($lblScan)

$lv = New-Object System.Windows.Forms.ListView
$lv.Location = '12,48'; $lv.Size = New-Object System.Drawing.Size(915, 510)
$lv.View = 'Details'; $lv.FullRowSelect = $true; $lv.GridLines = $true
$lv.BackColor = $BG2; $lv.ForeColor = $FG
$lv.Anchor = 'Top,Bottom,Left,Right'
[void]$lv.Columns.Add('#', 40)
[void]$lv.Columns.Add('Tamaño', 110)
[void]$lv.Columns.Add('Archivo', 260)
[void]$lv.Columns.Add('Ruta', 480)
$tabTop.Controls.Add($lv)

$btnAbrir = New-Object System.Windows.Forms.Button
$btnAbrir.Text = 'Abrir carpeta'; $btnAbrir.Location = '12,565'; $btnAbrir.Width = 130; Style-Btn $btnAbrir
$btnAbrir.Anchor = 'Bottom,Left'
$tabTop.Controls.Add($btnAbrir)
$btnAbrir.Add_Click({
  if ($lv.SelectedItems.Count -gt 0) {
    $ruta = $lv.SelectedItems[0].SubItems[3].Text
    if (Test-Path $ruta) { Start-Process explorer.exe "/select,`"$ruta`"" }
  }
})

$btnScan.Add_Click({
  $btnScan.Enabled = $false; $lblScan.Text = 'Escaneando C:... (puede tardar varios minutos)'; $lv.Items.Clear()
  Run-Bg {
    $skip = '\\(Windows|WinSxS|\$Recycle\.Bin|System Volume Information)\\'
    Get-ChildItem 'C:\' -Recurse -File -Force -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -notmatch $skip } |
      Select-Object FullName, Name, Length |
      Sort-Object Length -Descending | Select-Object -First 100
  } @() {
    param($res)
    $btnScan.Enabled = $true
    $arr = @($res)
    $lv.BeginUpdate(); $lv.Items.Clear()
    $i = 0
    foreach ($f in $arr) {
      $i++
      $it = New-Object System.Windows.Forms.ListViewItem([string]$i)
      [void]$it.SubItems.Add((Format-Size $f.Length))
      [void]$it.SubItems.Add($f.Name)
      [void]$it.SubItems.Add($f.FullName)
      [void]$lv.Items.Add($it)
    }
    $lv.EndUpdate()
    $lblScan.Text = "Listo: $($arr.Count) archivos mas pesados de C:."
  }
})

# =================== Timer global de trabajos en 2º plano ===================
$poll = New-Object System.Windows.Forms.Timer
$poll.Interval = 300
$poll.Add_Tick({
  if ($script:bg.Count -eq 0) { return }
  $pend = @($script:bg.ToArray())
  foreach ($j in $pend) {
    if ($j.H.IsCompleted) {
      $out = $null
      try { $out = $j.P.EndInvoke($j.H) } catch { $out = @("Error: $($_.Exception.Message)") }
      try { & $j.D $out } catch {}
      $j.P.Dispose(); $j.R.Close(); $j.R.Dispose()
      [void]$script:bg.Remove($j)
    }
  }
})
$poll.Start()

# Recursos: primera lectura + arranque del timer al mostrar
$form.Add_Shown({ try { Update-Recursos } catch {}; $timRec.Start() })
$form.Add_FormClosing({ $poll.Stop(); $timRec.Stop() })

[void]$form.ShowDialog()
