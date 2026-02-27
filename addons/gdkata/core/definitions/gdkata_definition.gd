@tool
class_name GDKataDefinition
extends Resource

const KATAS_ROOT_PATH: String = "res://addons/gdkata/katas/"
const CATALOG_PATH: String = KATAS_ROOT_PATH + "catalog/"
const WORKSPACE_PATH: String = KATAS_ROOT_PATH + "workspace/"

# Legacy paths are still read for one-time migration.
const LEGACY_TODO_PATH: String = KATAS_ROOT_PATH + "1_todo/"
const LEGACY_IN_PROGRESS_PATH: String = KATAS_ROOT_PATH + "2_in_progress/"
const LEGACY_DONE_PATH: String = KATAS_ROOT_PATH + "3_done/"

const STATUS_TODO := "todo"
const STATUS_IN_PROGRESS := "in_progress"
const STATUS_DONE := "done"

const KATA_CONFIG_FILE: String = "kata.json"

const TEMPLATE_PATH: String = "res://addons/gdkata/core/gdkata_solution_template.txt"
const TEMPLATE_METHOD_NAME_PLACEHOLDER: String = "{{method_name}}"
const TEMPLATE_ARGUMENTS_PLACEHOLDER: String = "{{arguments}}"
const TEMPLATE_EXPECTED_TYPE_PLACEHOLDER: String = "{{expected_type}}"
const TEMPLATE_TITLE_PLACEHOLDER: String = "{{title}}"
const TEMPLATE_DESCRIPTION_PLACEHOLDER: String = "{{description}}"
const TEMPLATE_DEFAULT_RETURN_PLACEHOLDER: String = "{{default_return}}"

const EDITOR_SETTING_EXTERNAL_EXEC: String = "text_editor/external/use_external_editor"
const MAINSCREEN_SCRIPT: String = "Script"
const EDITOR_ICON_SCRIPT: String = "Script"
const EDITOR_ICON_RELOAD: String = "Reload"
const EDITOR_ICON_CATEGORY: String = "EditorIcons"

const DEFAULT_LOCALE := "en"

@export_tool_button("Generate JSON") var generate_json = _generate_json

@export var id: String
@export var status: String = STATUS_TODO
@export var active_script_filename: String = ""
@export var method_name: String
@export var expected_type_hint: Variant.Type
@export var name: String
@export var description: String
@export var hints: String
@export var language: String
@export var difficulty: int = 1
@export var arguments: Array[GDKataArgumentDefinition] = []
@export var tests: Array[GDKataTestDefinition] = []
@export var translations: Dictionary = {}

var source_path: String = ""


static func get_default_return_for_type(type: Variant.Type) -> String:
	match type:
		TYPE_BOOL:
			return "false"
		TYPE_INT:
			return "0"
		TYPE_FLOAT:
			return "0.0"
		TYPE_STRING:
			return '""'
		TYPE_ARRAY:
			return "[]"
		TYPE_DICTIONARY:
			return "{}"
		TYPE_VECTOR2:
			return "Vector2.ZERO"
		TYPE_VECTOR2I:
			return "Vector2i.ZERO"
		TYPE_VECTOR3:
			return "Vector3.ZERO"
		TYPE_VECTOR3I:
			return "Vector3i.ZERO"
		TYPE_VECTOR4:
			return "Vector4.ZERO"
		TYPE_VECTOR4I:
			return "Vector4i.ZERO"
		TYPE_COLOR:
			return "Color.BLACK"
		TYPE_PACKED_BYTE_ARRAY:
			return "PackedByteArray()"
		TYPE_PACKED_INT32_ARRAY:
			return "PackedInt32Array()"
		TYPE_PACKED_INT64_ARRAY:
			return "PackedInt64Array()"
		TYPE_PACKED_FLOAT32_ARRAY:
			return "PackedFloat32Array()"
		TYPE_PACKED_FLOAT64_ARRAY:
			return "PackedFloat64Array()"
		TYPE_PACKED_STRING_ARRAY:
			return "PackedStringArray()"
		TYPE_PACKED_VECTOR2_ARRAY:
			return "PackedVector2Array()"
		TYPE_PACKED_VECTOR3_ARRAY:
			return "PackedVector3Array()"
		TYPE_PACKED_COLOR_ARRAY:
			return "PackedColorArray()"
		_:
			return "null"


