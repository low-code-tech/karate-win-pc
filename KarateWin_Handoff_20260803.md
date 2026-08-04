# Karate Win 操作画面・観客モニター 開発引き継ぎドキュメント

作成日: 2026-08-03 ／ 対象セッション: 操作マニュアル作成〜v1.7改修（iPad対応・UI大型化）

---

## 1. 対象ファイルと現行バージョン

| ファイル | 現行版 | 内容 |
|---|---|---|
| karate-all-in-one_v1.7.html | **v1.7**（2026-08-03） | 操作画面本体。2026-04-16版をベースにv1.1〜v1.7の改修を適用 |
| karate-monitor.html | 2026-04-16版（無改修） | 観客モニター。改修なし |
| KarateWin_Operation_Manual_v1.7.docx | Ver.1.7 | 画面付き操作マニュアル（スクリーンショット22枚埋込・全25ページ） |

デプロイ: GitHub Web UI でファイル内容を置き換え → Vercel 自動反映（ブラウザのみの運用）。

## 2. 改修履歴

### v1.1（導線追加）— 元の2026-04-16版はレガシー画面への導線が欠落していた
- トップバーに「📱 閲覧」→ screen-viewer（v1.2で「📱 動画閲覧」に改称）
- 選手選択画面上部バーに「✎ 手入力」→ screen-load（試合情報入力）
- 試合結果画面右上に「📋 詳細ログ」→ screen-log
- 背景: screen-load / screen-log / screen-viewer / screen-video-setting は旧ナビタブ時代の名残でボタン導線が存在しなかった（viewerとvideo-settingは相互リンクのみの孤立状態だった）

### v1.2（修正事項.pptx対応）
1. **閲覧画面の点数反転バグ修正**
   - 原因: 試合結果行の得点列 r[10] は `bPts+' 対 '+rPts`（青 対 赤）形式。閲覧カードは赤(左)/青(右)配置のため数字が逆に見えた
   - 修正: `vwRenderCards` 内で `const scDisp=m.score?m.score.split(' 対 ').reverse().join(' 対 '):'—'` として表示のみ反転。結果表・Excel出力の形式（青対赤）は不変
2. **ボタン配置変更**
   - 上段トップバー（左→右）: 設定／📹カメラ(+RECドット)／試合結果／📱動画閲覧／インターバル／決勝・準決勝｜spacer｜選手選択／リセット／判定
   - 下段actbar（左→右）: 青[勝ち(相手棄権)・勝ち(相手反則)・判定勝ち・通常勝ち]→青先取→＋1秒→｜開始・停止・再開｜→－1秒→赤先取→赤[通常勝ち・判定勝ち・勝ち(相手反則)・勝ち(相手棄権)]
   - 勝利ポップアップ(win-pop)廃止 → `directWin(side,type)` を新設（ポップアップ非経由で即確定）
   - win-pop のHTML/`openWinPop`/`closeWinPop` はコード残置（非表示・未使用、後方互換）
   - 「↩ 勝利取消」(cancelWin) は従来どおりバナー表示中に有効

### v1.3（動画プレーヤー2分割化）— 2026-08-02
- #vw-player-overlay を「動画(左・flex:1) + ハイライトパネル(右・width:min(340px,32vw))」の2ペインに変更
- vwBuildHlBtns を縦一覧化: 各行 = 番号/赤青バッジ/選手名/技/秒/▶ボタン、行クリックで vwSeekTo(sec-5)
- vwHighlightActiveBtn は borderLeftColor + background でアクティブ行表示

### v1.4（プレーヤーの点数反転・シークずれ修正）— 2026-08-02
- ①vwOpenPlayerのタイトル点数を 赤対青 に反転
- ②ハイライトシークの基準を変更: 試合タイマー経過秒(sec) → 録画開始からの実時間(vsec)。buildMatchListで最初の'Start'イベントのatを recStartIso として捕捉し、各ハイライトに vsec を付与。vsec優先・secフォールバック
- ③vwSeekToに動画長クランプ追加（duration-1超は末尾-3秒へ+トースト通知）

### v1.5（判定を得点に反映しない仕様へ変更）— 2026-08-02
- commitHantei から SC書き換え(updSc含む)を削除。alog('Hantei', 旗数+主審+集計)とトースト案内のみ
- 判定の勝敗確定は下段「判定勝ち」ボタン（selectWin('decision') が closeHantei も実施）
- 結果表・Excel・閲覧カードはScoreログ累積のため元々旗数を含まず、全経路が一致

