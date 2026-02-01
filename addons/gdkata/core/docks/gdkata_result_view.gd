@tool
class_name GDKataResultView
extends PanelContainer

signal kata_submitted(kata: GDKataDefinition)

@export var label_message: Label
@export var label_header: Label
@export var row_type_check: GDKataResultRow
@export var row_passed: GDKataResultRow
@export var row_failed: GDKataResultRow
@export var row_total: GDKataResultRow
@export var button_submit: Button
@export var stats_container: VBoxContainer
@export var background_panel: PanelContainer

static var instance: GDKataResultView

var _current_kata: GDKataDefinition


func _ready() -> void:
	button_submit.pressed.connect(_on_submit)
	label_header.text = GDKataTr.translate("RESULTVIEW_RESULT_HEADER")
	button_submit.text = GDKataTr.translate("RESULTVIEW_BUTTON_SUBMIT")
	row_type_check.key.text = GDKataTr.translate("RESULTVIEW_LABEL_TYPE_CHECK")
	row_passed.key.text = GDKataTr.translate("RESULTVIEW_LABEL_PASSED")
	row_failed.key.text = GDKataTr.translate("RESULTVIEW_LABEL_FAILED")
	row_total.key.text = GDKataTr.translate("RESULTVIEW_LABEL_TOTAL")
	_apply_bold_keys()
	_load_from_disk()
	_update_submit_button()


func _enter_tree() -> void:
	if not instance:
		instance = self


func _exit_tree() -> void:
	if instance:
		instance = null


func set_current_kata(kata: GDKataDefinition) -> void:
	_current_kata = kata
	_update_submit_button()
	# Show stats when kata becomes active (no results yet)
	label_message.hide()
	stats_container.show()
	_reset_values()


func clear_current_kata() -> void:
	_current_kata = null
	_update_submit_button()
	_show_idle_state()


func update_results(result: GDKataResultDefinition) -> void:
	_apply_result(result)


func set_highlight(active: bool) -> void:
	var style := StyleBoxFlat.new()
	if active:
		style.bg_color = GDKataTheme.get_base_color_active()
	else:
		style.bg_color = GDKataTheme.get_base_color()
	add_theme_stylebox_override("panel", style)


func _update_submit_button() -> void:
	button_submit.disabled = _current_kata == null


func _show_idle_state() -> void:
	label_message.text = GDKataTr.translate("RESULTVIEW_LABEL_NO_KATA_ACTIVE")
	label_message.show()
	stats_container.hide()
	button_submit.hide()


func _reset_values() -> void:
	row_type_check.value.text = GDKataTr.translate("RESULTVIEW_LABEL_NO_VALUE")
	row_passed.value.text = GDKataTr.translate("RESULTVIEW_LABEL_NO_VALUE")
	row_failed.value.text = GDKataTr.translate("RESULTVIEW_LABEL_NO_VALUE")
	row_total.value.text = GDKataTr.translate("RESULTVIEW_LABEL_NO_VALUE")
	_clear_value_colors()


func _apply_result(result: GDKataResultDefinition) -> void:
	if not result:
		return

	stats_container.show()
	button_submit.show()

	if result.error:
		label_message.text = result.message
		label_message.show()
		row_type_check.value.text = GDKataTr.translate("RESULTVIEW_LABEL_NO_VALUE")
		row_passed.value.text = "0"
		row_failed.value.text = "0"
		row_total.value.text = "0"
		_clear_value_colors()
	else:
		label_message.hide()
		row_type_check.value.text = str(result.type_check_passed).to_lower()
		row_passed.value.text = str(result.passed_count)
		row_failed.value.text = str(result.failed_count)
		row_total.value.text = str(result.total_count)
		_apply_value_colors(result)


func _apply_value_colors(result: GDKataResultDefinition) -> void:
	if result.type_check_passed:
		row_type_check.value.add_theme_color_override("font_color", Color.GREEN)
	else:
		row_type_check.value.add_theme_color_override("font_color", Color.RED)
	row_passed.value.add_theme_color_override("font_color", Color.GREEN)
	row_failed.value.add_theme_color_override("font_color", Color.RED)


func _clear_value_colors() -> void:
	row_type_check.value.remove_theme_color_override("font_color")
	row_passed.value.remove_theme_color_override("font_color")
	row_failed.value.remove_theme_color_override("font_color")


func _apply_bold_keys() -> void:
	for row: GDKataResultRow in [row_type_check, row_passed, row_failed, row_total]:
		row.key.add_theme_font_size_override("font_size", 15)
		row.value.add_theme_font_size_override("font_size", 15)


func _load_from_disk() -> void:
	var result := GDKataResultDefinition.load_from_file()
	if result:
		_apply_result(result)


func _on_submit() -> void:
	if not _current_kata:
		return

	var folder_name := _current_kata.name.replace(" ", "_")
	var done_path := GDKataDefinition.DONE_PATH + folder_name + "/"

	if DirAccess.dir_exists_absolute(done_path):
		var timestamp := int(Time.get_unix_time_from_system())
		done_path = "%s%s_%d/" % [GDKataDefinition.DONE_PATH, folder_name, timestamp]

	DirAccess.make_dir_recursive_absolute(done_path)

	var in_progress := GDKataDefinition.IN_PROGRESS_PATH
	var script_filename := GDKataDefinition.get_script_filename(_current_kata.name)
	_move_file(
		in_progress + GDKataDefinition.KATA_CONFIG_FILE,
		done_path + GDKataDefinition.KATA_CONFIG_FILE
	)
	_move_file(in_progress + script_filename, done_path + script_filename)
	_move_file(
		GDKataResultDefinition.get_result_file_path(),
		done_path + GDKataResultDefinition.RESULT_FILE_NAME
	)

	EditorInterface.get_resource_filesystem().scan()
	kata_submitted.emit(_current_kata)
	clear_current_kata()


func _move_file(source: String, dest: String) -> void:
	if FileAccess.file_exists(source):
		DirAccess.rename_absolute(source, dest)
