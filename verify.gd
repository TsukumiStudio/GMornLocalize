extends SceneTree

## 表の読み込み・登録・番号の埋め方・二重登録しないことを保証する。

const TABLE := "user://gmorn_localize_verify.csv"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var file := FileAccess.open(TABLE, FileAccess.WRITE)
	file.store_string('keys,ja,en\nGREETING,こんにちは,Hello\nPRICE,{1}円 → {2}円,{2} yen (was {1})\nMULTILINE,"1行目\\n2行目",\nJA_ONLY,日本語だけ,\n')
	file.close()
	ProjectSettings.set_setting("gmorn_localize/table_path", TABLE)
	TranslationServer.set_locale("ja")

	var service: Node = load("res://gmorn_localize.gd").new()
	# 呼ぶ側は class_name 越しに static で引く。インスタンスを持たない所からも同じ結果になる。
	assert(GMornLocalize.get_text("GREETING") == "こんにちは", "static で引けない")
	assert(service.translations.size() == 2, "言語の列ごとに作られない: %d" % service.translations.size())
	assert(service.get_text("GREETING") == "こんにちは", "引けない: %s" % service.get_text("GREETING"))
	assert(service.get_text("PRICE", ["30", 36]) == "30円 → 36円", "番号で埋まらない: %s" % service.get_text("PRICE", ["30", 36]))
	assert(service.get_text("MULTILINE") == "1行目\n2行目", "\\n が改行にならない")

	# 語順の違う訳でも、呼ぶ側の引数の順はそのまま。
	TranslationServer.set_locale("en")
	assert(service.get_text("PRICE", ["30", 36]) == "36 yen (was 30)", "訳の語順で埋まらない: %s" % service.get_text("PRICE", ["30", 36]))
	assert(service.get_text("GREETING") == "Hello", "英語が引けない")
	TranslationServer.set_locale("ja")

	# 消えたら登録も外れる。外れないと Editor で読み直すたびに同じ表が積み重なる。
	service.free()
	assert(TranslationServer.translate("GREETING") == "GREETING", "消しても登録が残る")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TABLE))
	print("GMORN LOCALIZE VERIFY: PASS")
	quit(0)
