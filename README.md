# GMornLocalize

## 概要

画面に出す文言を1枚のCSVに集め、起動時に読んで翻訳として登録するGodotアドオン。呼ぶ側は `GMornLocalize.get_text("KEY", [値…])` だけを使う。

Godot の CSV 取り込みは使わない。取り込みの生成物 `.translation` は git に入り、マージで表と食い違ったまま残ると、表は正しいのに画面だけ古い文言が出る。

## 動作環境

- Godot 4.x（4.7で確認）

## 何ができるか

- **表は1枚**。`keys,ja,en,…` の列を足せば、その言語の翻訳も作られる。
- **生成物が無い**。CSV を直せば、取り込み直さなくても次の起動から反映される。
- **番号で埋める**。表に `{1}` `{2}` と書き、引数を順に渡す。訳で語順が変わっても呼ぶ側は変えない。
- **見せ方は表に書く**。`{1:money}` で3桁区切り、`{1:.2}` で小数2桁。呼ぶ側は生の値を渡す。
- **キーでも直書きでも書ける**。表に無い文字列はそのまま出て、番号だけ埋まる。直書きした文言は、表にその文言そのものをキーにした行（`こんにちは,,Hello`）を足せば後から訳せる。
- **シーンはそのまま**。Label の `text` にキー（または文言）を書けば、Control の自動翻訳で表示される。
- **Editor でも効く**。自動読み込みが `@tool` なので、Preview Translation に同じ表が出る。

## 使い方

### 1. 取り込む

```
git submodule add https://github.com/TsukumiStudio/GMornLocalize.git addons/gmorn_localize
```

「プロジェクト設定 → プラグイン」で `GMornLocalize` を有効にする。自動読み込みへ `GMornLocalizeTable`（表を登録する役）が登録される。

呼ぶときの `GMornLocalize` は `class_name`。const の表や static 関数、`--script` で先に読まれる台本からも引けるようにするため。`class_name` はエディタか `--import` が一度走査すると解決できるので、CI では起動の前に `--import` を回す。

**リポジトリ直下に `project.godot` は置かない。** 置くとGodotがそこを別のプロジェクトと見なし、取り込んだ側の書き出しからフォルダごと外れる。

### 2. 表を置く

```
keys,ja,en
TITLE_START,はじめる,Start
HUD_LIVES,残り{1}機,{1} lives left
SHOP_PRICE,{1:money}円,¥{1:money}
HUD_RATE,倍率 ×{1:.2},Rate ×{1:.2}
RESULT_TIME,{1}分{2}秒,{1}m {2}s
```

- 置き場所はプロジェクト設定 `gmorn_localize/table_path`（既定 `res://localization.csv`）。
- 表の取り込み設定を **Keep File** にする（`.import` の `importer="keep"`）。翻訳として取り込まれると `FileAccess` で読めない。
- 書き出し設定の「リソース以外のファイル」（`include_filter`）に表を足す。足さないと配布物に入らない。
- `internationalization/locale/fallback` を元の言語にしておくと、訳の無い言語でもキーではなく元の文言が出る。

### 3. 引く

```gdscript
label.text = GMornLocalize.get_text("TITLE_START")
label.text = GMornLocalize.get_text("HUD_LIVES", [lives])
label.text = GMornLocalize.get_text("RESULT_TIME", [minutes, "%02d" % seconds])
```

- 値は生のまま渡す。`get_text("SHOP_PRICE", [1500])` → `1,500円`、`get_text("HUD_RATE", [1.25])` → `倍率 ×1.25`。
- 書式は `money`（整数を3桁区切り）と `.N`（小数N桁）。書式の無い `{1}` に float を渡すとエラー（桁が値で揺れるため）。
- 表に無い文字列はそのまま出る。`GMornLocalize.get_text("残り{1}機", [lives])` のように直書きしてもよい。
- 直書きした文言を訳すときは、表にその文言をキーにした行を足す。元の言語の列は空でよい。空の欄は `internationalization/locale/fallback` の言語を引き、そこも空ならキーそのものが出るので、fallback を元の言語にしておく。

```
keys,ja,en
残り{1}機,,{1} lives left
```

- シーンでは Label の `text` にキー（`TITLE_START`）か文言をそのまま書く。

### 4. 確かめる

```
./verify.sh
```

## ライセンス

[UNLICENSE](UNLICENSE)