### v1.6（閲覧カードのハイライトボタン削除）— 2026-08-02
- vwRenderCards から「ハイライトシーン」トグルボタン・展開リスト・vwToggleHL を削除
- ハイライト件数は「▶ 試合動画」ボタンのサブラベルに統合
- 注意: 旧カードリストにはYouTubeのシーン別ジャンプリンク(hUrl)があった。ローカル動画がなくYouTubeのみの試合は、現状シーン別ジャンプ手段がない（要望が出たら復活検討）

### v1.7（iPad対応・UI大型化・機能改善）— 2026-08-03
**a. 16:9スケーリング方式（iPad対応の根幹）**
- viewport meta追加（これが無くiPad Safariが仮想幅980pxで描画→両端切れが発生していた）+ apple-mobile-web-app系meta追加（ホーム画面追加でフルスクリーン起動）
- fit169を「1600×900固定キャンバス + transform:scale縮小 + 中央配置」に変更。中身は常にPC設計サイズで描画されるため崩れない。window.KW_SCALE を公開
- transform配下では position:fixed の座標系がキャンバス内になるため、ivToggle/anncToggle のメニュー座標をスケール換算
- resize / orientationchange / visualViewport.resize で再フィット
- vh/vw基準だったフォント（#tdis・sbt-score・pen-big・win-banner・sentoku-badge等）をキャンバス基準の固定pxへ変換（viewport依存だと小画面で二重に縮小されるため）

**b. レイアウト再配分（1600×900キャンバス内）**
- topbar: row1 72px（ボタン19px化）+ row2 48px = 120
- 選手名行: 210px固定（よみがな24px／氏名84px基準／所属26px）
- アリーナ: 900-120-210-92 = 478px
- actbar: 92px（.abtn 19px/16px padding、.win-sm 15px、判定勝ち・通常勝ちは .win-wide で左右padding 26px）
- fitScoreFont: arenaH = rh-120-210-92、fs = min(colW*0.88, arenaH*0.68)、fs2 = fs*0.74（2桁時）

**c. ペナルティ移設・タイマー/得点拡大**
- 得点板から反則行(pen-row)を削除し、.pen-corner を #bot-blue 右下／#bot-red 左下に新設（＋が中央寄り）。ID bv-p-s/rv-p-s は維持＝Excel出力・ログ経路は不変
- #bot-blue/#bot-red に padding-bottom:116px でペナルティ予約領域を確保（合計数字との重なり防止）
- kb-hints（KEYBOARD）は赤エリア右下へ移動
- #tdis は flex:1 で得点板上の余白を全て使用、255px。得点板は中央エリア下端に固定

**d. 氏名まわり**
- よみがな表示（20→24px）。**重要バグ修正**: fitScoreFont/fitPlayerName がIIFE内スコープで updSc からの `typeof` ガード呼出しが常にスキップされていた → window公開で解消。doLoad に名前確定後の fitPlayerName 呼出しを追加
- fitPlayerName を測定ベースに書換え: ≤4字84px…≤10字48px、11字超は56px開始で折返し許可（maxHeight110px、収まるまで2px刻み縮小・最低18px）

**e. その他UI**
- ロゴ「Karate Win」クリック → sw('onboarding')（はじめに画面へ）。はじめに画面のタイトル行「はじめに — 4ステップで試合開始」を削除
- 試合画面以外（.sc.sub と #screen-matchload）に zoom:1.22（小さすぎた文字の一括拡大）
- 選手選択カード: 氏名＋よみがなを1行統合、全行 flex-shrink:0、ROWSを固定5→高さベース動的算出(min86px/card,max5)に変更（zoom起因の縦潰れを解消）

**f. Excel取込の堅牢化（impHandleFile）**
- 全シートから選手名列を持つシートを探索（Sensyu_List優先）
- 列名エイリアス: 選手名=氏名/名前/選手氏名、よみがな=ふりがな/フリガナ/ヨミガナ/読み仮名、ゼッケンNo=ゼッケン/番号/No、所属=所属道場/道場、クラス=学年/クラス・学年、コート=コートNo
- 先頭10行からヘッダー行を自動検出（タイトル行付きファイル対応）
- 0名時は「検出した列名」を診断表示（ユーザーが自力で原因特定できる）
- 発端: ユーザーのファイルが Sensyu_List シート無し・選手名列無しで0名になった事例

## 3. アプリのアーキテクチャ要点（改修時の前提知識）