static func ensure_catalog_initialized() -> void:
	ensure_directories()
	if _has_catalog_files():
		return
	_migrate_legacy_data()


static func ensure_directories() -> void:
	DirAccess.make_dir_recursive_absolute(CATALOG_PATH)
	DirAccess.make_dir_recursive_absolute(WORKSPACE_PATH)


static func get_catalog_file_path(kata_id: String) -> String:
	return CATALOG_PATH + kata_id + ".json"


static func get_workspace_script_path(script_filename: String) -> String:
	return WORKSPACE_PATH + script_filename


static func get_script_filename(kata_name: String) -> String:
	return kata_name.to_snake_case() + ".gd"


func ensure_active_script_filename() -> String:
	if active_script_filename.is_empty():
		active_script_filename = get_script_filename(get_display_name())
	return active_script_filename


func get_script_path() -> String:
	return get_workspace_script_path(ensure_active_script_filename())


static func has_valid_in_progress() -> bool:
	var kata := load_in_progress()
	if not kata:
		return false
	return FileAccess.file_exists(kata.get_script_path())


static func is_external_editor_configured() -> bool:
	return EditorInterface.get_editor_settings().get_setting(EDITOR_SETTING_EXTERNAL_EXEC)


static func is_valid_status(value: String) -> bool:
	return value in [STATUS_TODO, STATUS_IN_PROGRESS, STATUS_DONE]


static func load_catalog() -> Array[GDKataDefinition]:
	ensure_catalog_initialized()
	var result: Array[GDKataDefinition] = []
	var directory := DirAccess.open(CATALOG_PATH)
	if not directory:
		return result

	var files := directory.get_files()
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".json"):
			continue
		var kata := load_from_file(CATALOG_PATH + file_name)
		if kata:
			result.append(kata)

	if _normalize_in_progress_entries(result):
		for kata in result:
			save_kata(kata)

	var locale := TranslationServer.get_locale()
	for kata in result:
		kata.apply_locale(locale)

	return result


static func load_in_progress() -> GDKataDefinition:
	for kata in load_catalog():
		if kata.status == STATUS_IN_PROGRESS:
			return kata
	return null


static func save_kata(kata: GDKataDefinition) -> void:
	if not kata:
		return
	ensure_directories()
	if kata.id.is_empty():
		kata.id = _derive_id_from_data(kata.method_name, kata.get_display_name())
	if kata.source_path.is_empty():
		kata.source_path = get_catalog_file_path(kata.id)
	var file := FileAccess.open(kata.source_path, FileAccess.WRITE)
	if not file:
		printerr("[GDKata] Could not write Kata: ", kata.source_path)
		return
	file.store_string(JSON.stringify(kata.to_json_data(), "\t"))
	file.close()


static func save_catalog(katas: Array[GDKataDefinition]) -> void:
	for kata in katas:
		save_kata(kata)


static func clear_workspace_result() -> void:
	var result_path := GDKataResultDefinition.get_result_file_path()
	if FileAccess.file_exists(result_path):
		DirAccess.remove_absolute(result_path)


static func delete_workspace_script(script_filename: String) -> void:
	if script_filename.is_empty():
		return
	var path := get_workspace_script_path(script_filename)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var uid_path := path + ".uid"
	if FileAccess.file_exists(uid_path):
		DirAccess.remove_absolute(uid_path)


static func load_from_file(path: String) -> GDKataDefinition:
	var parsed := _read_json_file(path)
	if parsed.is_empty():
		return null
	var kata := from_json_data(parsed)
	if kata:
		kata.source_path = path
	return kata


static func from_json(json: JSON) -> GDKataDefinition:
	if not json:
		return null
	return from_json_data(json.data)


