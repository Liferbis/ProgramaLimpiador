# App.ps1 — Limpiador de PC (interfaz con pestañas, modo oscuro) — portable, Windows PowerShell 5.1+
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
# Barra de titulo oscura (Windows 10 2004+/11)
try { Add-Type -Namespace Win -Name Dwm -MemberDefinition '[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attr, int[] val, int size);' -ErrorAction SilentlyContinue } catch {}

$PS1 = Join-Path $PSScriptRoot 'Limpiador.ps1'
$EXCLUIR = 'Windows|Microsoft Office|SQL Server|Common Files'

# Paleta oscura
$script:BG  = [System.Drawing.Color]::FromArgb(24,24,27)
$script:BG2 = [System.Drawing.Color]::FromArgb(40,40,46)
$script:FG  = [System.Drawing.Color]::FromArgb(230,230,230)
$script:ACC = [System.Drawing.Color]::FromArgb(90,170,230)
$fuente = New-Object System.Drawing.Font('Segoe UI',10)

function Format-Size([long]$b) {
  if ($b -ge 1GB) { return ('{0:N2} GB' -f ($b/1GB)) }
  if ($b -ge 1MB) { return ('{0:N1} MB' -f ($b/1MB)) }
  if ($b -ge 1KB) { return ('{0:N0} KB' -f ($b/1KB)) }
  return "$b B"
}

# --- Trabajos en segundo plano (UI fluida) ---
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
$form.BackColor = $script:BG; $form.ForeColor = $script:FG; $form.Font = $fuente
$form.MinimumSize = New-Object System.Drawing.Size(820, 540)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = 'Fill'
$tabs.SizeMode = 'Fixed'
$tabs.ItemSize = New-Object System.Drawing.Size(140, 30)
$tabs.DrawMode = 'OwnerDrawFixed'
$tabs.BackColor = $script:BG; $tabs.ForeColor = $script:FG
$tabs.Add_DrawItem({
  param($sender, $e)
  $sel = ($e.Index -eq $sender.SelectedIndex)
  $back = if ($sel) { $script:BG2 } else { $script:BG }
  $brB = New-Object System.Drawing.SolidBrush($back)
  $e.Graphics.FillRectangle($brB, $e.Bounds)
  if ($sel) {
    $penA = New-Object System.Drawing.Pen($script:ACC, 2)
    $e.Graphics.DrawLine($penA, $e.Bounds.Left, $e.Bounds.Bottom-1, $e.Bounds.Right, $e.Bounds.Bottom-1)
    $penA.Dispose()
  }
  $brT = New-Object System.Drawing.SolidBrush($script:FG)
  $sf = New-Object System.Drawing.StringFormat
  $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
  $rf = New-Object System.Drawing.RectangleF($e.Bounds.X, $e.Bounds.Y, $e.Bounds.Width, $e.Bounds.Height)
  $e.Graphics.DrawString($sender.TabPages[$e.Index].Text, $sender.Font, $brT, $rf, $sf)
  $brB.Dispose(); $brT.Dispose(); $sf.Dispose()
})
$form.Controls.Add($tabs)

function New-Tab($titulo) {
  $t = New-Object System.Windows.Forms.TabPage
  $t.Text = $titulo; $t.BackColor = $script:BG; $t.ForeColor = $script:FG
  $t.UseVisualStyleBackColor = $false
  $t.Padding = New-Object System.Windows.Forms.Padding(12)
  $tabs.TabPages.Add($t); return $t
}
function New-Lbl($txt, $x, $y) {
  $l = New-Object System.Windows.Forms.Label
  $l.Text = $txt; $l.AutoSize = $true; $l.ForeColor = $script:FG
  $l.Location = New-Object System.Drawing.Point($x, $y)
  return $l
}
function Style-Btn($b) {
  $b.FlatStyle = 'Flat'; $b.BackColor = $script:BG2; $b.ForeColor = $script:FG
  $b.FlatAppearance.BorderColor = $script:ACC
}

# =================== PESTAÑA 1: LIMPIADOR ===================
$tabLimp = New-Tab 'Limpiador'
$tabLimp.Controls.Add((New-Lbl 'Programa a eliminar:' 12 16))

$txtN = New-Object System.Windows.Forms.TextBox
$txtN.Location = New-Object System.Drawing.Point(150,13); $txtN.Width = 320
$txtN.BackColor = $script:BG2; $txtN.ForeColor = $script:FG; $txtN.BorderStyle = 'FixedSingle'
$tabLimp.Controls.Add($txtN)

$btnBuscar = New-Object System.Windows.Forms.Button
$btnBuscar.Text = 'Buscar'; $btnBuscar.Location = New-Object System.Drawing.Point(480,11); $btnBuscar.Width = 100; Style-Btn $btnBuscar
$tabLimp.Controls.Add($btnBuscar)

