# ============================================================
#  KarateWin 起動ランチャー  v1.7
#  0) 起動前に最新版を確認し、承認されたら更新する（オンライン時のみ）
#  1) Windows を「拡張」ディスプレイ構成に切り替える
#  2) 観客モニター(karate-monitor.html)を Screen2 に全画面で開く
#  3) 操作画面(karate-all-in-one.html)を Screen1（メイン画面）に全画面で開く
#  ※ 2つの窓は同じ専用プロファイルで開く（別プロファイルだと画面間の同期ができないため）
#  v1.1: 起動オプション任せにせず、開いた窓を Windows API で目的の画面へ移動し、全画面(F11)にする
#  v1.2: 更新確認（Yes/No）
#  v1.3: 更新インストーラーのダウンロードと SHA-256 検証
#  v1.4: 検証済みインストーラーを実行して終了（更新後はインストーラーが KarateWin を再起動）
#        バージョン表記の先頭 v（例: v1.16b）に対応
#  v1.5: 拡張表示は SetDisplayConfig で直接切替（表示切替パネルを出さない）。すでに2画面なら何もしない
#  v1.6: ・全画面の判定を Windows API の座標だけで行う（WinForms の画面情報との座標ずれで
#          「まだ全画面でない」と誤判定し、F11 をもう一度押して全画面を解除していた不具合を修正）
#        ・F11 は1回だけ送る。窓に変化があれば二度と押さない（押し直しで解除しない）
#        ・窓の前面化は実際のクリック（タイトルバー）で行う（Windows の前面化制限を受けない）
#        ・観客モニターの窓を「常に手前」に固定（操作画面を触ってもタスクバーが重ならない）
#        ・最後に操作画面の上部帯（ボタンのない場所）をクリックして前面に戻し、カーソルもそこに置く
#  v1.7: ・「常に手前」の固定を既定で無効に（Chrome の全画面窓にタイトルバーが再表示されるため）
#        ・仕上げに観客モニターを一度クリックしてから操作画面をクリックする
#          （モニターの窓が一度でも裏に回るとタイトルバーが残ることがあるため、手作業で直していた操作を自動化）
# ============================================================

# ---- 設定（必要に応じて変更） -------------------------------
# 空欄なら、このランチャーと同じフォルダのHTMLを開く。Vercel版を使う場合は例のように指定
$BaseUrl        = ''        # 例: 'https://karate-win-pc.vercel.app/'
$OperatorFile   = 'karate-all-in-one.html'
$MonitorFile    = 'karate-monitor.html'
$OperatorMode   = 'fullscreen'   # 操作画面の表示: 'fullscreen'＝全画面（タイトルバー・タスクバーなし） / 'maximized'＝最大化
$MonitorTopmost = $false         # 観客モニターを「常に手前」にする。Chrome のタイトルバーが出ることがあるため既定は無効
$ProfileDir     = Join-Path $env:LOCALAPPDATA 'KarateWin\BrowserProfile'
# -------------------------------------------------------------

# ---- 更新設定 -----------------------------------------------
$CurrentVersionFile = Join-Path $PSScriptRoot 'version.txt'                      # ローカルの現在バージョン（インストーラーが作成）
$UpdateManifestUrl  = 'https://karate-win-pc.vercel.app/version.json'           # サーバーの最新バージョン情報
$UpdateCheckEnabled = $true    # 更新確認を行うか
$UpdateDebug        = $true    # 開発中は $true（比較内容とエラーを表示）。本番は $false
$UpdateDir          = Join-Path $env:TEMP 'KarateWin\Update'                      # 更新インストーラーの保存先
# -------------------------------------------------------------

