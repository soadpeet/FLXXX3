# Lists the visible top-level windows of a process (title and size).
# AI disclaimer: this file was written autonomously by an AI agent (Claude).
param([string]$Name = "mixxx")
Add-Type @"
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public class E {
  public delegate bool CB(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(CB cb, IntPtr l);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
  public struct RECT { public int L, T, R, B; }
  public static List<string> List(uint pid) {
    var res = new List<string>();
    EnumWindows((h, l) => { uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) { var s = new StringBuilder(256); GetWindowText(h, s, 256);
        RECT r; GetWindowRect(h, out r); res.Add(h + " [" + s + "] " + (r.R - r.L) + "x" + (r.B - r.T)); }
      return true; }, IntPtr.Zero);
    return res; }
}
"@
foreach ($p in Get-Process -Name $Name) { [E]::List([uint32]$p.Id) }
