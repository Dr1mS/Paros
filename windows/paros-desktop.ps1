# Paros helper for Windows: the counterpart of the GNOME Shell extension.
# Started by the app (see Desktop.start_helper), ends with it.
#
# Writes, in -Dir:
#   desktop.json    same format as the GNOME extension, plus idle_ms, music, cpu, battery.
#   processes.json  every process: pid -> [parent pid, creation time as a string].
# Reads, in -Dir/requests: one file per request, then deletes it.
#   focus <TAB> session pid <TAB> pids of its ancestors, comma separated <TAB> session name
#   ring  <TAB> session pid
# ASCII only: Windows PowerShell 5.1 reads a script without BOM as ANSI.
param(
	[Parameter(Mandatory = $true)][uint32]$ParentPid,
	[Parameter(Mandatory = $true)][string]$Dir
)
$ErrorActionPreference = 'SilentlyContinue'

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Text;

public class ParosWindow
{
	public IntPtr Handle;
	public uint Pid;
	public string Title;
}

public static class ParosNative
{
	[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
	[StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
	[StructLayout(LayoutKind.Sequential)] public struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
	[StructLayout(LayoutKind.Sequential)] public struct MONITORINFO { public uint cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }
	[StructLayout(LayoutKind.Sequential)] public struct FILETIME { public uint Lo; public uint Hi; }
	[StructLayout(LayoutKind.Sequential)] public struct POWER { public byte AC; public byte Flag; public byte Percent; public byte Saver; public uint Life; public uint Full; }
	[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
	public struct PROCESSENTRY32
	{
		public uint dwSize; public uint cntUsage; public uint th32ProcessID; public IntPtr th32DefaultHeapID;
		public uint th32ModuleID; public uint cntThreads; public uint th32ParentProcessID; public int pcPriClassBase;
		public uint dwFlags;
		[MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string szExeFile;
	}
	public delegate bool EnumProc(IntPtr h, IntPtr l);

	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
	[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
	[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
	[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
	[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
	[DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
	[DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int index);
	[DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
	[DllImport("user32.dll")] public static extern bool GetLastInputInfo(ref LASTINPUTINFO i);
	[DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr h, uint flags);
	[DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr m, ref MONITORINFO i);
	[DllImport("user32.dll")] public static extern IntPtr OpenInputDesktop(uint flags, bool inherit, uint access);
	[DllImport("user32.dll")] public static extern bool CloseDesktop(IntPtr d);
	[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
	[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
	[DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
	[DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
	[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
	[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr ctx);
	[DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out RECT r, int size);
	[DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out int v, int size);
	[DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
	[DllImport("kernel32.dll")] public static extern bool GetSystemTimes(out FILETIME idle, out FILETIME kernel, out FILETIME user);
	[DllImport("kernel32.dll")] public static extern bool GetSystemPowerStatus(out POWER s);
	[DllImport("kernel32.dll")] public static extern IntPtr CreateToolhelp32Snapshot(uint flags, uint pid);
	[DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern bool Process32First(IntPtr s, ref PROCESSENTRY32 e);
	[DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern bool Process32Next(IntPtr s, ref PROCESSENTRY32 e);
	[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
	[DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
	[DllImport("kernel32.dll")] public static extern bool GetProcessTimes(IntPtr h, out FILETIME c, out FILETIME e, out FILETIME k, out FILETIME u);
	[DllImport("kernel32.dll")] public static extern bool FreeConsole();
	[DllImport("kernel32.dll")] public static extern bool AttachConsole(uint pid);
	[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
	[DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern uint GetConsoleTitle(StringBuilder s, uint n);
	[DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr CreateFile(string name, uint access, uint share, IntPtr sec, uint disp, uint flags, IntPtr tmpl);
	[DllImport("kernel32.dll")] public static extern bool WriteFile(IntPtr h, byte[] buf, uint n, out uint written, IntPtr ov);

	static ulong lastIdle, lastTotal;
	static DateTime lastCpuTime = DateTime.MinValue;
	static double cpu = 0;

	public static void Init()
	{
		// Same pixels as the app: without this, the rectangles would be scaled.
		SetProcessDpiAwarenessContext(new IntPtr(-4));
	}

	static ulong U(FILETIME f) { return ((ulong)f.Hi << 32) | f.Lo; }

	static string Text(IntPtr h)
	{
		StringBuilder s = new StringBuilder(512);
		GetWindowText(h, s, 512);
		return s.ToString();
	}

	static string Class(IntPtr h)
	{
		StringBuilder s = new StringBuilder(256);
		GetClassName(h, s, 256);
		return s.ToString();
	}

	static string Num(double v) { return v.ToString("0.###", CultureInfo.InvariantCulture); }

	static bool Cloaked(IntPtr h)
	{
		int v;
		return DwmGetWindowAttribute(h, 14, out v, 4) == 0 && v != 0;
	}

	static RECT Frame(IntPtr h)
	{
		RECT r;
		// Extended frame bounds: the visible frame, without the invisible resize border.
		if (DwmGetWindowAttribute(h, 9, out r, 16) != 0)
			GetWindowRect(h, out r);
		return r;
	}

	static double Cpu()
	{
		FILETIME i, k, u;
		if (!GetSystemTimes(out i, out k, out u)) return cpu;
		ulong idle = U(i), total = U(k) + U(u);
		DateTime now = DateTime.UtcNow;
		if (lastCpuTime != DateTime.MinValue && total > lastTotal)
		{
			double busy = 1.0 - (double)(idle - lastIdle) / (double)(total - lastTotal);
			double seconds = (now - lastCpuTime).TotalSeconds;
			// Average over about a minute, like a load average.
			double alpha = Math.Min(seconds / 60.0, 1.0);
			cpu = cpu == 0 ? busy : cpu + (busy - cpu) * alpha;
		}
		lastIdle = idle; lastTotal = total; lastCpuTime = now;
		return cpu;
	}

	// The state of the desktop as one JSON object. Same keys as the GNOME extension.
	public static string State(uint ownPid, bool music)
	{
		StringBuilder sb = new StringBuilder("{");
		POINT p;
		GetCursorPos(out p);
		sb.Append("\"pointer\":[" + p.X + "," + p.Y + "]");
		IntPtr desk = OpenInputDesktop(0, false, 0x100);
		bool locked = desk == IntPtr.Zero;
		if (!locked) CloseDesktop(desk);
		sb.Append(",\"locked\":" + (locked ? "true" : "false") + ",\"mirrored\":0");

		string covered = "";
		string active = "null";
		IntPtr fg = locked ? IntPtr.Zero : GetForegroundWindow();
		uint pid = 0;
		if (fg != IntPtr.Zero) GetWindowThreadProcessId(fg, out pid);
		string cls = fg == IntPtr.Zero ? "" : Class(fg);
		bool shell = cls == "Progman" || cls == "WorkerW" || cls == "Shell_TrayWnd" || cls == "Shell_SecondaryTrayWnd";
		if (fg != IntPtr.Zero && pid != ownPid && !shell && IsWindowVisible(fg) && !IsIconic(fg) && !Cloaked(fg))
		{
			RECT r = Frame(fg);
			MONITORINFO mi = new MONITORINFO();
			mi.cbSize = (uint)Marshal.SizeOf(typeof(MONITORINFO));
			bool full = false;
			IntPtr mon = MonitorFromWindow(fg, 2);
			if (mon != IntPtr.Zero && GetMonitorInfo(mon, ref mi))
			{
				bool caption = (GetWindowLong(fg, -16) & 0xC00000) == 0xC00000;
				full = !caption && r.Left <= mi.rcMonitor.Left && r.Top <= mi.rcMonitor.Top
					&& r.Right >= mi.rcMonitor.Right && r.Bottom >= mi.rcMonitor.Bottom;
				if (full)
					covered = "[" + mi.rcMonitor.Left + "," + mi.rcMonitor.Top + "," + (mi.rcMonitor.Right - mi.rcMonitor.Left) + "," + (mi.rcMonitor.Bottom - mi.rcMonitor.Top) + "]";
			}
			active = "{\"x\":" + r.Left + ",\"y\":" + r.Top + ",\"width\":" + (r.Right - r.Left) + ",\"height\":" + (r.Bottom - r.Top)
				+ ",\"fullscreen\":" + (full ? "true" : "false") + ",\"pid\":" + pid + "}";
		}
		sb.Append(",\"covered\":[" + covered + "],\"active\":" + active);

		LASTINPUTINFO li = new LASTINPUTINFO();
		li.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
		uint idleMs = 0;
		if (GetLastInputInfo(ref li)) idleMs = unchecked((uint)Environment.TickCount - li.dwTime);
		sb.Append(",\"idle_ms\":" + idleMs);
		sb.Append(",\"music\":" + (music ? "true" : "false"));
		sb.Append(",\"cpu\":" + Num(Cpu()));

		POWER pw;
		string battery = "null";
		if (GetSystemPowerStatus(out pw) && (pw.Flag & 128) == 0 && pw.Percent <= 100)
			battery = "{\"percent\":" + pw.Percent + ",\"discharging\":" + (pw.AC == 0 ? "true" : "false") + "}";
		sb.Append(",\"battery\":" + battery);
		sb.Append("}");
		return sb.ToString();
	}

	// Every process: {"updated": unix seconds, "processes": {"pid": [parent, "creation FILETIME"]}}.
	public static string Processes()
	{
		StringBuilder sb = new StringBuilder();
		long unix = (long)(DateTime.UtcNow - new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc)).TotalSeconds;
		sb.Append("{\"updated\":" + unix + ",\"processes\":{");
		IntPtr snap = CreateToolhelp32Snapshot(2, 0);
		if (snap != IntPtr.Zero && snap != new IntPtr(-1))
		{
			PROCESSENTRY32 e = new PROCESSENTRY32();
			e.dwSize = (uint)Marshal.SizeOf(typeof(PROCESSENTRY32));
			bool first = true;
			bool more = Process32First(snap, ref e);
			while (more)
			{
				string created = "0";
				IntPtr h = OpenProcess(0x1000, false, e.th32ProcessID);
				if (h != IntPtr.Zero)
				{
					FILETIME c, x, k, u;
					if (GetProcessTimes(h, out c, out x, out k, out u)) created = U(c).ToString();
					CloseHandle(h);
				}
				if (!first) sb.Append(",");
				first = false;
				sb.Append("\"" + e.th32ProcessID + "\":[" + e.th32ParentProcessID + ",\"" + created + "\"]");
				more = Process32Next(snap, ref e);
			}
			CloseHandle(snap);
		}
		sb.Append("}}");
		return sb.ToString();
	}

	// The visible top-level windows without owner, that belong to one of the processes.
	public static List<ParosWindow> Windows(uint[] pids)
	{
		List<ParosWindow> found = new List<ParosWindow>();
		List<uint> wanted = new List<uint>(pids);
		EnumWindows(delegate (IntPtr h, IntPtr l)
		{
			uint pid;
			GetWindowThreadProcessId(h, out pid);
			if (wanted.Contains(pid) && IsWindowVisible(h) && GetWindow(h, 4) == IntPtr.Zero)
			{
				ParosWindow w = new ParosWindow();
				w.Handle = h; w.Pid = pid; w.Title = Text(h);
				found.Add(w);
			}
			return true;
		}, IntPtr.Zero);
		return found;
	}

	[DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int index, int value);

	// The main window of the app is empty and parked off screen: it must not
	// have a button in the taskbar. The pet windows have none already.
	public static void HideFromTaskbar(uint pid)
	{
		EnumWindows(delegate (IntPtr h, IntPtr l)
		{
			uint owner;
			GetWindowThreadProcessId(h, out owner);
			int style = GetWindowLong(h, -20);
			if (owner == pid && IsWindowVisible(h) && (style & 0x40000) != 0)
			{
				SetWindowLong(h, -20, (style & ~0x40000) | 0x80);
				// A window is listed again when it is shown again.
				ShowWindow(h, 0);
				ShowWindow(h, 8);
			}
			return true;
		}, IntPtr.Zero);
	}

	// Title of the console of a process, which is the title of its terminal tab,
	// and the window that holds it (0 when unknown).
	public static string ConsoleInfo(uint pid, out IntPtr window)
	{
		window = IntPtr.Zero;
		FreeConsole();
		if (!AttachConsole(pid)) return "";
		StringBuilder s = new StringBuilder(1024);
		GetConsoleTitle(s, 1024);
		IntPtr console = GetConsoleWindow();
		// Behind a terminal such as Windows Terminal, this window is hidden and owned by the real one.
		if (console != IntPtr.Zero) window = GetAncestor(console, 3);
		FreeConsole();
		return s.ToString();
	}

	public static void Ring(uint pid)
	{
		FreeConsole();
		if (!AttachConsole(pid)) return;
		IntPtr h = CreateFile("CONOUT$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
		if (h != IntPtr.Zero && h != new IntPtr(-1))
		{
			uint written;
			WriteFile(h, new byte[] { 7 }, 1, out written, IntPtr.Zero);
			CloseHandle(h);
		}
		FreeConsole();
	}

	// Windows refuses to bring to the front a window for a process that has no input.
	// A key press and a shared input queue make it believe the user asked.
	public static void Activate(IntPtr h)
	{
		if (IsIconic(h)) ShowWindow(h, 9);
		IntPtr fg = GetForegroundWindow();
		uint ignored;
		uint fgThread = fg == IntPtr.Zero ? 0 : GetWindowThreadProcessId(fg, out ignored);
		uint me = GetCurrentThreadId();
		bool attached = fgThread != 0 && fgThread != me && AttachThreadInput(me, fgThread, true);
		keybd_event(0x12, 0, 0, UIntPtr.Zero);
		keybd_event(0x12, 0, 2, UIntPtr.Zero);
		BringWindowToTop(h);
		SetForegroundWindow(h);
		if (attached) AttachThreadInput(me, fgThread, false);
	}
}
'@
[ParosNative]::Init()

$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-Atomic([string]$name, [string]$text) {
	$path = Join-Path $Dir $name
	[System.IO.File]::WriteAllText("$path.tmp", $text, $utf8)
	Move-Item -LiteralPath "$path.tmp" -Destination $path -Force
}

# --- Music: any media session that plays, as Windows tells it (SMTC). ---
$smtc = $null
try {
	Add-Type -AssemblyName System.Runtime.WindowsRuntime
	$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
		$_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
	} | Select-Object -First 1
	$managerType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
	$task = $asTask.MakeGenericMethod($managerType).Invoke($null, @($managerType::RequestAsync()))
	if ($task.Wait(5000)) { $smtc = $task.Result }
} catch { $smtc = $null }

function Test-Music {
	if ($null -eq $smtc) { return $false }
	try {
		foreach ($session in $smtc.GetSessions()) {
			if ($session.GetPlaybackInfo().PlaybackStatus.ToString() -eq 'Playing') { return $true }
		}
	} catch { }
	return $false
}

# --- Terminal focus. ---
# Selects, in a Windows Terminal window, the tab that has this title.
function Select-Tab([IntPtr]$window, [string]$title) {
	if ([string]::IsNullOrWhiteSpace($title)) { return $false }
	try {
		Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
		$root = [System.Windows.Automation.AutomationElement]::FromHandle($window)
		$condition = New-Object System.Windows.Automation.PropertyCondition(
			[System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::TabItem)
		foreach ($tab in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition)) {
			$name = $tab.Current.Name
			if ($name -eq $title -or $name.Contains($title) -or $title.Contains($name)) {
				$tab.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern).Select()
				return $true
			}
		}
	} catch { }
	return $false
}

function Invoke-Focus([uint32]$sessionPid, [string]$ancestors, [string]$name) {
	$pids = @($ancestors.Split(',') | Where-Object { $_ } | ForEach-Object { [uint32]$_ })
	$windows = New-Object System.Collections.Generic.List[ParosWindow]
	$windows.AddRange([ParosNative]::Windows($pids))
	$console = [IntPtr]::Zero
	$tab = [ParosNative]::ConsoleInfo($sessionPid, [ref]$console)
	# A classic console window belongs to no ancestor: its handle comes from the console itself.
	if ($console -ne [IntPtr]::Zero -and [ParosNative]::IsWindowVisible($console) -and -not ($windows | Where-Object { $_.Handle -eq $console })) {
		$extra = New-Object ParosWindow
		$extra.Handle = $console
		$windows.Add($extra)
	}
	if ($windows.Count -eq 0) { return }
	$target = $null
	foreach ($title in @($tab, $name)) {
		foreach ($window in $windows) {
			if (Select-Tab $window.Handle $title) { $target = $window; break }
		}
		if ($target) { break }
	}
	if (-not $target) {
		$target = $windows | Where-Object { $_.Title -and $name -and $_.Title.Contains($name) } | Select-Object -First 1
	}
	if (-not $target) { $target = $windows[0] }
	[ParosNative]::Activate($target.Handle)
}

function Invoke-Requests {
	$folder = Join-Path $Dir 'requests'
	foreach ($file in Get-ChildItem -LiteralPath $folder -Filter '*.txt' | Sort-Object Name) {
		$line = [System.IO.File]::ReadAllText($file.FullName)
		Remove-Item -LiteralPath $file.FullName -Force
		$fields = $line.Trim("`r", "`n").Split("`t")
		try {
			switch ($fields[0]) {
				'focus' { Invoke-Focus ([uint32]$fields[1]) $fields[2] $fields[3] }
				'ring' { [ParosNative]::Ring([uint32]$fields[1]) }
			}
		} catch { }
	}
}

New-Item -ItemType Directory -Force -Path (Join-Path $Dir 'requests') | Out-Null
$music = $false
$tick = 0
while ($true) {
	if ($tick % 5 -eq 0) {
		if (-not (Get-Process -Id $ParentPid)) { break }
		if ($tick % 30 -eq 0) { $music = Test-Music }
		Write-Atomic 'desktop.json' ([ParosNative]::State($ParentPid, $music))
		if ($tick % 50 -eq 0) { Write-Atomic 'processes.json' ([ParosNative]::Processes()) }
		if ($tick % 50 -eq 20) { [ParosNative]::HideFromTaskbar($ParentPid) }
	}
	Invoke-Requests
	Start-Sleep -Milliseconds 100
	$tick++
}
