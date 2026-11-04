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

[internationalization]

locale/fallback="ja"
PROJECT

# class_name は一度走査しないと引けないので、先に取り込みを回す。
"$godot_bin" --headless --path "$work_dir" --import >/dev/null 2>&1 || true
cat > "$work_dir/verify_settings.gd" <<'SCRIPT'
extends SceneTree

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var plugin: EditorPlugin = load("res://addons/gmorn_localize/plugin.gd").new()
	plugin._register_settings()
	var valid: bool = ProjectSettings.get_setting("gmorn_localize/table_dir") == ""
	var found := false
	for property in ProjectSettings.get_property_list():
		if property.name == "gmorn_localize/table_dir":
			found = true
			valid = valid and property.type == TYPE_STRING and property.hint == PROPERTY_HINT_DIR
			valid = valid and bool(property.usage & PROPERTY_USAGE_EDITOR_BASIC_SETTING)
	plugin.free()
	if not valid or not found:
		push_error("表のディレクトリ設定が正しく登録されない")
		quit(1)
		return
	print("GMORN LOCALIZE SETTINGS VERIFY: PASS")
	quit(0)
SCRIPT
"$godot_bin" --headless --editor --path "$work_dir" --script verify_settings.gd
"$godot_bin" --headless --path "$work_dir" --script verify.gd
