@tool
class_name GDKataSelector
extends PanelContainer

const CONFIG_SECTION := "selector"

signal kata_start_requested(kata_id: String)
signal refresh_requested

@export var dropdown_difficulty: OptionButton
@export var dropdown_katas: OptionButton
@export var checkbox_show_completed: CheckButton
@export var label_description: Label
@export var button_toggle_hints: Button
@export var hints_container: VBoxContainer
@export var label_hints: Label
@export var label_hints_header: Label
@export var label_in_progress: Label
@export var button_run: Button
@export var button_refresh: Button
@export var background_panel: PanelContainer

static var instance: GDKataSelector

var _all_katas: Array[GDKataDefinition] = []
var _filtered_katas: Array[GDKataDefinition] = []
var _selected_kata: GDKataDefinition
var _available_difficulties: Array[int] = []
var _active_kata_id: String = ""
var _difficulty_filter: int = -1
var _hints_expanded := false


func _ready() -> void:
	button_refresh.icon = EditorInterface.get_editor_theme().get_icon(
		GDKataDefinition.EDITOR_ICON_RELOAD, GDKataDefinition.EDITOR_ICON_CATEGORY
	)
	dropdown_difficulty.item_selected.connect(_on_difficulty_filter_changed)
	dropdown_katas.item_selected.connect(_on_item_selected)
	checkbox_show_completed.toggled.connect(_on_show_completed_toggled)
	button_toggle_hints.pressed.connect(_on_toggle_hints_pressed)
	button_run.pressed.connect(_on_run)
	button_refresh.pressed.connect(_on_refresh)
	button_run.text = GDKataTr.translate("SELECTOR_BUTTON_START_KATA")
	label_in_progress.text = GDKataTr.translate("SELECTOR_LABEL_IN_PROGRESS")
	checkbox_show_completed.text = GDKataTr.translate("SELECTOR_FILTER_SHOW_COMPLETED")
	label_hints_header.text = GDKataTr.translate("MAINSCREEN_LABEL_HINTS")
	_set_hints_expanded(false)
	reload_data()


func _enter_tree() -> void:
	if not instance:
		instance = self


func _exit_tree() -> void:
	if instance:
		instance = null


func set_active_kata_id(value: String) -> void:
	_active_kata_id = value
	_update_state()


func reload_data(preferred_kata_id: String = "") -> void:
	label_description.text = ""
	label_hints.text = ""
	_set_hints_expanded(false)
	_load_katas()
	_init_filter_dropdowns()
	_load_config()
	_apply_filters(preferred_kata_id)
	_update_state()


func set_highlight(active: bool) -> void:
	var style := StyleBoxFlat.new()
	if active:
		style.bg_color = GDKataTheme.get_base_color_active()
	else:
		style.bg_color = GDKataTheme.get_base_color()
	add_theme_stylebox_override("panel", style)


func _load_katas() -> void:
	_all_katas = GDKataDefinition.load_catalog()
	_available_difficulties.clear()

	for kata in _all_katas:
		if kata.difficulty not in _available_difficulties:
			_available_difficulties.append(kata.difficulty)

	_available_difficulties.sort()


func _init_filter_dropdowns() -> void:
	dropdown_difficulty.clear()
	dropdown_difficulty.add_item(GDKataTr.translate("SELECTOR_FILTER_ALL_DIFFICULTIES"))
	dropdown_difficulty.set_item_metadata(0, -1)
	for difficulty in _available_difficulties:
		dropdown_difficulty.add_item(str(difficulty))
		dropdown_difficulty.set_item_metadata(dropdown_difficulty.item_count - 1, difficulty)


func _apply_filters(preferred_kata_id: String = "") -> void:
	_filtered_katas.clear()
	var include_done := checkbox_show_completed.button_pressed

	for kata in _all_katas:
		var difficulty_match := _difficulty_filter < 0 or kata.difficulty == _difficulty_filter
		var status_match := include_done or kata.status != GDKataDefinition.STATUS_DONE
		if difficulty_match and status_match:
			_filtered_katas.append(kata)

	_filtered_katas.sort_custom(_sort_by_name)
	_init_kata_dropdown(preferred_kata_id)


func _sort_by_name(a: GDKataDefinition, b: GDKataDefinition) -> bool:
	return a.get_display_name().nocasecmp_to(b.get_display_name()) < 0


