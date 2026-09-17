# ============================================================
#  KarateWin 起動ランチャー  v1.1
#  1) Windows を「拡張」ディスプレイ構成に切り替える
#  2) 観客モニター(karate-monitor.html)を Screen2 に全画面で開く
#  3) 操作画面(karate-all-in-one.html)を Screen1（メイン画面）に全画面で開く
#  ※ 2つの窓は同じ専用プロファイルで開く（別プロファイルだと画面間の同期ができないため）
#  v1.1: 起動オプション任せにせず、開いた窓を Windows API で目的の画面へ移動し、全画面(F11)にする
# ============================================================

# ---- 設定（必要に応じて変更） -------------------------------
# 空欄なら、このランチャーと同じフォルダのHTMLを開く。Vercel版を使う場合は例のように指定
$BaseUrl      = ''        # 例: 'https://karate-win-pc.vercel.app/'
$OperatorFile = 'karate-all-in-one.html'
$MonitorFile  = 'karate-monitor.html'
$OperatorMode = 'fullscreen'   # 操作画面の表示: 'fullscreen'＝全画面（タイトルバー・タスクバーなし） / 'maximized'＝最大化
$ProfileDir   = Join-Path $env:LOCALAPPDATA 'KarateWin\BrowserProfile'
# -------------------------------------------------------------

Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public static class KwWin {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int hgt, uint flags);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  // 見えているトップレベル窓の一覧: "hwnd|pid|title"
  public static List<string> List() {
    var res = new List<string>();
    EnumWindows((h, l) => {
      if (IsWindowVisible(h)) {
        var sb = new StringBuilder(512); GetWindowText(h, sb, 512);
        if (sb.Length > 0) { uint pid; GetWindowThreadProcessId(h, out pid); res.Add(h.ToInt64() + "|" + pid + "|" + sb.ToString()); }
      }
      return true;
    }, IntPtr.Zero);
    return res;
  }
}
"@
[void][KwWin]::SetProcessDPIAware()   # 画面座標を実ピクセルで扱う（拡大率125%/150%の環境でもずれない）

function Msg($text,$icon='Information'){ [void][System.Windows.Forms.MessageBox]::Show($text,'KarateWin',[System.Windows.Forms.MessageBoxButtons]::OK,$icon) }

function Get-KwPids {
  @(Get-CimInstance Win32_Process -Filter "Name='chrome.exe' OR Name='msedge.exe'" |
    Where-Object { $_.CommandLine -like "*KarateWin\BrowserProfile*" } | ForEach-Object { [uint32]$_.ProcessId })
}

# 専用プロファイルの窓のうち、タイトルが条件に合うものを待って返す（最大 $timeoutSec 秒）
function Wait-KwWindow([scriptblock]$titleTest, [int]$timeoutSec = 20) {
  $until = (Get-Date).AddSeconds($timeoutSec)
  while((Get-Date) -lt $until){
    $pids = Get-KwPids
    foreach($line in [KwWin]::List()){
      $parts = $line.Split('|',3)
      if($pids -contains [uint32]$parts[1]){
        if(& $titleTest $parts[2]){ return [IntPtr][int64]$parts[0] }
      }
    }
    Start-Sleep -Milliseconds 500
  }
  return [IntPtr]::Zero
}

# 窓を指定画面へ移動し、全画面(F11) または 最大化 にする
function Set-KwWindow([IntPtr]$hwnd, $screen, [string]$mode) {
  if($hwnd -eq [IntPtr]::Zero){ return $false }
  $b = $screen.Bounds
  $isFull = {
    $r = New-Object KwWin+RECT
    [void][KwWin]::GetWindowRect($hwnd, [ref]$r)
    ($r.L -le $b.X) -and ($r.T -le $b.Y) -and ($r.R -ge ($b.X + $b.Width)) -and ($r.B -ge ($b.Y + $b.Height)) -and ($r.L -ge ($b.X - 20)) -and ($r.R -le ($b.X + $b.Width + 20))
  }
  if(& $isFull){ return $true }                       # すでに目的の画面で全画面ならそのまま
  [void][KwWin]::ShowWindow($hwnd, 9)                  # SW_RESTORE（最大化・全画面解除後でないと移動できない）
  Start-Sleep -Milliseconds 300
  $w = [int]($b.Width * 0.8); $h = [int]($b.Height * 0.8)
  [void][KwWin]::SetWindowPos($hwnd, [IntPtr]::Zero, $b.X + 40, $b.Y + 40, $w, $h, 0x0040)   # 目的の画面の中へ移動
  Start-Sleep -Milliseconds 300
  if($mode -eq 'maximized'){
    [void][KwWin]::ShowWindow($hwnd, 3)                # SW_MAXIMIZE
    return $true
  }
  # 全画面: 窓を前面にして F11（ブラウザ自体の全画面。ダイアログや Esc では解除されない）
  for($i=0; $i -lt 3; $i++){
    [void][KwWin]::SetForegroundWindow($hwnd)
    Start-Sleep -Milliseconds 400
    [System.Windows.Forms.SendKeys]::SendWait('{F11}')
    Start-Sleep -Milliseconds 1200
    if(& $isFull){ return $true }
  }
  [void][KwWin]::ShowWindow($hwnd, 3)                  # F11 が効かなかった場合は最大化で代替
  return $false
}

