# Cambia la fuente de la ventana de consola actual a una TrueType legible (Consolas)
try {
  $src = @"
using System;
using System.Runtime.InteropServices;
public static class CF {
  [StructLayout(LayoutKind.Sequential)]
  public struct COORD { public short X; public short Y; }
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public struct FONTINFO {
    public uint cbSize; public uint nFont; public COORD dwFontSize;
    public int FontFamily; public int FontWeight;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string FaceName;
  }
  [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr GetStdHandle(int h);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetCurrentConsoleFontEx(IntPtr h, bool b, ref FONTINFO f);
}
"@
  Add-Type $src -ErrorAction Stop
  $h = [CF]::GetStdHandle(-11)
  $f = New-Object CF+FONTINFO
  $f.cbSize = [uint32][Runtime.InteropServices.Marshal]::SizeOf($f)
  $f.FaceName = 'Consolas'
  $f.dwFontSize = New-Object CF+COORD
  $f.dwFontSize.Y = 18        # tamaño; sube/baja este numero
  $f.FontFamily = 54
  $f.FontWeight = 400
  [void][CF]::SetCurrentConsoleFontEx($h, $false, [ref]$f)
} catch { }