# Windows PowerShell 5.1 で HTTPS(TLS1.2) を確実に使い、ダウンロードを高速化する
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
$ProgressPreference = 'SilentlyContinue'

Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public static class KwWin {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  public delegate bool MonEnumProc(IntPtr hMon, IntPtr hdc, IntPtr rc, IntPtr data);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonEnumProc cb, IntPtr data);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool GetMonitorInfo(IntPtr hMon, ref MONITORINFO mi);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int hgt, uint flags);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool attach);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, int dx, int dy, uint data, UIntPtr extra);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
  [DllImport("user32.dll")] public static extern int SetDisplayConfig(uint numPath, IntPtr pathArray, uint numMode, IntPtr modeArray, uint flags);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct MONITORINFO {
    public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags;
  }

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

  // ディスプレイ一覧: "L|T|R|B|primary(1/0)"（窓の座標と同じ単位で取得する）
  public static List<string> Monitors() {
    var res = new List<string>();
    EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (hm, hdc, rc, d) => {
      var mi = new MONITORINFO(); mi.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
      if (GetMonitorInfo(hm, ref mi)) {
        res.Add(mi.rcMonitor.L + "|" + mi.rcMonitor.T + "|" + mi.rcMonitor.R + "|" + mi.rcMonitor.B + "|" + (((mi.dwFlags & 1) != 0) ? "1" : "0"));
      }
      return true;
    }, IntPtr.Zero);
    return res;
  }

  // 窓が指定ディスプレイをちょうど覆っているか（ブラウザの全画面は窓＝画面の大きさになる。最大化は数px はみ出すので一致しない）
  public static bool IsFullOn(IntPtr h, int l, int t, int r, int b) {
    RECT w; if (!GetWindowRect(h, out w)) return false;
    return Math.Abs(w.L - l) <= 2 && Math.Abs(w.T - t) <= 2 && Math.Abs(w.R - r) <= 2 && Math.Abs(w.B - b) <= 2;
  }
  public static string RectStr(IntPtr h) { RECT w; GetWindowRect(h, out w); return w.L + "," + w.T + "," + w.R + "," + w.B; }

  // 指定位置を左クリック（実際の入力なので、Windows の前面化制限を受けずに窓が前面になる）
  public static void ClickAt(int x, int y) {
    SetCursorPos(x, y);
    System.Threading.Thread.Sleep(80);
    mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero);   // LEFTDOWN
    mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero);   // LEFTUP
  }

  // クリックで前面化できなかったときの予備
  public static bool ForceForeground(IntPtr h) {
    if (h == IntPtr.Zero) return false;
    if (GetForegroundWindow() == h) return true;
    if (IsIconic(h)) ShowWindow(h, 9);
    uint dummy;
    uint fgThread = GetWindowThreadProcessId(GetForegroundWindow(), out dummy);
    uint me = GetCurrentThreadId();
    bool attached = false;
    if (fgThread != 0 && fgThread != me) attached = AttachThreadInput(me, fgThread, true);
    BringWindowToTop(h);
    SetForegroundWindow(h);
    if (attached) AttachThreadInput(me, fgThread, false);
    return GetForegroundWindow() == h;
  }

  // キーを1回押して離す（前面の窓に届く）
  public static void PressKey(byte vk) {
    keybd_event(vk, 0, 0, UIntPtr.Zero);
    keybd_event(vk, 0, 2, UIntPtr.Zero);         // KEYEVENTF_KEYUP
  }
}
"@

# 画面座標を実ピクセルで扱う。画面ごとに拡大率が違う（例: 125% と 100%）場合も正しく扱えるよう Per-Monitor V2 を優先
try {
  if(-not [KwWin]::SetProcessDpiAwarenessContext([IntPtr](-4))){ [void][KwWin]::SetProcessDPIAware() }
} catch { [void][KwWin]::SetProcessDPIAware() }

function Msg($text,$icon='Information'){ [void][System.Windows.Forms.MessageBox]::Show($text,'KarateWin',[System.Windows.Forms.MessageBoxButtons]::OK,$icon) }

