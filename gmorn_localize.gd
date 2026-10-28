@tool
extends Node

## 画面に出す文言の取得口。文言は1枚のCSV（`keys,ja,en,…`）にIDのキーで集め、起動時に読んで
## 列ごとの言語の翻訳として `TranslationServer` へ登録する。
## Godot の CSV 取り込みは使わない。生成物の `.translation` が git に入り、マージで表と食い違ったまま残るため。
## `@tool` なのは Editor の Preview Translation にも同じ表を効かせるため。
## 呼ぶ側は `GMornLocalize.get_text("KEY", [値…])` だけを使う。`tr()` と `TranslationServer.translate()` を
## 混ぜると、Node と static 関数で呼び方が割れる。

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
## 小数は桁を決めた String にして渡す（`"%.2f" % x`）。float をそのまま渡すと桁が値で揺れるので受けない。
func get_text(key: String, args: Array = []) -> String:
	var text := String(TranslationServer.translate(key))
	for index in args.size():
		var value: Variant = args[index]
		if value is float:
			push_error("%s の {%d} に float が来た。桁を決めた String にして渡す: %s" % [key, index + 1, value])
		text = text.replace("{%d}" % (index + 1), str(value))
	return text

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
