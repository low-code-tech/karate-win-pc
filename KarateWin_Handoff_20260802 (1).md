# Karate Win 操作画面・観客モニター 開発引き継ぎドキュメント

作成日: 2026-08-02 ／ 対象セッション: 操作マニュアル作成〜v1.2改修

---

## 1. 対象ファイルと現行バージョン

| ファイル | 現行版 | 内容 |
|---|---|---|
| karate-all-in-one_v1.2.html | **v1.2**（2026-08-02） | 操作画面本体。2026-04-16版をベースにv1.1・v1.2の改修を適用 |
| karate-monitor.html | 2026-04-16版（無改修） | 観客モニター。今回の改修では変更なし |
| KarateWin_Operation_Manual_v1.2.docx | Ver.1.2 | 画面付き操作マニュアル（スクリーンショット18枚埋込・全23ページ） |

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
   - 勝利ポップアップ(win-pop)廃止 → `directWin(side,type)` を新設（`winSide=side; selectWin(type);` のみ。ポップアップ非経由で即確定）
   - win-pop のHTML/`openWinPop`/`closeWinPop` はコード残置（非表示・未使用、後方互換）
   - 「↩ 勝利取消」(cancelWin) は従来どおりバナー表示中に有効


### v1.3（動画プレーヤー2分割化）— 2026-08-02
- 課題: ハイライト飛ばし見の際、動画がジャンプボタンを覆い、閉じる→次を押すの繰り返しが冗長
- 改修: #vw-player-overlay を「動画(左・flex:1) + ハイライトパネル(右・width:min(340px,32vw))」の2ペインに変更
- vwBuildHlBtns を縦一覧化: 各行 = 番号/赤青バッジ/選手名/技/秒/▶ボタン、行クリックで vwSeekTo(sec-5)
- vwHighlightActiveBtn は borderLeftColor + background でアクティブ行表示（border-left:3px方式）
- 検証: ffmpeg生成の70秒webmで 12/35/58秒 → 7/30/53秒への連続シーク・オーバーレイ維持・アクティブ表示を確認
- 現行ファイル: karate-all-in-one_v1.3.html ／ マニュアル Ver.1.3

## 3. v1.2 主要変更箇所（karate-all-in-one_v1.2.html）

| 箇所 | 変更 |
|---|---|
| topbar #tb-row1（~873行） | ボタン並び替え・追加。インターバル/決勝・準決勝は `ivToggle(event)` / `anncToggle(event)` |
| CSS #interval-menu / #annc-menu | `position:absolute;bottom:68px` → `position:fixed;top:44px`（初期値） |
| ivToggle / anncToggle | `e.currentTarget.getBoundingClientRect()` でボタン直下（left=r.left, top=r.bottom+4）に動的配置 |
| #actbar（~1330行） | 15ボタン構成に全面書き換え。旧 ab-left-fixed/ab-right-fixed のインターバル・告知ボタンを撤去 |
| CSS .abtn.win-sm（新規） | 2行表示の小型勝利ボタン `font-size:min(11px,1.5vh);line-height:1.25;padding:5px 9px` |
| directWin（selectWin直前に新設） | ポップアップなしの直接勝利確定 |
| vwRenderCards | scDisp によるスコア表示反転（上記2-1） |

## 4. アプリのアーキテクチャ要点（改修時の前提知識）

- **2画面同期**: 操作画面→モニターは BroadcastChannel 'karate-win-sync'。操作画面が約100ms間隔で状態をbcSend、モニターは applyState(e.data) で描画。同一PC・同一Chromeプロファイル必須
- **試合結果・イベントログ**: メモリ上の配列 `EL` のみ（localStorage永続化なし）。リロードで消えるため Excel出力(expL) をこまめに行う運用
- **選手データ**: localStorage `karate_players` / `karate_eventInfo` / `karate_importedAt`。Excel取込はシート名 Sensyu_List
- **選手選択(matchload)**: `_mlVisible` はクラス選択後に生成。クラス未選択だと mlAssign が無効 → mlLaunch が無反応（テスト時の注意点）
- **試合ロード**: mlLaunch → screen-loadのフォームに値をセット → doLoad() → sw('match')。screen-load(手入力)は doLoad の入力フォームを兼ねる裏方画面
- **録画**: ▶開始で自動録画、停止・再開中も継続、勝敗確定/強制終了/時間切れで自動停止→webmダウンロード＋IndexedDB登録。録画中はカメラ切断不可
- **勝敗確定(selectWin)**: タイマー終了固定(T.finByWin)・camStopRec・バナー表示・WinDecisionログ。判定勝ちなら closeHantei
- **設定**: localStorage `kw3`。試合時間・ブザー回数/間隔・操作者ID
- **外部依存**: XLSX(cdnjs)・supabase-js(jsdelivr)。SUPABASE_URLがプレースホルダのままの環境はデモモード（認証画面スキップ）

## 5. 検証方法（このセッションで確立した手順）

Playwright headless Chromium（1600×900）でローカルHTTPサーバ経由（file://はBroadcastChannel不可のためhttp必須）:
1. localStorage にサンプル選手8名 + `kw_ob_skip=1` を注入して再ロード
2. `sw('matchload')` → **ml-class を明示選択** → `mlOnClassChange()` → `mlAssign('red',0); mlAssign('blue',1); mlLaunch()`
3. 得点は `sc('r','y',1)` 等、勝利は actbar の実ボタンをクリックして検証
4. モニター単体検証は別コンテキストで `applyState({...})` を直接呼ぶ（同一コンテキストだと操作画面のbcSendが100ms間隔で上書きするため）
- マニュアルのスクリーンショット生成スクリプト構成は shoot3.py 相当（本ドキュメント末尾の構成を参照）

## 6. 保留・要確認事項

- [ ] **下段の勝利ボタン並び順**: 修正事項.pptxのテキストから「外側=棄権/反則、中央寄り=通常勝ち」の左右対称と解釈して実装。図の意図と異なれば並び替えのみで対応可
- [ ] **勝利ボタンの誤操作リスク**: ポップアップ廃止により1クリック確定。取消はバナーの「↩ 勝利取消」。確認ダイアログ追加の要否は運用後に判断
- [ ] **イベントログ画面の「◀ 戻る」**: 現状は試合画面へ戻る（元コードのまま）。「試合結果へ戻る」への変更は1行修正
- [ ] karate-monitor.html は無改修。モニター側の表示変更要望が出た場合は別途
- [ ] マニュアルの目次: Word で開いて右クリック→フィールド更新が必要（既知の仕様）

## 7. マニュアル生成メモ

- docx(npm) で生成。フォント Yu Gothic、見出しネイビー(1F3864)/アクセント(2E5496)、A4縦・余白20mm
- スクリーンショットは 1600×900 → 600px幅(通常)/520px幅(モニター縦連続)で埋込、図番号は自動連番
- 章構成: 1概要／2起動とログイン／3試合前の準備／4試合画面／5カメラ録画／6記録の出力／7動画閲覧／8観客モニター／9設定／10トラブルシューティング＋改訂履歴
- ファイル名はASCII（KarateWin_Operation_Manual_vX.X.docx）
