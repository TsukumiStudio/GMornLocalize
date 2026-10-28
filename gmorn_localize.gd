@tool
class_name GMornLocalize
extends Node

## 画面に出す文言の取得口。文言は1枚のCSV（`keys,ja,en,…`）にIDのキーで集め、起動時に読んで
## 列ごとの言語の翻訳として `TranslationServer` へ登録する。
## Godot の CSV 取り込みは使わない。生成物の `.translation` が git に入り、マージで表と食い違ったまま残るため。
## `@tool` なのは Editor の Preview Translation にも同じ表を効かせるため。
## 呼ぶ側は `GMornLocalize.get_text("KEY", [値…])` だけを使う。`tr()` と `TranslationServer.translate()` を
## 混ぜると、Node と static 関数で呼び方が割れる。
## GMorn の他の部品と違い `class_name` を持つ。文言は const の表や static 関数や `--script` で先に読まれる台本からも
## 引くが、自動読み込みの名前はそこではまだ解決できない。自動読み込みは別名 `GMornLocalizeTable` で同じ台本を指し、
## 表の登録だけを受け持つ（名前が同じだと class_name と自動読み込みがぶつかる）。

const TABLE_PATH_SETTING := "gmorn_localize/table_path"
const DEFAULT_TABLE_PATH := "res://localization.csv"

var translations: Array[Translation] = []

## 最初の画面より先に登録が済むよう `_ready()` でなく `_init()` で読む。
func _init() -> void:
	for translation: Translation in read_table(table_path()):
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

## 1列目がキー、2列目以降が見出しの言語。`\n` などは Godot の取り込みと同じく文言の側だけ解く。
static func read_table(path: String) -> Array[Translation]:
	var result: Array[Translation] = []
	var csv := FileAccess.open(path, FileAccess.READ)
	if csv == null:
		push_error("文言の表が読めない: %s" % path)
		return result
	var header := csv.get_csv_line()
	for column in range(1, header.size()):
		var translation := Translation.new()
		translation.locale = header[column]
		result.append(translation)
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.is_empty() or row[0] == "":
			continue
		for column in range(1, mini(row.size(), header.size())):
			if row[column] != "":
				result[column - 1].add_message(row[0], row[column].c_unescape())
	return result