$lstM = New-Object System.Windows.Forms.ListBox
$lstM.Location = New-Object System.Drawing.Point(12,48); $lstM.Size = New-Object System.Drawing.Size(568, 150)
$lstM.BackColor = $script:BG2; $lstM.ForeColor = $script:FG; $lstM.BorderStyle = 'FixedSingle'
$tabLimp.Controls.Add($lstM)

$chkTodas = New-Object System.Windows.Forms.CheckBox
$chkTodas.Text = 'Todas las coincidencias'; $chkTodas.AutoSize = $true
$chkTodas.ForeColor = $script:FG; $chkTodas.Location = New-Object System.Drawing.Point(12,205)
$tabLimp.Controls.Add($chkTodas)

$btnSim = New-Object System.Windows.Forms.Button
$btnSim.Text = 'Simular'; $btnSim.Location = New-Object System.Drawing.Point(300,202); $btnSim.Width = 130; Style-Btn $btnSim
$tabLimp.Controls.Add($btnSim)
$btnLimp = New-Object System.Windows.Forms.Button
$btnLimp.Text = 'Desinstalar y limpiar'; $btnLimp.Location = New-Object System.Drawing.Point(440,202); $btnLimp.Width = 150; Style-Btn $btnLimp
$tabLimp.Controls.Add($btnLimp)

$outL = New-Object System.Windows.Forms.TextBox
$outL.Location = New-Object System.Drawing.Point(12,240); $outL.Multiline = $true; $outL.ScrollBars = 'Vertical'; $outL.ReadOnly = $true
$outL.Size = New-Object System.Drawing.Size(915, 320)
$outL.BackColor = [System.Drawing.Color]::FromArgb(16,16,18); $outL.ForeColor = [System.Drawing.Color]::FromArgb(130,230,150)
$outL.Font = New-Object System.Drawing.Font('Consolas', 9); $outL.BorderStyle = 'FixedSingle'
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
  if ($ejecutar) { $outL.Text = 'Desinstalando y limpiando...' } else { $outL.Text = 'Analizando...' }
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
$lblRec.Location = New-Object System.Drawing.Point(16,16); $lblRec.AutoSize = $true; $lblRec.ForeColor = $script:FG
$lblRec.Font = New-Object System.Drawing.Font('Consolas', 12)
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
    if ($d.Size) { $pd = [math]::Round(($us / $d.Size) * 100) } else { $pd = 0 }
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
$btnScan.Text = 'Escanear C:'; $btnScan.Location = New-Object System.Drawing.Point(12,12); $btnScan.Width = 130; Style-Btn $btnScan
$tabTop.Controls.Add($btnScan)
$lblScan = New-Lbl 'Pulsa Escanear (tarda; se ejecuta en segundo plano).' 155 18
$tabTop.Controls.Add($lblScan)

$lv = New-Object System.Windows.Forms.ListView
$lv.Location = New-Object System.Drawing.Point(12,48); $lv.Size = New-Object System.Drawing.Size(915, 505)
$lv.View = 'Details'; $lv.FullRowSelect = $true; $lv.GridLines = $true
$lv.BackColor = $script:BG2; $lv.ForeColor = $script:FG
$lv.Anchor = 'Top,Bottom,Left,Right'
[void]$lv.Columns.Add('#', 40)
[void]$lv.Columns.Add('Tamaño', 110)
[void]$lv.Columns.Add('Archivo', 260)
[void]$lv.Columns.Add('Ruta', 480)
$tabTop.Controls.Add($lv)

$btnAbrir = New-Object System.Windows.Forms.Button
$btnAbrir.Text = 'Abrir carpeta'; $btnAbrir.Location = New-Object System.Drawing.Point(12,560); $btnAbrir.Width = 130; Style-Btn $btnAbrir
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

# =================== Timer global de 2º plano ===================
$poll = New-Object System.Windows.Forms.Timer
$poll.Interval = 300
$poll.Add_Tick({
  if ($script:bg.Count -eq 0) { return }
  $pend = @($script:bg.ToArray())
  foreach ($j in $pend) {
    if ($j.H.IsCompleted) {
      try { $out = $j.P.EndInvoke($j.H) } catch { $out = @("Error: $($_.Exception.Message)") }
      try { & $j.D $out } catch {}
      $j.P.Dispose(); $j.R.Close(); $j.R.Dispose()
      [void]$script:bg.Remove($j)
    }
  }
})
$poll.Start()

$form.Add_Shown({
  try { $dark = @(1); [Win.Dwm]::DwmSetWindowAttribute($form.Handle, 20, $dark, 4) | Out-Null; [Win.Dwm]::DwmSetWindowAttribute($form.Handle, 19, $dark, 4) | Out-Null } catch {}
  try { Update-Recursos } catch {}
  $timRec.Start()
})
$form.Add_FormClosing({ $poll.Stop(); $timRec.Stop() })

[void]$form.ShowDialog()