func _init_kata_dropdown(preferred_kata_id: String) -> void:
	dropdown_katas.clear()
	_selected_kata = null
	_set_hints_expanded(false)

	if _filtered_katas.is_empty():
		return

	for kata in _filtered_katas:
		dropdown_katas.add_item(_build_kata_dropdown_label(kata))

	var preferred_id := preferred_kata_id
	if preferred_id.is_empty() and not _active_kata_id.is_empty():
		preferred_id = _active_kata_id

	var target_index := _find_filtered_index_by_id(preferred_id)
	if target_index < 0:
		target_index = 0

	dropdown_katas.select(target_index)
	_on_item_selected(target_index)


func _build_kata_dropdown_label(kata: GDKataDefinition) -> String:
	var label := kata.get_display_name()
	if kata.status == GDKataDefinition.STATUS_DONE:
		return "%s ✓" % label
	if kata.status == GDKataDefinition.STATUS_IN_PROGRESS:
		return "%s •" % label
	return label


func _find_filtered_index_by_id(kata_id: String) -> int:
	if kata_id.is_empty():
		return -1
	for i in range(_filtered_katas.size()):
		if _filtered_katas[i].id == kata_id:
			return i
	return -1


func _update_state() -> void:
	var enabled := _active_kata_id.is_empty()
	dropdown_difficulty.disabled = not enabled
	dropdown_katas.disabled = not enabled
	checkbox_show_completed.disabled = not enabled
	button_toggle_hints.disabled = _selected_kata == null
	button_run.disabled = not enabled or _selected_kata == null
	label_in_progress.visible = not enabled

	if not enabled:
		var active_index := _find_filtered_index_by_id(_active_kata_id)
		if active_index >= 0:
			dropdown_katas.select(active_index)
			_on_item_selected(active_index)


func _on_difficulty_filter_changed(index: int) -> void:
	_difficulty_filter = _difficulty_from_index(index)
	_apply_filters(_selected_kata.id if _selected_kata else "")
	_save_config()


func _on_show_completed_toggled(_toggled: bool) -> void:
	_apply_filters(_selected_kata.id if _selected_kata else "")
	_save_config()


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _filtered_katas.size():
		return
	_selected_kata = _filtered_katas[index]
	label_description.text = _selected_kata.get_display_description()
	label_hints.text = _selected_kata.get_display_hints()
	_set_hints_expanded(false)


func _on_toggle_hints_pressed() -> void:
	_set_hints_expanded(not _hints_expanded)


func _on_run() -> void:
	if not _selected_kata:
		return
	kata_start_requested.emit(_selected_kata.id)


func _on_refresh() -> void:
	refresh_requested.emit()


func _save_config() -> void:
	var config := ConfigFile.new()
	config.load(GDKata.CONFIG_PATH)
	config.set_value(CONFIG_SECTION, "difficulty", str(_difficulty_filter))
	config.set_value(CONFIG_SECTION, "show_completed", checkbox_show_completed.button_pressed)
	config.save(GDKata.CONFIG_PATH)


func _load_config() -> void:
	var config := ConfigFile.new()
	if config.load(GDKata.CONFIG_PATH) != OK:
		return

	var difficulty_filter := _normalize_difficulty_filter_value(
		config.get_value(CONFIG_SECTION, "difficulty", -1)
	)
	_difficulty_filter = difficulty_filter
	for i in range(dropdown_difficulty.item_count):
		if _difficulty_from_index(i) == difficulty_filter:
			dropdown_difficulty.select(i)
			break

	checkbox_show_completed.button_pressed = bool(
		config.get_value(CONFIG_SECTION, "show_completed", false)
	)


func _difficulty_from_index(index: int) -> int:
	if index < 0 or index >= dropdown_difficulty.item_count:
		return -1
	var value: Variant = dropdown_difficulty.get_item_metadata(index)
	if typeof(value) == TYPE_INT:
		return int(value)
	return -1


func _normalize_difficulty_filter_value(raw_value: Variant) -> int:
	if typeof(raw_value) == TYPE_INT:
		return int(raw_value)
	if typeof(raw_value) == TYPE_STRING:
		var text := str(raw_value).strip_edges()
		if text.is_valid_int():
			return int(text)
	return -1


func _set_hints_expanded(expanded: bool) -> void:
	_hints_expanded = expanded and _selected_kata != null
	button_toggle_hints.disabled = _selected_kata == null
	hints_container.visible = _hints_expanded
	var key := "MAINSCREEN_BUTTON_HIDE_HINTS" if _hints_expanded else "MAINSCREEN_BUTTON_SHOW_HINTS"
	button_toggle_hints.text = GDKataTr.translate(key)
