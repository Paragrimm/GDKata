@tool
class_name GDKataTr
extends RefCounted

# --- i18n workaround for EditorPlugins ----------------------------------
# Godot's TranslationServer.translate() and Node.tr() do not work reliably
# inside @tool EditorPlugin scripts. Even when Translation objects are
# correctly added via TranslationServer.add_translation(), the translate()
# method returns the raw key instead of the translated string.
#
# This class provides a self-contained workaround: it parses the CSV file
# directly, builds plain Translation objects, and performs the lookup via
# Translation.get_message() — bypassing TranslationServer entirely.
# ------------------------------------------------------------------------

const _CSV_PATH := "res://addons/gdkata/i18n.csv"

static var _translations: Array[Translation] = []
static var _initialized: bool = false


static func setup() -> void:
	if _initialized:
		return
	_translations = _parse_csv(_CSV_PATH)
	_initialized = true


static func teardown() -> void:
	_translations.clear()
	_initialized = false


static func translate(key: String) -> String:
	var locale := TranslationServer.get_locale()
	# Try exact match first, then base language (e.g. "de" from "de_DE")
	for t in _translations:
		if t.locale == locale:
			var msg := t.get_message(key)
			if not msg.is_empty():
				return msg
	var base_locale := locale.split("_")[0]
	if base_locale != locale:
		for t in _translations:
			if t.locale == base_locale:
				var msg := t.get_message(key)
				if not msg.is_empty():
					return msg
	# Fallback: return first available translation (typically "en")
	if not _translations.is_empty():
		var msg := _translations[0].get_message(key)
		if not msg.is_empty():
			return msg
	return key


static func _parse_csv(csv_path: String) -> Array[Translation]:
	var result: Array[Translation] = []
	var file := FileAccess.open(csv_path, FileAccess.READ)
	if not file:
		printerr("[GDKata i18n] Could not open CSV: ", csv_path)
		return result

	var header := file.get_csv_line()
	if header.size() < 2:
		printerr("[GDKata i18n] Invalid CSV header in: ", csv_path)
		return result

	# header[0] = "keys", header[1..n] = locale codes (e.g. "en", "de")
	for i in range(1, header.size()):
		var t := Translation.new()
		t.locale = header[i]
		result.append(t)

	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2 or row[0].is_empty():
			continue
		var key := row[0]
		for i in range(1, mini(row.size(), result.size() + 1)):
			result[i - 1].add_message(key, row[i])

	file.close()
	return result
