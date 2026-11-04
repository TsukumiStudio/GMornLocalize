@tool
class_name GMornLocalize
extends Node

## 画面に出す文言の取得口。文言はCSV（`keys,ja,en,…`）にIDのキーで集め、起動時に読んで
## 列ごとの言語の翻訳として `TranslationServer` へ登録する。
## Godot の CSV 取り込みは使わない。生成物の `.translation` が git に入り、マージで表と食い違ったまま残るため。
## `@tool` なのは Editor の Preview Translation にも同じ表を効かせるため。
## 呼ぶ側は `GMornLocalize.get_text("KEY", [値…])` だけを使う。`tr()` と `TranslationServer.translate()` を
## 混ぜると、Node と static 関数で呼び方が割れる。
## GMorn の他の部品と違い `class_name` を持つ。文言は const の表や static 関数や `--script` で先に読まれる台本からも
## 引くが、自動読み込みの名前はそこではまだ解決できない。自動読み込みは別名 `GMornLocalizeTable` で同じ台本を指し、
## 表の登録だけを受け持つ（名前が同じだと class_name と自動読み込みがぶつかる）。

const TABLE_DIR_SETTING := "gmorn_localize/table_dir"
const TABLE_PATH_SETTING := "gmorn_localize/table_path"
const DEFAULT_TABLE_PATH := "res://localization.csv"

var translations: Array[Translation] = []

## 最初の画面より先に登録が済むよう `_ready()` でなく `_init()` で読む。
func _init() -> void:
	var directory := String(ProjectSettings.get_setting(TABLE_DIR_SETTING, ""))
	var tables := read_directory(directory) if directory != "" else read_table(table_path())
	for translation: Translation in tables:
		TranslationServer.add_translation(translation)
		translations.append(translation)

## Editor でスクリプトを読み直したとき、古い表を残して二重に登録しない。
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for translation: Translation in translations:
			TranslationServer.remove_translation(translation)

## 表には埋める所を `{1}` `{2}` と番号で書き、`args` に順に渡す。番号なので、訳で語順が変わっても引数は並べ替えない。
## 見せ方は表の側に書く。呼ぶ側は生の値を渡す（見せ方は言語ごとに変わりうるので、呼ぶ側に漏らさない）。
## - `{1:money}` 整数を3桁区切りにする（777584 → 777,584）
## - `{1:.2}` 数を小数2桁にする（1.25）。`{1:.0}` は整数に丸める
## 書式の無い `{1}` に float は渡さない。桁が値で揺れるので、表に `.N` を書く。
static func get_text(key: String, args: Array = []) -> String:
	var text := String(TranslationServer.translate(key))
	if args.is_empty():
		return text
	var matches := RegEx.create_from_string("\\{(\\d+)(?::([^}]+))?\\}").search_all(text)
	# 後ろから置き換えると、前の位置がずれない。
	matches.reverse()
	for found: RegExMatch in matches:
		var index := int(found.get_string(1)) - 1
		if index < 0 or index >= args.size():
			continue
		text = text.substr(0, found.get_start()) + _format(key, found.get_string(0), args[index], found.get_string(2)) + text.substr(found.get_end())
	return text

static func _format(key: String, place: String, value: Variant, spec: String) -> String:
	if spec == "money":
		if not value is int:
			push_error("%s の %s に整数でない値が来た: %s" % [key, place, value])
			return str(value)
		return _group_digits(value)
	if spec.begins_with(".") and spec.substr(1).is_valid_int():
		if not (value is int or value is float):
			push_error("%s の %s に数でない値が来た: %s" % [key, place, value])
			return str(value)
		return ("%." + spec.substr(1) + "f") % float(value)
	if spec != "":
		push_error("%s の %s の書式が分からない" % [key, place])
	elif value is float:
		push_error("%s の %s に float が来た。表に {n:.2} のように桁を書く: %s" % [key, place, value])
	return str(value)

static func _group_digits(amount: int) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	grouped = digits + grouped
	return "-" + grouped if amount < 0 else grouped

static func table_path() -> String:
	return String(ProjectSettings.get_setting(TABLE_PATH_SETTING, DEFAULT_TABLE_PATH))

## 1列目がキー、2列目以降が見出しの言語。`\n` などは文言の側だけ解く。
static func read_table(path: String) -> Array[Translation]:
	return _read_tables(PackedStringArray([path]))

static func read_directory(path: String) -> Array[Translation]:
	var directory := DirAccess.open(path)
	if directory == null:
		push_error("文言の表のディレクトリが読めない: %s" % path)
		return []
	var paths := PackedStringArray()
	for file_name in directory.get_files():
		if file_name.ends_with(".csv"):
			paths.append(path.path_join(file_name))
	paths.sort()
	if paths.is_empty():
		push_error("文言の表がない: %s" % path)
		return []
	return _read_tables(paths)

static func _read_tables(paths: PackedStringArray) -> Array[Translation]:
	var result: Array[Translation] = []
	var keys := {}
	for path in paths:
		var csv := FileAccess.open(path, FileAccess.READ)
		if csv == null:
			push_error("文言の表が読めない: %s" % path)
			return []
		var header := csv.get_csv_line()
		if header.size() < 2 or header[0] != "keys":
			push_error("文言の表の見出しが不正: %s" % path)
			return []
		var locales := {}
		var translations: Array[Translation] = []
		for column in range(1, header.size()):
			if header[column].is_empty() or locales.has(header[column]):
				push_error("文言の表の言語が不正: %s" % path)
				return []
			locales[header[column]] = true
			var translation := Translation.new()
			translation.locale = header[column]
			translations.append(translation)
		while not csv.eof_reached():
			var row := csv.get_csv_line()
			if row.size() == 1 and row[0].is_empty():
				continue
			if row.size() != header.size() or row[0].is_empty():
				push_error("文言の表の行が不正: %s" % path)
				return []
			if keys.has(row[0]):
				push_error("文言のキーが重複: %s (%s)" % [row[0], path])
				return []
			keys[row[0]] = true
			for column in range(1, header.size()):
				if row[column] != "":
					translations[column - 1].add_message(row[0], row[column].c_unescape())
		result.append_array(translations)
	return result