static func from_json_data(raw_data: Variant) -> GDKataDefinition:
	if typeof(raw_data) != TYPE_DICTIONARY:
		return null

	var data: Dictionary = raw_data
	var kata := GDKataDefinition.new()

	kata.method_name = str(data.get("method_name", ""))
	kata.expected_type_hint = int(data.get("expected_type_hint", TYPE_NIL))
	kata.difficulty = int(data.get("difficulty", 1))
	kata.status = str(data.get("status", STATUS_TODO))
	if not is_valid_status(kata.status):
		kata.status = STATUS_TODO

	kata.id = str(data.get("id", "")).strip_edges()
	if kata.id.is_empty():
		kata.id = _derive_id_from_data(kata.method_name, str(data.get("name", "")))

	kata.active_script_filename = str(data.get("active_script_filename", ""))

	kata.arguments.clear()
	for argument_data in _to_array(data.get("arguments", [])):
		if typeof(argument_data) != TYPE_DICTIONARY:
			continue
		var arg := GDKataArgumentDefinition.new()
		arg.name = str(argument_data.get("name", ""))
		arg.type_hint = int(argument_data.get("type_hint", TYPE_NIL))
		kata.arguments.append(arg)

	kata.tests.clear()
	for test_data in _to_array(data.get("tests", [])):
		if typeof(test_data) != TYPE_DICTIONARY:
			continue
		var t := GDKataTestDefinition.new()
		t.expected = test_data.get("expected")
		t.name = str(test_data.get("name", ""))
		t.description = str(test_data.get("description", ""))
		t.arguments = _to_variant_array(test_data.get("arguments", []))
		kata.tests.append(t)

	kata.translations = _build_translations_from_data(data)

	kata.apply_locale(TranslationServer.get_locale())
	return kata


func to_json() -> String:
	return JSON.stringify(to_json_data(), "\t")


func to_json_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"status": status,
		"active_script_filename": active_script_filename,
		"method_name": method_name,
		"expected_type_hint": expected_type_hint,
		"difficulty": difficulty,
		"arguments": [],
		"tests": [],
		"translations": _normalized_translations_for_export(),
	}

	for argument in arguments:
		(
			data["arguments"]
			. append(
				{
					"name": argument.name,
					"type_hint": argument.type_hint,
				}
			)
		)

	var fallback_locale := _get_best_locale_key(DEFAULT_LOCALE)
	for i in range(tests.size()):
		var test := tests[i]
		var localized := _get_localized_test_data(i, fallback_locale)
		(
			data["tests"]
			. append(
				{
					"expected": test.expected,
					"arguments": test.arguments,
					"name": str(localized.get("name", test.name)),
					"description": str(localized.get("description", test.description)),
				}
			)
		)

	return data


func apply_locale(locale: String = "") -> void:
	var use_locale := locale
	if use_locale.is_empty():
		use_locale = TranslationServer.get_locale()
	var locale_key := _get_best_locale_key(use_locale)
	language = locale_key

	var localized := _get_translation(locale_key)
	name = str(localized.get("name", name))
	description = str(localized.get("description", description))
	hints = str(localized.get("hints", hints))

	for i in range(tests.size()):
		var test := tests[i]
		var localized_test := _get_localized_test_data(i, locale_key)
		if localized_test.has("name"):
			test.name = str(localized_test["name"])
		if localized_test.has("description"):
			test.description = str(localized_test["description"])


func get_display_name(locale: String = "") -> String:
	var translated := _get_translation(_get_best_locale_key(locale))
	var display_name := str(translated.get("name", name))
	if display_name.is_empty():
		return id
	return display_name


func get_display_description(locale: String = "") -> String:
	var translated := _get_translation(_get_best_locale_key(locale))
	return str(translated.get("description", description))


func get_display_hints(locale: String = "") -> String:
	var translated := _get_translation(_get_best_locale_key(locale))
	return str(translated.get("hints", hints))


func is_completed_by_result(result: GDKataResultDefinition) -> bool:
	if not result:
		return false
	if result.error:
		return false
	if not result.type_check_passed:
		return false
	if result.failed_count > 0:
		return false
	return true


