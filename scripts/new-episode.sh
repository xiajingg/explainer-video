#!/usr/bin/env bash
# 建一个期目录：标题.txt + 文案.txt + 16x9/ + 9x16/
# 用法: new-episode.sh <期目录> ["标题"]

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "用法: new-episode.sh <期目录> [\"标题\"]"
  exit 1
fi

DIR="$1"
TITLE="${2:-$(basename "$DIR")}"

mkdir -p "$DIR/16x9" "$DIR/9x16"

[ -f "$DIR/标题.txt" ] || printf '%s\n' "$TITLE" > "$DIR/标题.txt"
[ -f "$DIR/文案.txt" ] || : > "$DIR/文案.txt"

cat <<EOF
已创建: $DIR
  标题: $TITLE

下一步:
  1. 横版图放进 $DIR/16x9/，竖版图放进 $DIR/9x16/（文件名 01.png、02.png ...）
  2. 文案写进 $DIR/文案.txt，每行一段，80~95 个汉字
  3. 每个比例的图片张数 = 段落数
  4. 渲染: ./render.sh "$DIR"
EOF
