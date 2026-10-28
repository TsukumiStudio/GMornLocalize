@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GMornLocalize"
const SETTINGS := preload("gmorn_localize.gd")

## 置き場所を決め打ちにしない。submodule で任意の場所へ入れられるよう自分の居場所から辿る。
func _autoload_path() -> String:
	return get_script().resource_path.get_base_dir().path_join("gmorn_localize.gd")

func _enter_tree() -> void:
	_register_settings()
	# 登録済みなら足さない。毎回足すとエディタ起動ごとに「自動読み込みを追加」の履歴が並ぶ。
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, _autoload_path())

func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)

## 既定値を登録しないと「プロジェクト設定」で戻す印が付き、どれを変えたか分からない。
## 値は読む側の既定値と同じにする。読む側はこの登録が無くても動く。
func _register_settings() -> void:
	var key: String = SETTINGS.TABLE_PATH_SETTING
	if not ProjectSettings.has_setting(key):
		ProjectSettings.set_setting(key, SETTINGS.DEFAULT_TABLE_PATH)
	ProjectSettings.set_initial_value(key, SETTINGS.DEFAULT_TABLE_PATH)
	ProjectSettings.add_property_info({
		"name": key, "type": TYPE_STRING, "hint": PROPERTY_HINT_FILE, "hint_string": "*.csv",
	})
	ProjectSettings.set_as_basic(key, true)
