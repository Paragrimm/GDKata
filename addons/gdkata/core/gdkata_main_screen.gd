@tool
class_name GDKataMainScreen
extends PanelContainer

const STATUS_MIN_WIDTH: float = 50.0

signal tests_completed(result: GDKataResultDefinition)
signal kata_cancelled(kata: GDKataDefinition)

@export var label_kata_name: Label
@export var label_kata_description: Label
@export var label_external_hint: Label
@export var button_test: Button
@export var button_cancel: Button
@export var test_details_container: VBoxContainer
@export var scroll_container: ScrollContainer
@export var no_kata_label: Label
@export var kata_info_container: Control
@export var label_hints: Label
@export var button_hints_toggle: Button
@export var hints_container: VBoxContainer
@export var background_panel: PanelContainer

var _current_kata: GDKataDefinition
var _hints_visible: bool = false


func _ready() -> void:
	button_test.pressed.connect(_on_test_pressed)
	button_cancel.pressed.connect(_on_cancel_pressed)
	button_hints_toggle.pressed.connect(_on_hints_toggle_pressed)
	no_kata_label.text = GDKataTr.translate("MAINSCREEN_NO_KATA_PROMPT")
	button_test.text = GDKataTr.translate("MAINSCREEN_BUTTON_RUN_TESTS")
	button_cancel.text = GDKataTr.translate("MAINSCREEN_BUTTON_CANCEL_KATA")
	label_external_hint.text = GDKataTr.translate("MAINSCREEN_EXTERNAL_EDITOR_HINT")
	show_no_kata_state()


func show_no_kata_state() -> void:
	_current_kata = null
	kata_info_container.visible = false
	no_kata_label.visible = true
	_clear_test_details()


func set_kata(kata: GDKataDefinition) -> void:
	_current_kata = kata
	no_kata_label.visible = false
	kata_info_container.visible = true
	label_kata_name.text = kata.name
	label_kata_description.text = kata.description
	_setup_hints(kata)
	_clear_test_details()


func show_external_editor_hint(value: bool) -> void:
	label_external_hint.visible = value


func set_highlight(active: bool) -> void:
	var style := StyleBoxFlat.new()
	if active:
		style.bg_color = GDKataTheme.get_base_color_active()
	else:
		style.bg_color = GDKataTheme.get_base_color()
	add_theme_stylebox_override("panel", style)


func _setup_hints(kata: GDKataDefinition) -> void:
	_hints_visible = false
	if kata.hints.is_empty():
		button_hints_toggle.visible = false
		hints_container.visible = false
	else:
		button_hints_toggle.visible = true
		button_hints_toggle.text = GDKataTr.translate("MAINSCREEN_BUTTON_SHOW_HINTS")
		hints_container.visible = false
		label_hints.text = kata.hints


func _on_hints_toggle_pressed() -> void:
	_hints_visible = not _hints_visible
	hints_container.visible = _hints_visible
	if _hints_visible:
		button_hints_toggle.text = GDKataTr.translate("MAINSCREEN_BUTTON_HIDE_HINTS")
	else:
		button_hints_toggle.text = GDKataTr.translate("MAINSCREEN_BUTTON_SHOW_HINTS")


func _on_test_pressed() -> void:
	_clear_test_details()
	var result := GDKataTestRunner.run_tests()
	GDKataTestRunner.save_results(result)
	_display_result(result)
	tests_completed.emit(result)


func _on_cancel_pressed() -> void:
	if not _current_kata:
		return
	kata_cancelled.emit(_current_kata)
	show_no_kata_state()


func _display_result(result: GDKataResultDefinition) -> void:
	_clear_test_details()

	if result.error:
		var label := Label.new()
		label.text = result.message
		label.add_theme_color_override("font_color", Color.RED)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		test_details_container.add_child(label)
		return

	for detail: GDKataTestResultDefinition in result.details:
		var row := HBoxContainer.new()

		var status_label := Label.new()
		status_label.custom_minimum_size.x = STATUS_MIN_WIDTH
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

		test_details_container.add_child(row)


func _clear_test_details() -> void:
	for child in test_details_container.get_children():
		child.queue_free()
