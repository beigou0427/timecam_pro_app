#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_SRC="$ROOT_DIR/scripts/record_iphone_screen.swift"
RECORDER_BIN="/tmp/timecam_iphone_recorder"
MOD_CACHE="/tmp/swift_modcache"
OUT_DIR="$ROOT_DIR/build/review_recording"
RAW_MOV="$OUT_DIR/review_raw_45s.mov"
FINAL_MP4="$OUT_DIR/review_demo_45s.mp4"

mkdir -p "$OUT_DIR" "$MOD_CACHE"

transcode_to_mp4() {
  local src="$1"
  local dst="$2"
  if [[ ! -f "$src" ]]; then
    echo "❌ 找不到影片檔案：$src" >&2
    exit 1
  fi
  rm -f "$dst"
  echo "🎞️ 正在透過 macOS 硬體轉檔為輕量 720p MP4（符合 Apple 審核附件規格）..."
  /usr/bin/avconvert --preset Preset1280x720 --source "$src" --output "$dst" --replace
  local size_bytes
  size_bytes=$(stat -f%z "$dst")
  local size_mb
  size_mb=$(awk -v b="$size_bytes" 'BEGIN { printf "%.2f", b / 1048576 }')
  echo "✅ 審核影片已就緒：$dst（${size_mb} MB）"
  echo "👉 下一步：把這個檔案路徑貼回對話給 AI，就能直接上傳至 App Store Connect 原生審核附件並送審！"
}

MUTE_FLAG=""
CONVERT_SRC=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mute)
      MUTE_FLAG="--mute"
      shift
      ;;
    --convert)
      CONVERT_SRC="${2:-}"
      if [[ -z "$CONVERT_SRC" ]]; then
        echo "用法：$0 --convert /path/to/RPReplay.mov" >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      echo "用法："
      echo "  $0                    # USB 直連 iPhone 實機錄製 45 秒並自動壓縮為 MP4"
      echo "  $0 --mute             # 同上，但關閉語音報幕提示"
      echo "  $0 --convert <檔案>   # 將手機 AirDrop 的 .mov 轉為輕量審核 MP4"
      exit 0
      ;;
    *)
      echo "未知參數：$1（請加 --help 查看用法）" >&2
      exit 1
      ;;
  esac
done

if [[ -n "$CONVERT_SRC" ]]; then
  transcode_to_mp4 "$CONVERT_SRC" "$FINAL_MP4"
  exit 0
fi

if [[ ! -x "$RECORDER_BIN" || "$SWIFT_SRC" -nt "$RECORDER_BIN" ]]; then
  echo "⚙️ 編譯原生 macOS iPhone 錄影工具（只需一次）..."
  swiftc -O -module-cache-path "$MOD_CACHE" "$SWIFT_SRC" -o "$RECORDER_BIN"
fi

echo "📱 請先解鎖 iPhone 18 Pro 並停在桌面（準備好按 Enter 立刻開始 45 秒倒數錄影，按 Ctrl+C 可提前結束）..."
if [[ -t 0 ]]; then
  read -r
fi

"$RECORDER_BIN" "$RAW_MOV" 45 ${MUTE_FLAG:+"$MUTE_FLAG"}
transcode_to_mp4 "$RAW_MOV" "$FINAL_MP4"
