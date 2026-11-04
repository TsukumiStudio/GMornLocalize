extends SceneTree

## 表の読み込み・登録・番号の埋め方・二重登録しないことを保証する。

const TABLE := "user://gmorn_localize_verify.csv"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var file := FileAccess.open(TABLE, FileAccess.WRITE)
	file.store_string('keys,ja,en\nGREETING,こんにちは,Hello\nPRICE,{1}円 → {2}円,{2} yen (was {1})\nMULTILINE,"1行目\\n2行目",\nJA_ONLY,日本語だけ,\n残り{1}機,,{1} lives left\nWALLET,所持金 {1:money}円,\nRATE,倍率 ×{1:.2},\n')
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
	# 表に無い直書きはそのまま出て、番号だけ埋まる。
	assert(service.get_text("残り{1}機", [3]) == "残り3機", "直書きがそのまま出ない: %s" % service.get_text("残り{1}機", [3]))

	# 見せ方は表に書き、呼ぶ側は生の値を渡す。
	assert(service.get_text("WALLET", [777584]) == "所持金 777,584円", "桁区切りにならない: %s" % service.get_text("WALLET", [777584]))
	assert(service.get_text("WALLET", [-1000]) == "所持金 -1,000円", "負の数の桁区切りが崩れる")
	assert(service.get_text("WALLET", [12]) == "所持金 12円", "3桁以下が崩れる")
	assert(service.get_text("RATE", [1.25]) == "倍率 ×1.25", "小数の桁が決まらない: %s" % service.get_text("RATE", [1.25]))
	assert(service.get_text("RATE", [2]) == "倍率 ×2.00", "整数を小数の書式で出せない")

	# 語順の違う訳でも、呼ぶ側の引数の順はそのまま。
	TranslationServer.set_locale("en")
	assert(service.get_text("PRICE", ["30", 36]) == "36 yen (was 30)", "訳の語順で埋まらない: %s" % service.get_text("PRICE", ["30", 36]))
	assert(service.get_text("GREETING") == "Hello", "英語が引けない")
	# 直書きをキーにした行で、後から訳せる。
	assert(service.get_text("残り{1}機", [3]) == "3 lives left", "直書きの文言が訳せない: %s" % service.get_text("残り{1}機", [3]))
	TranslationServer.set_locale("ja")

	# 消えたら登録も外れる。外れないと Editor で読み直すたびに同じ表が積み重なる。
	service.free()
	assert(TranslationServer.translate("GREETING") == "GREETING", "消しても登録が残る")

	var directory := "user://gmorn_localize_tables"
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(directory))
	var first := directory.path_join("a.csv")
	var second := directory.path_join("b.csv")
	file = FileAccess.open(first, FileAccess.WRITE)
	file.store_string("keys,ja,en\nFIRST,最初,First\n")
	file.close()
	file = FileAccess.open(second, FileAccess.WRITE)
	file.store_string("keys,ja,en\nSECOND,次,Second\n")
	file.close()
	ProjectSettings.set_setting("gmorn_localize/table_dir", directory)
	service = load("res://gmorn_localize.gd").new()
	assert(service.get_text("FIRST") == "最初" and service.get_text("SECOND") == "次", "複数の表が登録されない")
	service.free()
	file = FileAccess.open(second, FileAccess.WRITE)
	file.store_string("keys,ja,en\nFIRST,重複,Duplicate\n")
	file.close()
	service = load("res://gmorn_localize.gd").new()
	assert(service.translations.is_empty(), "重複した表が登録された")
	assert(TranslationServer.translate("FIRST") == "FIRST", "不正な表の一部が登録された")
	service.free()
	file = FileAccess.open(second, FileAccess.WRITE)
	file.store_string("keys,ja,en\nBROKEN,列不足\n")
	file.close()
	assert(GMornLocalize.read_directory(directory).is_empty(), "不正な行を含む表が読み込まれた")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(first))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(second))
	assert(GMornLocalize.read_directory(directory).is_empty(), "空のディレクトリが読み込まれた")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TABLE))
	print("GMORN LOCALIZE VERIFY: PASS")
	quit(0)
