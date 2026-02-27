@tool
class_name GDKataResultView
extends PanelContainer

signal run_tests_requested()
signal kata_cancel_requested()
signal kata_submit_requested()

@export var label_message: Label
@export var label_header: Label
@export var row_type_check: GDKataResultRow
@export var row_passed: GDKataResultRow
@export var row_failed: GDKataResultRow
@export var button_run_tests: Button
@export var button_cancel: Button
@export var button_submit: Button
@export var stats_container: VBoxContainer
@export var details_container: VBoxContainer
@export var background_panel: PanelContainer

static var instance: GDKataResultView

var _current_kata: GDKataDefinition
var _is_completed: bool = false


func _ready() -> void:
	button_run_tests.pressed.connect(_on_run_tests)
	button_cancel.pressed.connect(_on_cancel)
	button_submit.pressed.connect(_on_submit)
	label_header.text = GDKataTr.translate("RESULTVIEW_RESULT_HEADER")
	button_run_tests.text = GDKataTr.translate("RESULTVIEW_BUTTON_RUN_TESTS")
	button_cancel.text = GDKataTr.translate("RESULTVIEW_BUTTON_CANCEL_KATA")
	button_submit.text = GDKataTr.translate("RESULTVIEW_BUTTON_SUBMIT_COMPLETED")
	row_type_check.key.text = GDKataTr.translate("RESULTVIEW_LABEL_TYPE_CHECK")
	row_passed.key.text = GDKataTr.translate("RESULTVIEW_LABEL_PASSED")
	row_failed.key.text = GDKataTr.translate("RESULTVIEW_LABEL_FAILED")
	_apply_bold_keys()
	_show_idle_state()
	_load_from_disk()
	_update_action_buttons()


func _enter_tree() -> void:
	if not instance:
		instance = self


func _exit_tree() -> void:
	if instance:
		instance = null


func set_current_kata(kata: GDKataDefinition) -> void:
	_current_kata = kata
	_is_completed = false
	label_message.hide()
	stats_container.show()
	button_run_tests.show()
	button_cancel.show()
	button_submit.show()
	_reset_values()
	_clear_details()
	_update_action_buttons()


func clear_current_kata() -> void:
	_current_kata = null
	_is_completed = false
	_reset_values()
	_clear_details()
	_update_action_buttons()
	_show_idle_state()


func update_results(result: GDKataResultDefinition, completed: bool) -> void:
	_is_completed = completed
	_apply_result(result)
	_update_action_buttons()


func set_highlight(active: bool) -> void:
	var style := StyleBoxFlat.new()
	if active:
		style.bg_color = GDKataTheme.get_base_color_active()
	else:
		style.bg_color = GDKataTheme.get_base_color()
	add_theme_stylebox_override("panel", style)


func _update_action_buttons() -> void:
	var has_kata := _current_kata != null
	button_run_tests.disabled = not has_kata
	button_cancel.disabled = not has_kata
	button_submit.disabled = not has_kata or not _is_completed


func _show_idle_state() -> void:
	label_message.text = GDKataTr.translate("RESULTVIEW_LABEL_NO_KATA_ACTIVE")
	label_message.show()
	stats_container.hide()
	button_run_tests.hide()
	button_cancel.hide()
	button_submit.hide()


func _reset_values() -> void:
	row_type_check.value.text = GDKataTr.translate("RESULTVIEW_LABEL_NO_VALUE")
	row_passed.value.text = GDKataTr.translate("RESULTVIEW_LABEL_NO_VALUE")
	row_failed.value.text = GDKataTr.translate("RESULTVIEW_LABEL_NO_VALUE")
	_clear_value_colors()


func _apply_result(result: GDKataResultDefinition) -> void:
	if not result:
		return

	stats_container.show()
	button_run_tests.show()
	button_cancel.show()
	button_submit.show()

	if result.error:
		label_message.text = result.message
		label_message.show()
		row_type_check.value.text = GDKataTr.translate("RESULTVIEW_LABEL_NO_VALUE")
		row_passed.value.text = "0"
		row_failed.value.text = "0"
		_clear_value_colors()
		_clear_details()
		return

	label_message.hide()
	row_type_check.value.text = str(result.type_check_passed).to_lower()
	row_passed.value.text = str(result.passed_count)
	row_failed.value.text = str(result.failed_count)
	_apply_value_colors(result)
	_apply_details(result)


func _apply_value_colors(result: GDKataResultDefinition) -> void:
	if result.type_check_passed:
		row_type_check.value.add_theme_color_override("font_color", Color.GREEN)
	else:
		row_type_check.value.add_theme_color_override("font_color", Color.RED)

	row_passed.value.add_theme_color_override("font_color", Color.GREEN)

	if result.failed_count == 0:
		row_failed.value.add_theme_color_override("font_color", Color.GREEN)
	else:
		row_failed.value.add_theme_color_override("font_color", Color.RED)


func _clear_value_colors() -> void:
	row_type_check.value.remove_theme_color_override("font_color")
	row_passed.value.remove_theme_color_override("font_color")
	row_failed.value.remove_theme_color_override("font_color")


func _apply_bold_keys() -> void:
	for row in [row_type_check, row_passed, row_failed]:
		row.key.add_theme_font_size_override("font_size", 15)
		row.value.add_theme_font_size_override("font_size", 15)


func _apply_details(result: GDKataResultDefinition) -> void:
	_clear_details()
	for detail in result.details:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var status_label := Label.new()
		status_label.custom_minimum_size.x = 55.0
		if detail.status:
			status_label.text = GDKataTr.translate("TESTDETAIL_TEST_STATUS_PASS")
			status_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			status_label.text = GDKataTr.translate("TESTDETAIL_TEST_STATUS_FAIL")
			status_label.add_theme_color_override("font_color", Color.RED)
		row.add_child(status_label)

		var detail_label := Label.new()
		detail_label.text = "%s: %s" % [detail.name, detail.message]
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(detail_label)

		details_container.add_child(row)


func _clear_details() -> void:
	for child in details_container.get_children():
		child.queue_free()


func _load_from_disk() -> void:
	var result := GDKataResultDefinition.load_from_file()
	if result and _current_kata:
		update_results(result, false)


func _on_run_tests() -> void:
	run_tests_requested.emit()


func _on_cancel() -> void:
	kata_cancel_requested.emit()


func _on_submit() -> void:
	kata_submit_requested.emit()