func _get_translation(locale_key: String) -> Dictionary:
	if translations.has(locale_key):
		var data: Variant = translations[locale_key]
		if typeof(data) == TYPE_DICTIONARY:
			return data
	return {}


func _get_best_locale_key(locale: String) -> String:
	var use_locale := locale
	if use_locale.is_empty():
		use_locale = TranslationServer.get_locale()
	var normalized := _normalize_locale(use_locale)
	if translations.has(normalized):
		return normalized
	var base := normalized.split("_")[0]
	if translations.has(base):
		return base
	if translations.has(DEFAULT_LOCALE):
		return DEFAULT_LOCALE
	for key in translations.keys():
		return str(key)
	return DEFAULT_LOCALE


func _get_localized_test_data(index: int, locale_key: String) -> Dictionary:
	var translated := _get_translation(locale_key)
	var tests_data := _to_array(translated.get("tests", []))
	if index >= 0 and index < tests_data.size() and typeof(tests_data[index]) == TYPE_DICTIONARY:
		return tests_data[index]
	return {}


func _normalized_translations_for_export() -> Dictionary:
	var normalized: Dictionary = {}
	for key_variant in translations.keys():
		var key := _normalize_locale(str(key_variant))
		var value: Variant = translations[key_variant]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = {
			"name": str(value.get("name", "")),
			"description": str(value.get("description", "")),
			"hints": str(value.get("hints", "")),
			"tests": [],
		}
		for test_translation in _to_array(value.get("tests", [])):
			if typeof(test_translation) != TYPE_DICTIONARY:
				continue
			(
				entry["tests"]
				. append(
					{
						"name": str(test_translation.get("name", "")),
						"description": str(test_translation.get("description", "")),
					}
				)
			)
		normalized[key] = entry
	return normalized


func _generate_json() -> void:
	if method_name.is_empty() and name.is_empty():
		printerr("Please define a method name or name before generating the JSON!")
		return

	if id.is_empty():
		id = _derive_id_from_data(method_name, name)

	if translations.is_empty():
		var locale := _normalize_locale(language)
		if locale.is_empty():
			locale = DEFAULT_LOCALE
		translations[locale] = {
			"name": name,
			"description": description,
			"hints": hints,
			"tests": _collect_current_test_translations(),
		}

	source_path = get_catalog_file_path(id)
	save_kata(self)
	EditorInterface.get_resource_filesystem().scan()


func _collect_current_test_translations() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for test in tests:
		(
			output
			. append(
				{
					"name": test.name,
					"description": test.description,
				}
			)
		)
	return output


static func _normalize_locale(locale: String) -> String:
	var value := locale.strip_edges().to_lower()
	if value.is_empty():
		return DEFAULT_LOCALE
	return value


static func _to_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []


static func _to_variant_array(value: Variant) -> Array[Variant]:
	var output: Array[Variant] = []
	for item in _to_array(value):
		output.append(item)
	return output


static func _derive_id_from_data(method: String, title: String) -> String:
	var base := method.strip_edges()
	if base.is_empty():
		base = title.strip_edges()
	if base.is_empty():
		base = "kata"
	return base.to_snake_case()


static func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func _has_catalog_files() -> bool:
	var directory := DirAccess.open(CATALOG_PATH)
	if not directory:
		return false
	for file_name in directory.get_files():
		if file_name.ends_with(".json"):
			return true
	return false


static func _normalize_in_progress_entries(katas: Array[GDKataDefinition]) -> bool:
	var in_progress: Array[GDKataDefinition] = []
	for kata in katas:
		if kata.status == STATUS_IN_PROGRESS:
			in_progress.append(kata)
	if in_progress.size() <= 1:
		return false
	for i in range(1, in_progress.size()):
		in_progress[i].status = STATUS_TODO
	return true


static func _build_translations_from_data(data: Dictionary) -> Dictionary:
	if data.has("translations") and typeof(data["translations"]) == TYPE_DICTIONARY:
		return _normalize_translations(data["translations"])
	return _build_legacy_translation(data)


