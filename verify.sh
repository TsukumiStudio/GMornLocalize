#!/bin/sh
# この部品だけをヘッドレスで確かめる。
#
# リポジトリ直下に project.godot は置けない。submodule として取り込まれた先に
# project.godot があると、Godot がそこを別プロジェクトと見なして書き出しから外す。
# 代わりに一時の最小プロジェクトへ写して回す。
set -eu

addon_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
godot_bin=${GODOT_BIN:-$(command -v godot 2>/dev/null || echo /Applications/Godot.app/Contents/MacOS/Godot)}
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

mkdir -p "$work_dir/addons/gmorn_localize"
cp "$addon_dir"/*.gd "$addon_dir"/plugin.cfg "$work_dir/addons/gmorn_localize/"
cp "$addon_dir/verify.gd" "$work_dir/verify.gd"
# 部品の中の相対参照に合わせるため、確認用の読み込み先も addons/ を指す。
sed -i '' 's|res://gmorn_|res://addons/gmorn_localize/gmorn_|g' "$work_dir/verify.gd" 2>/dev/null \
  || sed -i 's|res://gmorn_|res://addons/gmorn_localize/gmorn_|g' "$work_dir/verify.gd"

cat > "$work_dir/project.godot" <<'PROJECT'
config_version=5

[application]

config/name="GMornLocalize Verify"
config/features=PackedStringArray("4.7")
PROJECT

# class_name は一度走査しないと引けないので、先に取り込みを回す。
"$godot_bin" --headless --path "$work_dir" --import >/dev/null 2>&1 || true
"$godot_bin" --headless --path "$work_dir" --script verify.gd
