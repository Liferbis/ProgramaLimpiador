# Elegir.ps1 — Ventana con botones de radio para elegir el programa a limpiar.
# Lee $env:PS1LIM (ruta a Limpiador.ps1), $env:LNOMBRE, $env:LEXCLUIR, $env:SELOUT (fichero de salida).
# Codigos de salida: 0 = elegido (escrito en SELOUT), 1 = cancelado, 2 = sin coincidencias.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ps1 = $env:PS1LIM
$out = $env:SELOUT
$cands = @()
try {
  $cands = @(powershell -NoProfile -ExecutionPolicy Bypass -File $ps1 -Nombre $env:LNOMBRE -Excluir $env:LEXCLUIR -Listar | ? { $_ -and $_.Trim() })
} catch {}
if ($cands.Count -eq 0) { exit 2 }

$form = New-Object System.Windows.Forms.Form
$form.Text = "Limpiador - elegir programa"
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false; $form.MinimizeBox = $false
$form.Width = 500
$form.BackColor = [System.Drawing.Color]::FromArgb(28,28,30)
$form.ForeColor = [System.Drawing.Color]::Gainsboro
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$form.Topmost = $true

$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = "Programas parecidos a `"$($env:LNOMBRE)`". Elige uno:"
$lbl.AutoSize = $true; $lbl.Location = New-Object System.Drawing.Point(16,14)
$form.Controls.Add($lbl)

$panel = New-Object System.Windows.Forms.Panel
$panel.Location = New-Object System.Drawing.Point(16,44)
$panel.Width = 452; $panel.AutoScroll = $true
$panel.Height = [Math]::Min($cands.Count + 1, 11) * 28 + 4
$form.Controls.Add($panel)

$radios = New-Object System.Collections.ArrayList
$y = 2
foreach ($c in $cands) {
  $r = New-Object System.Windows.Forms.RadioButton
  $r.Text = $c; $r.AutoSize = $true
  $r.Location = New-Object System.Drawing.Point(4,$y)
  $panel.Controls.Add($r); [void]$radios.Add($r); $y += 28
}
$rAll = New-Object System.Windows.Forms.RadioButton
$rAll.Text = "Todas ($($cands.Count))"; $rAll.AutoSize = $true
$rAll.ForeColor = [System.Drawing.Color]::FromArgb(120,230,120)
$rAll.Location = New-Object System.Drawing.Point(4,$y)
$panel.Controls.Add($rAll)
$radios[0].Checked = $true

$ok = New-Object System.Windows.Forms.Button
$ok.Text = 'Aceptar'; $ok.Width = 120
$ok.Location = New-Object System.Drawing.Point(228, ($panel.Bottom + 16))
$ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = 'Cancelar'; $cancel.Width = 120
$cancel.Location = New-Object System.Drawing.Point(348, ($panel.Bottom + 16))
$cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($ok); $form.Controls.Add($cancel)
$form.AcceptButton = $ok; $form.CancelButton = $cancel
$form.ClientSize = New-Object System.Drawing.Size(484, ($ok.Bottom + 16))

if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit 1 }

$sel = $null
if ($rAll.Checked) { $sel = ($cands -join '|') }
else { foreach ($r in $radios) { if ($r.Checked) { $sel = $r.Text; break } } }
if (-not $sel) { exit 1 }
[IO.File]::WriteAllText($out, $sel, (New-Object System.Text.UTF8Encoding($false)))
exit 0
