@tool
class_name GDKataSelector
extends PanelContainer

const CONFIG_SECTION := "selector"

signal kata_started(kata: GDKataDefinition)

@export var dropdown_language: OptionButton
@export var dropdown_difficulty: OptionButton
@export var dropdown_katas: OptionButton
@export var label_description: Label
@export var label_in_progress: Label
@export var button_run: Button
@export var button_refresh: Button
@export var background_panel: PanelContainer

static var instance: GDKataSelector

var _all_katas: Array[GDKataDefinition] = []
var _filtered_katas: Array[GDKataDefinition] = []
var _selected_kata: GDKataDefinition
var _available_languages: Array[String] = []
var _available_difficulties: Array[int] = []


func _ready() -> void:
	button_refresh.icon = EditorInterface.get_editor_theme().get_icon(
		GDKataDefinition.EDITOR_ICON_RELOAD, GDKataDefinition.EDITOR_ICON_CATEGORY
	)
	dropdown_language.item_selected.connect(_on_filter_changed)
	dropdown_difficulty.item_selected.connect(_on_filter_changed)
	dropdown_katas.item_selected.connect(_on_item_selected)
	button_run.pressed.connect(_on_run)
	button_refresh.pressed.connect(_on_refresh)
	button_run.text = GDKataTr.translate("SELECTOR_BUTTON_START_KATA")
	label_in_progress.text = GDKataTr.translate("SELECTOR_LABEL_IN_PROGRESS")
	_load()


func _enter_tree() -> void:
	if not instance:
		instance = self


func _exit_tree() -> void:
	if instance:
		instance = null


func on_kata_finished() -> void:
	_load()


func set_highlight(active: bool) -> void:
	var style := StyleBoxFlat.new()
	if active:
		style.bg_color = GDKataTheme.get_base_color_active()
	else:
		style.bg_color = GDKataTheme.get_base_color()
	add_theme_stylebox_override("panel", style)


func _load() -> void:
	label_description.text = ""
	_load_katas()
	_init_filter_dropdowns()
	_load_config()
	_apply_filters()
	_update_state()


func _load_katas() -> void:
	_all_katas.clear()
	_available_languages.clear()
	_available_difficulties.clear()
	var directory := DirAccess.open(GDKataDefinition.TODO_PATH)
	if not directory:
		return
	for file: String in directory.get_files():
		var resource: Resource = load(GDKataDefinition.TODO_PATH + file)
		if resource:
			var kata := GDKataDefinition.from_json(resource)
			_all_katas.append(kata)
			if kata.language and kata.language not in _available_languages:
				_available_languages.append(kata.language)
			if kata.difficulty not in _available_difficulties:
				_available_difficulties.append(kata.difficulty)
	_available_languages.sort()
	_available_difficulties.sort()


func _init_filter_dropdowns() -> void:
	dropdown_language.clear()
	dropdown_language.add_item(GDKataTr.translate("SELECTOR_FILTER_ALL_LANGUAGES"))
	for lang: String in _available_languages:
		dropdown_language.add_item(lang)

	dropdown_difficulty.clear()
	dropdown_difficulty.add_item(GDKataTr.translate("SELECTOR_FILTER_ALL_DIFFICULTIES"))
	for diff: int in _available_difficulties:
		dropdown_difficulty.add_item(str(diff))


func _apply_filters() -> void:
	_filtered_katas.clear()
	var selected_lang_idx := dropdown_language.selected
	var selected_diff_idx := dropdown_difficulty.selected

	var filter_language: String = ""
	if selected_lang_idx > 0:
		filter_language = _available_languages[selected_lang_idx - 1]

	var filter_difficulty: int = -1
	if selected_diff_idx > 0:
		filter_difficulty = _available_difficulties[selected_diff_idx - 1]

	for kata: GDKataDefinition in _all_katas:
		var lang_match := filter_language.is_empty() or kata.language == filter_language
		var diff_match := filter_difficulty < 0 or kata.difficulty == filter_difficulty
		if lang_match and diff_match:
			_filtered_katas.append(kata)

	_init_kata_dropdown()


func _init_kata_dropdown() -> void:
	dropdown_katas.clear()
	_selected_kata = null
	if _filtered_katas.is_empty():
		return
	for kata: GDKataDefinition in _filtered_katas:
		dropdown_katas.add_item(kata.name)
	_selected_kata = _filtered_katas[0]
	_on_item_selected(0)