static func _normalize_translations(raw: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for key_variant in raw.keys():
		var locale := _normalize_locale(str(key_variant))
		var value: Variant = raw[key_variant]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = {
			"name": str(value.get("name", "")),
			"description": str(value.get("description", "")),
			"hints": str(value.get("hints", "")),
			"tests": [],
		}
		for test_translation in _to_array(value.get("tests", [])):
			if typeof(test_translation) != TYPE_DICTIONARY:
				continue
			(
				entry["tests"]
				. append(
					{
						"name": str(test_translation.get("name", "")),
						"description": str(test_translation.get("description", "")),
					}
				)
			)
		output[locale] = entry
	return output


static func _build_legacy_translation(data: Dictionary) -> Dictionary:
	var locale := _normalize_locale(str(data.get("language", DEFAULT_LOCALE)))
	var translation: Dictionary = {
		"name": str(data.get("name", "")),
		"description": str(data.get("description", "")),
		"hints": str(data.get("hints", "")),
		"tests": [],
	}
	for test in _to_array(data.get("tests", [])):
		if typeof(test) != TYPE_DICTIONARY:
			continue
		(
			translation["tests"]
			. append(
				{
					"name": str(test.get("name", "")),
					"description": str(test.get("description", "")),
				}
			)
		)
	return {locale: translation}


static func _migrate_legacy_data() -> void:
	var entries := _collect_legacy_entries()
	if entries.is_empty():
		return

	var grouped: Dictionary = {}
	for entry in entries:
		var legacy_data := _read_json_file(str(entry.get("path", "")))
		if legacy_data.is_empty():
			continue
		var merge_key := _build_legacy_merge_key(legacy_data)
		if not grouped.has(merge_key):
			grouped[merge_key] = _legacy_to_unified_data(
				legacy_data, str(entry.get("status", STATUS_TODO))
			)
		else:
			var existing: Dictionary = grouped[merge_key]
			existing["status"] = _merge_status(
				str(existing.get("status", STATUS_TODO)), str(entry.get("status", STATUS_TODO))
			)
			_merge_translation_into_unified(existing, legacy_data)
			grouped[merge_key] = existing

	var used_ids: Dictionary = {}
	for value in grouped.values():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var unified: Dictionary = value
		var kata_id := _build_unique_id(
			_derive_id_from_data(
				str(unified.get("method_name", "")), _first_translation_name(unified)
			),
			used_ids
		)
		unified["id"] = kata_id
		if not unified.has("active_script_filename"):
			unified["active_script_filename"] = ""
		var file := FileAccess.open(get_catalog_file_path(kata_id), FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(unified, "\t"))
			file.close()

	_copy_legacy_active_script_if_present()


static func _collect_legacy_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_collect_legacy_from_folder(LEGACY_TODO_PATH, STATUS_TODO, result)
	_collect_legacy_from_folder(LEGACY_IN_PROGRESS_PATH, STATUS_IN_PROGRESS, result)
	_collect_legacy_done_entries(result)
	return result


static func _collect_legacy_from_folder(
	folder_path: String, kata_status: String, out: Array[Dictionary]
) -> void:
	var directory := DirAccess.open(folder_path)
	if not directory:
		return
	for file_name in directory.get_files():
		if not file_name.ends_with(".json"):
			continue
		out.append({"path": folder_path + file_name, "status": kata_status})


static func _collect_legacy_done_entries(out: Array[Dictionary]) -> void:
	var directory := DirAccess.open(LEGACY_DONE_PATH)
	if not directory:
		return

	for file_name in directory.get_files():
		if file_name.ends_with(".json"):
			out.append({"path": LEGACY_DONE_PATH + file_name, "status": STATUS_DONE})

	for folder_name in directory.get_directories():
		var path := LEGACY_DONE_PATH + folder_name + "/" + KATA_CONFIG_FILE
		if FileAccess.file_exists(path):
			out.append({"path": path, "status": STATUS_DONE})


static func _build_legacy_merge_key(data: Dictionary) -> String:
	var tests_signature: Array = []
	for test in _to_array(data.get("tests", [])):
		if typeof(test) != TYPE_DICTIONARY:
			continue
		(
			tests_signature
			. append(
				{
					"expected": test.get("expected"),
					"arguments": _to_array(test.get("arguments", [])),
				}
			)
		)

	var key_data: Dictionary = {
		"method_name": str(data.get("method_name", "")),
		"expected_type_hint": int(data.get("expected_type_hint", TYPE_NIL)),
		"difficulty": int(data.get("difficulty", 1)),
		"arguments": _to_array(data.get("arguments", [])),
		"tests": tests_signature,
	}
	return JSON.stringify(key_data)


static func _legacy_to_unified_data(data: Dictionary, kata_status: String) -> Dictionary:
	var unified: Dictionary = {
		"id": "",
		"status": kata_status,
		"active_script_filename": "",
		"method_name": str(data.get("method_name", "")),
		"expected_type_hint": int(data.get("expected_type_hint", TYPE_NIL)),
		"difficulty": int(data.get("difficulty", 1)),
		"arguments": _to_array(data.get("arguments", [])),
		"tests": [],
		"translations": {},
	}

	for test in _to_array(data.get("tests", [])):
		if typeof(test) != TYPE_DICTIONARY:
			continue
		(
			unified["tests"]
			. append(
				{
					"expected": test.get("expected"),
					"arguments": _to_array(test.get("arguments", [])),
					"name": str(test.get("name", "")),
					"description": str(test.get("description", "")),
				}
			)
		)

	_merge_translation_into_unified(unified, data)
	return unified


static func _merge_translation_into_unified(unified: Dictionary, data: Dictionary) -> void:
	var locale := _normalize_locale(str(data.get("language", DEFAULT_LOCALE)))
	var translation: Dictionary = {
		"name": str(data.get("name", "")),
		"description": str(data.get("description", "")),
		"hints": str(data.get("hints", "")),
		"tests": [],
	}

	for test in _to_array(data.get("tests", [])):
		if typeof(test) != TYPE_DICTIONARY:
			continue
		(
			translation["tests"]
			. append(
				{
					"name": str(test.get("name", "")),
					"description": str(test.get("description", "")),
				}
			)
		)

	var translations_dict: Dictionary = unified.get("translations", {})
	translations_dict[locale] = translation
	unified["translations"] = translations_dict


static func _merge_status(current_status: String, incoming_status: String) -> String:
	if current_status == STATUS_IN_PROGRESS or incoming_status == STATUS_IN_PROGRESS:
		return STATUS_IN_PROGRESS
	if current_status == STATUS_DONE or incoming_status == STATUS_DONE:
		return STATUS_DONE
	return STATUS_TODO


static func _first_translation_name(unified: Dictionary) -> String:
	var raw_translations: Variant = unified.get("translations", {})
	if typeof(raw_translations) != TYPE_DICTIONARY:
		return ""
	var translations_dict: Dictionary = raw_translations
	for locale in translations_dict.keys():
		var entry: Variant = translations_dict[locale]
		if typeof(entry) == TYPE_DICTIONARY:
			return str(entry.get("name", ""))
	return ""


static func _build_unique_id(base_id: String, used: Dictionary) -> String:
	var normalized := base_id
	if normalized.is_empty():
		normalized = "kata"
	if not used.has(normalized):
		used[normalized] = true
		return normalized

	var suffix := 2
	while true:
		var candidate := "%s_%d" % [normalized, suffix]
		if not used.has(candidate):
			used[candidate] = true
			return candidate
		suffix += 1
	return normalized


static func _copy_legacy_active_script_if_present() -> void:
	var directory := DirAccess.open(LEGACY_IN_PROGRESS_PATH)
	if not directory:
		return
	for file_name in directory.get_files():
		if not file_name.ends_with(".gd"):
			continue
		var source := LEGACY_IN_PROGRESS_PATH + file_name
		var target := WORKSPACE_PATH + file_name
		if FileAccess.file_exists(source):
			if FileAccess.file_exists(target):
				DirAccess.remove_absolute(target)
			DirAccess.copy_absolute(source, target)
			return
