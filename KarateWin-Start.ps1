# ============================================================
#  KarateWin 起動ランチャー  v1.0
#  1) Windows を「拡張」ディスプレイ構成に切り替える
#  2) 観客モニター(karate-monitor.html)を 2台目の画面に全画面で開く
#  3) 操作画面(karate-all-in-one.html)を メイン画面に最大化で開く
#  ※ 2つの窓は同じ専用プロファイルで開く（別プロファイルだと画面間の同期ができないため）
# ============================================================

# ---- 設定（必要に応じて変更） -------------------------------
# 空欄なら、このランチャーと同じフォルダのHTMLを開く。Vercel版を使う場合は例のように指定
$BaseUrl      = ''        # 例: 'https://karate-win-pc.vercel.app/'
$OperatorFile = 'karate-all-in-one.html'
$MonitorFile  = 'karate-monitor.html'
$ProfileDir   = Join-Path $env:LOCALAPPDATA 'KarateWin\BrowserProfile'
# -------------------------------------------------------------

Add-Type -AssemblyName System.Windows.Forms
function Msg($text,$icon='Information'){ [void][System.Windows.Forms.MessageBox]::Show($text,'KarateWin',[System.Windows.Forms.MessageBoxButtons]::OK,$icon) }

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
$running = Get-CimInstance Win32_Process -Filter "Name='chrome.exe' OR Name='msedge.exe'" |
           Where-Object { $_.CommandLine -like "*KarateWin\BrowserProfile*" }
if($running){ Msg "KarateWin はすでに起動しています。`n開き直す場合は、操作画面とモニターの窓を両方閉じてから、もう一度起動してください。" 'Warning'; exit 0 }

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

# ---- 2台目の画面の位置を取得 ----
$screens = [System.Windows.Forms.Screen]::AllScreens
$second  = $screens | Where-Object { -not $_.Primary } | Select-Object -First 1
$primary = [System.Windows.Forms.Screen]::PrimaryScreen

$common = @("--user-data-dir=`"$ProfileDir`"", '--no-first-run', '--no-default-browser-check',
            '--disable-session-crashed-bubble', '--autoplay-policy=no-user-gesture-required')

if($second){
  # ---- 2) モニターを 2台目の画面に全画面で開く（先に開く＝このプロセスの起動オプションとして全画面が効く） ----
  $b = $second.Bounds
  $monArgs = $common + @("--app=$MonitorUrl", "--window-position=$($b.X),$($b.Y)", "--window-size=$($b.Width),$($b.Height)", '--start-fullscreen')
  Start-Process $Browser -ArgumentList $monArgs
  Start-Sleep -Seconds 4
} else {
  Msg "2台目のディスプレイが見つかりません。`n操作画面だけを開きます。ケーブル接続後、もう一度起動し直してください。" 'Warning'
}

# ---- 3) 操作画面をメイン画面に最大化で開く ----
$p = $primary.WorkingArea
$opArgs = $common + @("--app=$OperatorUrl", "--window-position=$($p.X),$($p.Y)", "--window-size=$($p.Width),$($p.Height)", '--start-maximized')
Start-Process $Browser -ArgumentList $opArgs