# ---- ブラウザを探す（Chrome 優先、なければ Edge） ----
$candidates = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
)
$Browser = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if(-not $Browser){ Msg 'Chrome / Edge が見つかりません。' 'Error'; exit 1 }

# ---- 二重起動の防止（録画中の窓を壊さないため、既存の窓は閉じない） ----
if((Get-KwPids).Count -gt 0){ Msg "KarateWin はすでに起動しています。`n開き直す場合は、操作画面とモニターの窓を両方閉じてから、もう一度起動してください。" 'Warning'; exit 0 }

# ---- URL を決める ----
if([string]::IsNullOrWhiteSpace($BaseUrl)){
  $opPath  = Join-Path $PSScriptRoot $OperatorFile
  $monPath = Join-Path $PSScriptRoot $MonitorFile
  foreach($p in @($opPath,$monPath)){ if(-not (Test-Path $p)){ Msg "ファイルが見つかりません:`n$p" 'Error'; exit 1 } }
  $OperatorUrl = ([System.Uri]$opPath).AbsoluteUri
  $MonitorUrl  = ([System.Uri]$monPath).AbsoluteUri + '?kiosk=1'
} else {
  if(-not $BaseUrl.EndsWith('/')){ $BaseUrl += '/' }
  $OperatorUrl = $BaseUrl + $OperatorFile
  $MonitorUrl  = $BaseUrl + $MonitorFile + '?kiosk=1'
}

# ---- 1) 拡張ディスプレイに切り替え（Windows 標準コマンド。すでに拡張なら何も起きない） ----
$ds = Join-Path $env:WINDIR 'System32\DisplaySwitch.exe'
if(Test-Path $ds){ Start-Process $ds -ArgumentList '/extend' ; Start-Sleep -Seconds 4 }

$primary = [System.Windows.Forms.Screen]::PrimaryScreen                                   # Screen1
$second  = [System.Windows.Forms.Screen]::AllScreens | Where-Object { -not $_.Primary } | Select-Object -First 1   # Screen2

$common = @("--user-data-dir=`"$ProfileDir`"", '--no-first-run', '--no-default-browser-check',
            '--disable-session-crashed-bubble', '--autoplay-policy=no-user-gesture-required')

# ---- 2) モニターを Screen2 に全画面で開く ----
if($second){
  $b = $second.Bounds
  Start-Process $Browser -ArgumentList ($common + @("--app=$MonitorUrl", "--window-position=$($b.X),$($b.Y)"))   # 全画面化は下の Set-KwWindow(F11) で確実に行う
  $hMon = Wait-KwWindow { param($t) $t -like '*観客モニター*' }
  [void](Set-KwWindow $hMon $second 'fullscreen')
} else {
  Msg "2台目のディスプレイが見つかりません。`n操作画面だけを開きます。ケーブル接続後、窓を閉じてからもう一度起動し直してください。" 'Warning'
}

# ---- 3) 操作画面を Screen1 に全画面（または最大化）で開く ----
$p = $primary.Bounds
Start-Process $Browser -ArgumentList ($common + @("--app=$OperatorUrl", "--window-position=$($p.X),$($p.Y)"))
$hOp = Wait-KwWindow { param($t) ($t -like '*Karate Win*') -and ($t -notlike '*観客モニター*') }
$ok = Set-KwWindow $hOp $primary $OperatorMode
if($hOp -ne [IntPtr]::Zero){ [void][KwWin]::SetForegroundWindow($hOp) }    # 最後に操作画面を前面に（キーボード操作はこちらへ）
if($hOp -eq [IntPtr]::Zero){ Msg '操作画面の窓を確認できませんでした。手動で Screen1 に移動し、F11 キーで全画面にしてください。' 'Warning' }