func _update_state() -> void:
	var enabled := not GDKataDefinition.has_valid_in_progress()
	dropdown_language.disabled = not enabled
	dropdown_difficulty.disabled = not enabled
	dropdown_katas.disabled = not enabled
	button_run.disabled = not enabled
	label_in_progress.visible = not enabled
	if not enabled:
		label_description.text = ""


func _move_selected_kata() -> void:
	var source := "%s%s.json" % [GDKataDefinition.TODO_PATH, _selected_kata.name]
	var dest := GDKataDefinition.get_config_path()
	var err := DirAccess.rename_absolute(source, dest)
	if err != OK:
		printerr("Failed to move Kata to In Progress")
	EditorInterface.get_resource_filesystem().scan()


func _create_template_script() -> void:
	var dest := _selected_kata.get_script_path()
	var template_file := FileAccess.open(GDKataDefinition.TEMPLATE_PATH, FileAccess.READ)

	var template := template_file.get_as_text()
	template_file.close()
	template = template.replace(
		GDKataDefinition.TEMPLATE_METHOD_NAME_PLACEHOLDER, _selected_kata.method_name
	)
	template = template.replace(
		GDKataDefinition.TEMPLATE_EXPECTED_TYPE_PLACEHOLDER,
		type_string(_selected_kata.expected_type_hint)
	)
	template = template.replace(
		GDKataDefinition.TEMPLATE_ARGUMENTS_PLACEHOLDER, _build_arguments_string()
	)
	template = template.replace(GDKataDefinition.TEMPLATE_TITLE_PLACEHOLDER, _selected_kata.name)
	template = template.replace(
		GDKataDefinition.TEMPLATE_DESCRIPTION_PLACEHOLDER, _selected_kata.description
	)

	var dest_file := FileAccess.open(dest, FileAccess.WRITE)
	dest_file.store_string(template)
	dest_file.close()

	EditorInterface.get_resource_filesystem().scan()


func _build_arguments_string() -> String:
	var parts: PackedStringArray = []
	for i in range(_selected_kata.arguments.size()):
		var letter := (
			_selected_kata.arguments[i].name
			if not _selected_kata.arguments[i].name.is_empty()
			else char(ord("a") + i)
		)
		var type := type_string(_selected_kata.arguments[i].type_hint)
		parts.append("%s: %s" % [letter, type])
	return ", ".join(parts)


func _on_filter_changed(_index: int) -> void:
	_apply_filters()
	_save_config()


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _filtered_katas.size():
		return
	_selected_kata = _filtered_katas[index]
	label_description.text = _selected_kata.description


func _on_run() -> void:
	if not _selected_kata:
		return
	_move_selected_kata()
	_create_template_script()
	_update_state()
	kata_started.emit(_selected_kata)


func _on_refresh() -> void:
	_load()


func _save_config() -> void:
	var config := ConfigFile.new()
	config.load(GDKata.CONFIG_PATH)
	_save_config_language(config)
	_save_config_difficulty(config)
	config.save(GDKata.CONFIG_PATH)


func _save_config_language(config: ConfigFile) -> void:
	var language_text := (
		dropdown_language.get_item_text(dropdown_language.selected)
		if dropdown_language.selected >= 0
		else ""
	)
	config.set_value(CONFIG_SECTION, "language", language_text)


func _save_config_difficulty(config: ConfigFile) -> void:
	var difficulty_text := (
		dropdown_difficulty.get_item_text(dropdown_difficulty.selected)
		if dropdown_difficulty.selected >= 0
		else ""
	)
	config.set_value(CONFIG_SECTION, "difficulty", difficulty_text)


func _load_config() -> void:
	var config := ConfigFile.new()
	if config.load(GDKata.CONFIG_PATH) != OK:
		return
	_load_config_language(config)
	_load_config_difficulty(config)


func _load_config_language(config: ConfigFile) -> void:
	var language_text: String = config.get_value(CONFIG_SECTION, "language", "")

	for i in range(dropdown_language.item_count):
		if dropdown_language.get_item_text(i) == language_text:
			dropdown_language.select(i)
			break


func _load_config_difficulty(config: ConfigFile) -> void:
	var difficulty_text: String = config.get_value(CONFIG_SECTION, "difficulty", "")

	for i in range(dropdown_difficulty.item_count):
		if dropdown_difficulty.get_item_text(i) == difficulty_text:
			dropdown_difficulty.select(i)
			break
