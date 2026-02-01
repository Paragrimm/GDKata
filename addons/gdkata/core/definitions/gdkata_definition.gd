@tool
class_name GDKataDefinition
extends Resource

const TODO_PATH: String = "res://addons/gdkata/katas/1_todo/"
const IN_PROGRESS_PATH: String = "res://addons/gdkata/katas/2_in_progress/"
const DONE_PATH: String = "res://addons/gdkata/katas/3_done/"

const KATA_CONFIG_FILE: String = "kata.json"

const TEMPLATE_PATH: String = "res://addons/gdkata/core/gdkata_solution_template.txt"
const TEMPLATE_METHOD_NAME_PLACEHOLDER: String = "{{method_name}}"
const TEMPLATE_ARGUMENTS_PLACEHOLDER: String = "{{arguments}}"
const TEMPLATE_EXPECTED_TYPE_PLACEHOLDER: String = "{{expected_type}}"
const TEMPLATE_TITLE_PLACEHOLDER: String = "{{title}}"
const TEMPLATE_DESCRIPTION_PLACEHOLDER: String = "{{description}}"

const EDITOR_SETTING_EXTERNAL_EXEC: String = "text_editor/external/use_external_editor"
const MAINSCREEN_NAME: String = "Kata"
const MAINSCREEN_SCRIPT: String = "Script"
const EDITOR_ICON_SCRIPT: String = "Script"
const EDITOR_ICON_RELOAD: String = "Reload"
const EDITOR_ICON_CATEGORY: String = "EditorIcons"

@export_tool_button("Generate JSON") var generate_json = _generate_json

@export var method_name: String
@export var expected_type_hint: Variant.Type
@export var name: String
@export var description: String
@export var hints: String
@export var language: String
@export var difficulty: int = 1
@export var arguments: Array[GDKataArgumentDefinition] = []
@export var tests: Array[GDKataTestDefinition] = []


static func get_config_path() -> String:
	DirAccess.make_dir_recursive_absolute(IN_PROGRESS_PATH)
	return IN_PROGRESS_PATH + KATA_CONFIG_FILE


static func get_script_filename(kata_name: String) -> String:
	return kata_name.to_snake_case() + ".gd"


static func get_script_path_for(kata_name: String) -> String:
	return IN_PROGRESS_PATH + get_script_filename(kata_name)


func get_script_path() -> String:
	return get_script_path_for(name)


static func has_valid_in_progress() -> bool:
	if not FileAccess.file_exists(get_config_path()):
		return false
	var kata := load_in_progress()
	if not kata:
		return false
	return FileAccess.file_exists(get_script_path_for(kata.name))


static func is_external_editor_configured() -> bool:
	return EditorInterface.get_editor_settings().get_setting(EDITOR_SETTING_EXTERNAL_EXEC)


static func from_json(json: JSON) -> GDKataDefinition:
	if not json:
		return null
	var kata := GDKataDefinition.new()
	kata.method_name = json.data["method_name"]
	kata.expected_type_hint = json.data["expected_type_hint"]
	kata.name = json.data["name"]
	kata.description = json.data["description"]
	kata.hints = json.data.get("hints", "")
	kata.language = json.data.get("language", "")
	kata.difficulty = json.data.get("difficulty", 1)
	kata.arguments = []
	for argument in json.data["arguments"]:
		var arg := GDKataArgumentDefinition.new()
		arg.name = argument["name"]
		arg.type_hint = argument["type_hint"]
		kata.arguments.append(arg)

	kata.tests = []
	for test in json.data["tests"]:
		var t := GDKataTestDefinition.new()
		t.expected = test["expected"]
		t.name = test["name"]
		t.description = test["description"]
		t.arguments = test["arguments"]
		kata.tests.append(t)

	return kata


static func load_in_progress() -> GDKataDefinition:
	var json_text := FileAccess.get_file_as_string(get_config_path())
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return null
	return from_json(json)


func to_json() -> String:
	var data: Variant = {
		"method_name": method_name,
		"expected_type_hint": expected_type_hint,
		"name": name,
		"description": description,
		"hints": hints,
		"language": language,
		"difficulty": difficulty,
		"arguments": [],
		"tests": [],
	}
	for argument: GDKataArgumentDefinition in arguments:
		(
			data["arguments"]
			. append(
				{
					"name": argument.name,
					"type_hint": argument.type_hint,
				}
			)
		)

	for test: GDKataTestDefinition in tests:
		(
			data["tests"]
			. append(
				{
					"expected": test.expected,
					"name": test.name,
					"description": test.description,
					"arguments": test.arguments,
				}
			)
		)
	return JSON.stringify(data)


func _generate_json() -> void:
	if name.is_empty():
		printerr("Please define a name before generating the JSON!")
		return
	var file := FileAccess.open(TODO_PATH + name + ".json", FileAccess.WRITE)
	file.store_string(to_json())
	file.close()
	EditorInterface.get_resource_filesystem().scan()