- **16:9キャンバス**: #root169 は常に1600×900で描画し transform:scale で画面にフィット。レイアウト定数（topbar120/氏名210/actbar92）を変える場合は fitScoreFont の定数も必ず同期すること
- **fitScoreFont/fitPlayerName は window 公開済み**（v1.7d）。updSc→fitScoreFont→fitPlayerName の再計算チェーンが得点更新ごとに動く
- **2画面同期**: 操作画面→モニターは BroadcastChannel 'karate-win-sync'。約100ms間隔でbcSend。同一PC・同一Chromeプロファイル必須
- **試合結果・イベントログ**: メモリ上の配列 `EL` のみ（localStorage永続化なし）。リロードで消えるため Excel出力(expL) をこまめに行う運用
- **選手データ**: localStorage `karate_players` / `karate_eventInfo` / `karate_importedAt`。選手オブジェクトのキーは no/bib/name/yomi/club/cls/court
- **選手選択(matchload)**: `_mlVisible` はクラス選択後に生成。クラス未選択だと mlAssign が無効 → mlLaunch が無反応（テスト時の注意点）
- **試合ロード**: mlLaunch → screen-loadのフォームに値をセット → doLoad() → sw('match')
- **録画**: ▶開始で自動録画、停止・再開中も継続、勝敗確定/強制終了/時間切れで自動停止→webmダウンロード＋IndexedDB登録。録画中はカメラ切断不可
- **勝敗確定(selectWin)**: タイマー終了固定・camStopRec・バナー表示・WinDecisionログ。判定勝ちなら closeHantei
- **設定**: localStorage `kw3`。試合時間・ブザー回数/間隔・操作者ID
- **外部依存**: XLSX(cdnjs)・supabase-js(jsdelivr)。SUPABASE_URLがプレースホルダのままの環境はデモモード（認証画面スキップ）

## 4. 検証方法（このセッションで確立した手順）

Playwright headless Chromium（1600×900 と 1133×744=iPad横相当）でローカルHTTPサーバ経由（file://はBroadcastChannel不可のためhttp必須）:
1. localStorage にサンプル選手 + `kw_ob_skip=1` を注入して再ロード（選手キーは name/yomi/cls/club/court/bib）
2. `sw('matchload')` → **ml-class を明示選択** → `mlOnClassChange()` → `mlAssign('red',i); mlAssign('blue',j); mlLaunch()`
3. 得点は `sc('r','y',1)` 等、勝利・ペナルティは実ボタンをクリックして検証
4. **はみ出し監査**: #screen-match 配下の全可視要素の getBoundingClientRect が #root169 内に収まるかを走査（v1.7の定番チェック）
5. **Excel取込テスト**: 本検証環境はcdnjs遮断のため、npmから xlsx@0.18.5 を取得し `page.route('**/xlsx.full.min.js', fulfill)` でCDNを差替え。openpyxlで正規形/別名列/下段ヘッダー/列欠落の4種xlsxを生成し `set_input_files('#imp-file')` で実ドロップ検証
6. マニュアル用スクリーンショットは manual/shots/ に fig01〜fig22（fig16とfig18〜21は旧docxから流用：動画プレーヤーは要動画データ、モニターは無改修のため）

## 5. 保留・要確認事項

- [ ] karate-monitor.html は無改修（16:9対応は元々実装済み）。操作画面のペナルティ移設に伴うモニター側の表示変更要望が出た場合は別途
- [ ] YouTubeのみの試合のシーン別ジャンプ（v1.6で削除したまま）
- [ ] 勝利ボタンの誤操作リスク: 1クリック確定＋「↩ 勝利取消」。確認ダイアログ追加の要否は運用後に判断
- [ ] イベントログ画面の「◀ 戻る」は試合画面へ戻る（元コードのまま）
- [ ] マニュアルの目次: Word で開いて右クリック→フィールド更新が必要（既知の仕様）
- [ ] win-pop / pen-row 関連の残置CSS（未使用・後方互換）

## 6. マニュアル生成メモ

- docx(npm) で生成（manual/gen_manual.js）。フォント Yu Gothic、見出しネイビー(1F3864)/アクセント(2E5496)、A4縦・余白20mm、フッターにページ番号
- スクリーンショットは 1600×900 → 600px幅(通常)/520px幅(モニター縦連続)で埋込、図番号は生成スクリプト内で自動連番（図1〜図22）
- 章構成: 1概要／2起動とログイン(2.3にiPadホーム画面追加を新設)／3試合前の準備／4試合画面／5カメラ録画／6記録の出力／7動画閲覧／8観客モニター／9設定／10トラブルシューティング＋改訂履歴
- ファイル名はASCII（KarateWin_Operation_Manual_vX.X.docx）