# ============================================================
# KarateWin 独自バージョン（例: 1.15 / 1.15d / v1.16b / 1.17c）を比較用に変換
#   先頭の v は無視する。1.15 -> 1.15.0.0 / 1.15d -> 1.15.0.4 / v1.16b -> 1.16.0.2
# ============================================================
function Convert-KwVersion([string]$version) {
  $version = $version.Trim()
  if($version -notmatch '^[vV]?(\d+)\.(\d+)([a-zA-Z]?)$'){ throw "対応していないバージョン形式です: $version" }
  $major  = [int]$Matches[1]
  $minor  = [int]$Matches[2]
  $letter = $Matches[3].ToLower()
  $revision = 0
  if($letter){ $revision = ([int][char]$letter) - ([int][char]'a') + 1 }   # a=1 ... z=26
  return [version]"$major.$minor.0.$revision"
}

# ============================================================
# 更新インストーラーのダウンロードと SHA-256 検証
#   戻り値: 検証済みインストーラーのパス / 失敗時は $null
# ============================================================
function Get-KwUpdateInstaller($manifest, [string]$latestText) {
  try {
    $url  = ([string]$manifest.installerUrl).Trim()
    $hash = ([string]$manifest.sha256) -replace '\s', ''
    if([string]::IsNullOrWhiteSpace($url)){  throw 'version.json に installerUrl がありません。' }
    if([string]::IsNullOrWhiteSpace($hash)){ throw 'version.json に sha256 がありません。' }
    if(-not $url.StartsWith('https://')){    throw "installerUrl は https:// で始まる必要があります。`n$url" }

    # 保存先を作り直す（前回の残りファイルを使わない）
    if(Test-Path $UpdateDir){ Remove-Item $UpdateDir -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item $UpdateDir -ItemType Directory -Force | Out-Null
    $path = Join-Path $UpdateDir "KarateWin-Setup-$latestText.exe"

    Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing -TimeoutSec 300 -ErrorAction Stop

    $actual = (Get-FileHash $path -Algorithm SHA256).Hash
    if($actual -ne $hash.ToUpperInvariant()){
      Remove-Item $path -Force -ErrorAction SilentlyContinue
      throw "ファイルの検証に失敗しました（SHA-256 不一致）。`n期待値: $($hash.ToUpperInvariant())`n実際値: $actual"
    }

    if($UpdateDebug){ Msg "【ダウンロード情報】`n`nURL: $url`n保存先: $path`nサイズ: $((Get-Item $path).Length) bytes`nSHA-256: 一致" }
    return $path
  }
  catch {
    Msg "更新ファイルを準備できませんでした。現在のバージョンで起動します。`n`n$($_.Exception.Message)" 'Warning'
    return $null
  }
}

# ============================================================
# 検証済みインストーラーを起動する
#   /SILENT      : 進行状況だけ表示し、質問はしない
#   /KWUPDATE=1  : 自動更新であることをインストーラーに伝える（完了後に KarateWin を再起動させる）
#   戻り値: $true = 起動できた（このランチャーは終了する） / $false = 起動できなかった
# ============================================================
function Start-KwUpdateInstall([string]$installer) {
  try {
    $log  = Join-Path $UpdateDir 'install.log'
    $installArgs = @('/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/KWUPDATE=1', "/LOG=`"$log`"")
    # Program Files へのインストールのため、ここで管理者確認(UAC)が表示される。拒否された場合は例外になる
    Start-Process -FilePath $installer -ArgumentList $installArgs -ErrorAction Stop
    return $true
  }
  catch {
    Msg "更新を開始できませんでした。現在のバージョンで起動します。`n`n$($_.Exception.Message)" 'Warning'
    return $false
  }
}

# ============================================================
# 最新版確認
#   戻り値: $true = 更新インストーラーを起動した（ランチャーは終了する）
#           $false = 更新不要・いいえ・失敗（現在の版で起動を続ける）
# ============================================================
function Test-KwUpdate {
  if(-not $UpdateCheckEnabled){ return $false }
  if(-not (Test-Path $CurrentVersionFile)){
    if($UpdateDebug){ Msg "version.txt が見つかりません。`n$CurrentVersionFile" 'Warning' }
    return $false
  }
  try {
    $currentText    = (Get-Content $CurrentVersionFile -Raw).Trim()
    $currentVersion = Convert-KwVersion $currentText

    $manifest = Invoke-RestMethod -Uri $UpdateManifestUrl -Method Get -TimeoutSec 5 -Headers @{ 'Cache-Control' = 'no-cache' } -ErrorAction Stop
    if(-not $manifest.version){ throw 'version.json に version がありません。' }

    $latestText    = ([string]$manifest.version).Trim()
    $latestVersion = Convert-KwVersion $latestText

    if($UpdateDebug){
      Msg "【更新チェック情報】`n`nローカル: $currentText`nサーバー: $latestText`n`n内部比較値: $currentVersion → $latestVersion`n`nURL: $UpdateManifestUrl"
    }

    if($latestVersion -gt $currentVersion){
      $message = "KarateWin の新しいバージョンがあります。`n`n現在のバージョン: $currentText`n最新バージョン: $latestText`n`n$($manifest.message)`n`n今すぐ更新しますか？`n「はい」: 更新します（完了後に自動で起動します）`n「いいえ」: 現在のバージョンで起動します"
      $result = [System.Windows.Forms.MessageBox]::Show($message, 'KarateWin 更新',
                  [System.Windows.Forms.MessageBoxButtons]::YesNo,
                  [System.Windows.Forms.MessageBoxIcon]::Information)
      if($result -eq [System.Windows.Forms.DialogResult]::Yes){
        $installer = Get-KwUpdateInstaller $manifest $latestText
        if($installer){ return (Start-KwUpdateInstall $installer) }
        return $false
      }
    }
    return $false
  }
  catch {
    # オフライン等で確認できなくても KarateWin の起動は止めない
    if($UpdateDebug){ Msg "更新確認をスキップしました。`n`n$($_.Exception.Message)`n`n現在の KarateWin を起動します。" 'Warning' }
    return $false
  }
}

# ============================================================
# 拡張ディスプレイへの切替（表示切替パネルを出さない）
#   ・すでに2画面以上が有効なら何もしない
#   ・SetDisplayConfig(SDC_TOPOLOGY_EXTEND | SDC_APPLY) で直接切り替える（Win+P のパネルは出ない）
#   ・API が使えない古い環境のみ DisplaySwitch.exe を使い、残ったパネルを閉じる
# ============================================================
function Get-KwMonitorCount { [KwWin]::GetSystemMetrics(80) }   # SM_CMONITORS（複製表示中は 1）

function Close-KwProjectFlyout {
  Get-Process DisplaySwitch -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  $fg = [KwWin]::GetForegroundWindow()
  $fgPid = 0
  [void][KwWin]::GetWindowThreadProcessId($fg, [ref]$fgPid)
  $p = Get-Process -Id $fgPid -ErrorAction SilentlyContinue
  if($p -and ($p.ProcessName -in @('DisplaySwitch','ShellExperienceHost','ShellHost'))){
    [KwWin]::PressKey(0x1B)   # Esc でパネルを閉じる
  }
}

function Set-KwExtendDisplay {
  if((Get-KwMonitorCount) -ge 2){ return }          # すでに拡張済み

  $ok = $false
  try {
    $rc = [KwWin]::SetDisplayConfig(0, [IntPtr]::Zero, 0, [IntPtr]::Zero, 0x84)   # SDC_TOPOLOGY_EXTEND(0x04) | SDC_APPLY(0x80)
    $ok = ($rc -eq 0)
  } catch { $ok = $false }

  if(-not $ok){
    # 予備: 古い方法（パネルが出るため、終わったら閉じる）
    $ds = Join-Path $env:WINDIR 'System32\DisplaySwitch.exe'
    if(Test-Path $ds){
      Start-Process $ds -ArgumentList '/extend'
      Start-Sleep -Seconds 3
      Close-KwProjectFlyout
    }
  }

  # 2台目が有効になるまで最大 8 秒待つ（ケーブル未接続なら 1 のまま進む）
  $until = (Get-Date).AddSeconds(8)
  while((Get-Date) -lt $until -and (Get-KwMonitorCount) -lt 2){ Start-Sleep -Milliseconds 300 }
  Start-Sleep -Milliseconds 1500   # 解像度の切替が落ち着くまで待つ
}

# ディスプレイ一覧（窓と同じ座標の単位。WinForms の Screen は使わない）
function Get-KwMonitors {
  foreach($s in [KwWin]::Monitors()){
    $a = $s.Split('|')
    [pscustomobject]@{
      L = [int]$a[0]; T = [int]$a[1]; R = [int]$a[2]; B = [int]$a[3]
      W = [int]$a[2] - [int]$a[0]; H = [int]$a[3] - [int]$a[1]
      Primary = ($a[4] -eq '1')
    }
  }
}

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

# 窓を前面にする: タイトルバーの中央をクリック（ボタンのない場所）。だめなら API で前面化
function Invoke-KwActivate([IntPtr]$hwnd) {
  if([KwWin]::GetForegroundWindow() -eq $hwnd){ return $true }
  $r = New-Object KwWin+RECT
  [void][KwWin]::GetWindowRect($hwnd, [ref]$r)
  [KwWin]::ClickAt([int](($r.L + $r.R) / 2), $r.T + 16)
  Start-Sleep -Milliseconds 400
  if([KwWin]::GetForegroundWindow() -eq $hwnd){ return $true }
  return [KwWin]::ForceForeground($hwnd)
}

# 窓を指定ディスプレイへ移動し、全画面(F11) または 最大化 にする
function Set-KwWindow([IntPtr]$hwnd, $mon, [string]$mode) {
  if($hwnd -eq [IntPtr]::Zero){ return $false }
  $isFull = { [KwWin]::IsFullOn($hwnd, $mon.L, $mon.T, $mon.R, $mon.B) }
  if(& $isFull){ return $true }                       # すでに目的の画面で全画面ならそのまま

  [void][KwWin]::ShowWindow($hwnd, 9)                  # SW_RESTORE（最大化・全画面解除後でないと移動できない）
  Start-Sleep -Milliseconds 300
  $w = [int]($mon.W * 0.8); $h = [int]($mon.H * 0.8)
  [void][KwWin]::SetWindowPos($hwnd, [IntPtr]::Zero, $mon.L + 40, $mon.T + 40, $w, $h, 0x0040)   # 目的の画面の中へ移動
  Start-Sleep -Milliseconds 500

  if($mode -eq 'maximized'){
    [void](Invoke-KwActivate $hwnd)
    [void][KwWin]::ShowWindow($hwnd, 3)                # SW_MAXIMIZE
    return $true
  }

  # 全画面: 前面にしてから F11 を1回だけ。窓に変化があれば押し直さない（押し直すと全画面が解除されるため）
  for($i=0; $i -lt 2; $i++){
    $before = [KwWin]::RectStr($hwnd)
    if(-not (Invoke-KwActivate $hwnd)){ Start-Sleep -Milliseconds 500; continue }
    Start-Sleep -Milliseconds 200
    [KwWin]::PressKey(0x7A)                            # VK_F11
    $until = (Get-Date).AddSeconds(4)
    while((Get-Date) -lt $until){
      if(& $isFull){ return $true }
      Start-Sleep -Milliseconds 200
    }
    if([KwWin]::RectStr($hwnd) -ne $before){ return $false }   # F11 は届いている。これ以上押さない
  }
  [void][KwWin]::ShowWindow($hwnd, 3)                  # F11 が届かなかった場合のみ最大化で代替
  return $false
}

# 操作画面の上部帯（大会名・クラス名の行。ボタンがない）の中央の画面座標
#   操作画面は 1600×900 の画面を縮小して中央に置き、上部帯は 72〜120 の高さにある
function Get-KwOperatorSafePoint($mon) {
  $s = [Math]::Min($mon.W / 1600, $mon.H / 900)
  $x = [int]($mon.L + $mon.W / 2)
  $y = [int]($mon.T + ($mon.H - 900 * $s) / 2 + 96 * $s)
  return @($x, $y)
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

# ---- 0) 最新版の確認と更新（画面切り替えより前に行う） ----
# 更新インストーラーを起動できたら、このランチャーは終了する（更新完了後にインストーラーが再起動する）
if(Test-KwUpdate){ exit 0 }

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

# ---- 1) 拡張ディスプレイに切り替え（パネルを出さない。すでに拡張なら何もしない） ----
Set-KwExtendDisplay

$monitors = @(Get-KwMonitors)
$primary  = $monitors | Where-Object { $_.Primary } | Select-Object -First 1          # Screen1
if(-not $primary){ $primary = $monitors | Select-Object -First 1 }
$second   = $monitors | Where-Object { -not $_.Primary } | Select-Object -First 1     # Screen2

# カーソルは最初からメイン画面へ
[void][KwWin]::SetCursorPos([int]($primary.L + $primary.W / 2), [int]($primary.T + $primary.H / 2))

$common = @("--user-data-dir=`"$ProfileDir`"", '--no-first-run', '--no-default-browser-check',
            '--disable-session-crashed-bubble', '--autoplay-policy=no-user-gesture-required')

# ---- 2) モニターを Screen2 に全画面で開く ----
if($second){
  Start-Process $Browser -ArgumentList ($common + @("--app=$MonitorUrl", "--window-position=$($second.L),$($second.T)"))
  $hMon = Wait-KwWindow { param($t) $t -like '*観客モニター*' }
  [void](Set-KwWindow $hMon $second 'fullscreen')
  if($hMon -ne [IntPtr]::Zero -and $MonitorTopmost){
    # 常に手前（HWND_TOPMOST）。移動・サイズ変更・前面化はしない（SWP_NOSIZE|SWP_NOMOVE|SWP_NOACTIVATE）
    [void][KwWin]::SetWindowPos($hMon, [IntPtr](-1), 0, 0, 0, 0, 0x0013)
  }
} else {
  Msg "2台目のディスプレイが見つかりません。`n操作画面だけを開きます。ケーブル接続後、窓を閉じてからもう一度起動し直してください。" 'Warning'
}

# ---- 3) 操作画面を Screen1 に全画面（または最大化）で開く ----
Start-Process $Browser -ArgumentList ($common + @("--app=$OperatorUrl", "--window-position=$($primary.L),$($primary.T)"))
$hOp = Wait-KwWindow { param($t) ($t -like '*Karate Win*') -and ($t -notlike '*観客モニター*') }
$ok = Set-KwWindow $hOp $primary $OperatorMode

# ---- 4) 仕上げ ----
#  ① 観客モニターの中央を1回クリック（モニター側はクリックしても何も起きない。残ったタイトルバーを消す）
#  ② 操作画面の上部帯（ボタンのない場所）をクリックして前面へ。カーソルもそこに置く
if($hOp -ne [IntPtr]::Zero){
  if($second -and $hMon -ne [IntPtr]::Zero -and [KwWin]::IsFullOn($hMon, $second.L, $second.T, $second.R, $second.B)){
    [KwWin]::ClickAt([int]($second.L + $second.W / 2), [int]($second.T + $second.H / 2))
    Start-Sleep -Milliseconds 600
  }
  $pt = Get-KwOperatorSafePoint $primary
  if([KwWin]::IsFullOn($hOp, $primary.L, $primary.T, $primary.R, $primary.B)){
    [KwWin]::ClickAt($pt[0], $pt[1])                   # ボタンのない上部帯をクリックして前面へ
    Start-Sleep -Milliseconds 300
    if([KwWin]::GetForegroundWindow() -ne $hOp){ [void][KwWin]::ForceForeground($hOp) }
    [void][KwWin]::SetCursorPos($pt[0], $pt[1])
  } else {
    [void](Invoke-KwActivate $hOp)                    # 最大化表示のときはタイトルバーで前面へ
  }
} else {
  Msg '操作画面の窓を確認できませんでした。手動で Screen1 に移動し、F11 キーで全画面にしてください。' 'Warning'
}
