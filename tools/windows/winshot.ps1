# Screenshot of the main window of one process only (not the whole desktop), also when
# other windows cover it (PrintWindow with PW_RENDERFULLCONTENT).
# Usage: powershell -File winshot.ps1 <processName> <outFile.png>
# AI disclaimer: this file was written autonomously by an AI agent (Claude).
param([string]$Name = "mixxx", [string]$Out = "X:\Dev\Screenshots\win_1.png")
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
[W]::SetProcessDPIAware() | Out-Null
$p = Get-Process -Name $Name -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { Write-Output "no window"; exit 1 }
$r = New-Object W+RECT
[W]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
$w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[W]::PrintWindow($p.MainWindowHandle, $hdc, 2) | Out-Null
$g.ReleaseHdc($hdc)
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output "$($p.MainWindowTitle) ${w}x${h}"
