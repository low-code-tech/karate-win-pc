# -*- coding: utf-8 -*-
"""
Karate Win 大会動画 軽量版(720p)一括生成スクリプト
====================================================
video_master の storage_path にある原本動画をダウンロードし、
720p / H.264 / faststart の軽量版に変換して同じバケットにアップロードし、
metadata.proxy_path に記録します。稽古スタジオ v8.4 以降はこの軽量版を
自動的に優先再生します(⚡軽量版バッジが付きます)。

【準備(Windows・1回だけ)】
1. ffmpeg のインストール:  コマンドプロンプトで  winget install ffmpeg
2. Python ライブラリ:      pip install supabase requests
3. 下の SERVICE_ROLE_KEY にサービスロールキーを貼り付ける
   (Supabase管理画面 → Project Settings → API → service_role)
   ※ このキーは全権限を持つため、このファイルを人に渡さないこと。

【実行】
    python make_proxy_720p.py            # 軽量版が無い動画をすべて処理
    python make_proxy_720p.py --limit 5  # まず5本だけ試す
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile

import requests
from supabase import create_client

# ======== 設定 ========
SUPABASE_URL = "https://ocxyycuasswuztjkbwuf.supabase.co"
SERVICE_ROLE_KEY = "ここにservice_roleキーを貼り付け"   # ★必ず書き換える
DEFAULT_BUCKET = "karate-videos"
PROXY_SUFFIX = "_720p.mp4"
# 720p / 約1.8Mbps。100MBの1080pがおおよそ15〜25MB程度になります
FFMPEG_ARGS = [
    "-vf", "scale=-2:720",
    "-c:v", "libx264", "-preset", "fast", "-crf", "26",
    "-c:a", "aac", "-b:a", "96k",
    "-movflags", "+faststart",   # 再生開始を速くする(メタデータを先頭へ)
]
# ======================


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0, help="処理する最大本数(0=全部)")
    ap.add_argument("--force", action="store_true", help="軽量版があっても作り直す")
    args = ap.parse_args()

    if "貼り付け" in SERVICE_ROLE_KEY:
        sys.exit("SERVICE_ROLE_KEY を設定してください。")

    sb = create_client(SUPABASE_URL, SERVICE_ROLE_KEY)

    rows = (
        sb.table("video_master")
        .select("id, title, tournament, storage_path, storage_bucket, metadata")
        .not_.is_("storage_path", "null")
        .order("recorded_at", desc=True)
        .execute()
        .data
    )

    targets = []
    for r in rows:
        md = r.get("metadata") or {}
        if md.get("proxy_path") and not args.force:
            continue
        targets.append(r)
    if args.limit:
        targets = targets[: args.limit]

    print(f"対象: {len(targets)} 本")

    ok = ng = 0
    for i, r in enumerate(targets, 1):
        bucket = r.get("storage_bucket") or DEFAULT_BUCKET
        src_path = r["storage_path"]
        base, _ext = os.path.splitext(src_path)
        proxy_path = base + PROXY_SUFFIX
        label = r.get("title") or r.get("tournament") or r["id"]
        print(f"\n[{i}/{len(targets)}] {label}")

        try:
            # 1) 原本をダウンロード(署名URL経由)
            signed = sb.storage.from_(bucket).create_signed_url(src_path, 3600)
            url = signed.get("signedURL") or signed.get("signed_url")
            if not url:
                raise RuntimeError(f"署名URL取得失敗: {signed}")
            if url.startswith("/"):
                url = SUPABASE_URL + "/storage/v1" + url

            with tempfile.TemporaryDirectory() as td:
                src = os.path.join(td, "src.mp4")
                dst = os.path.join(td, "dst.mp4")
                with requests.get(url, stream=True, timeout=600) as resp:
                    resp.raise_for_status()
                    with open(src, "wb") as f:
                        for chunk in resp.iter_content(1024 * 1024):
                            f.write(chunk)
                size_mb = os.path.getsize(src) / 1e6
                print(f"  DL完了 {size_mb:.1f}MB → 720p変換中…")

                # 2) ffmpegで720p変換
                cmd = ["ffmpeg", "-y", "-i", src, *FFMPEG_ARGS, dst]
                res = subprocess.run(cmd, capture_output=True, text=True)
                if res.returncode != 0:
                    raise RuntimeError("ffmpeg失敗:\n" + res.stderr[-600:])
                out_mb = os.path.getsize(dst) / 1e6
                print(f"  変換完了 {out_mb:.1f}MB → アップロード中…")

                # 3) アップロード(既存があれば上書き)
                with open(dst, "rb") as f:
                    sb.storage.from_(bucket).upload(
                        proxy_path, f.read(),
                        {"content-type": "video/mp4", "upsert": "true"},
                    )

            # 4) metadata.proxy_path を書き込み(既存metadataとマージ)
            md = r.get("metadata") or {}
            md["proxy_path"] = proxy_path
            md["proxy_bucket"] = bucket
            sb.table("video_master").update({"metadata": md}).eq("id", r["id"]).execute()
            print(f"  ✅ 完了: {proxy_path}")
            ok += 1

        except Exception as e:
            print(f"  ❌ 失敗: {e}")
            ng += 1

    print(f"\n===== 完了: 成功 {ok} / 失敗 {ng} =====")
    print("稽古スタジオのマイライブラリを開き直すと ⚡軽量版 バッジが付き、高速に再生されます。")


if __name__ == "__main__":
    main()
