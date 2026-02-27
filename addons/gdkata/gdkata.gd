@tool
class_name GDKata
extends EditorPlugin

const CONFIG_PATH := "res://addons/gdkata/gdkata.cfg"

var dock_selector: GDKataSelector
var dock_result_view: GDKataResultView

var _current_kata: GDKataDefinition
var _last_result: GDKataResultDefinition


func _has_main_screen() -> bool:
	return false


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(
		GDKataDefinition.EDITOR_ICON_SCRIPT, GDKataDefinition.EDITOR_ICON_CATEGORY
	)


func _enter_tree() -> void:
	GDKataTr.setup()
	GDKataDefinition.ensure_catalog_initialized()

	dock_selector = preload("res://addons/gdkata/core/docks/KataSelector.tscn").instantiate()
	if dock_selector:
		add_control_to_dock(DOCK_SLOT_LEFT_UR, dock_selector)
		dock_selector.kata_start_requested.connect(_on_kata_start_requested)
		dock_selector.refresh_requested.connect(_on_selector_refresh_requested)
	else:
		printerr("[GDKata] Failed to instantiate KataSelector dock scene.")

	dock_result_view = preload("res://addons/gdkata/core/docks/ResultView.tscn").instantiate()
	if dock_result_view:
		add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock_result_view)
		dock_result_view.run_tests_requested.connect(_on_run_tests_requested)
		dock_result_view.kata_cancel_requested.connect(_on_kata_cancel_requested)
		dock_result_view.kata_submit_requested.connect(_on_kata_submit_requested)
	else:
		printerr("[GDKata] Failed to instantiate ResultView dock scene.")

	if dock_selector and dock_result_view:
		_restore_state()


func _exit_tree() -> void:
	GDKataTr.teardown()

	if dock_selector:
		remove_control_from_docks(dock_selector)
	if dock_result_view:
		remove_control_from_docks(dock_result_view)

	if dock_selector:
		dock_selector.queue_free()
	if dock_result_view:
		dock_result_view.queue_free()


func _make_visible(_visible: bool) -> void:
	if dock_selector:
		dock_selector.visible = true
	if dock_result_view:
		dock_result_view.visible = true


func _restore_state() -> void:
	dock_selector.reload_data()

	var active := GDKataDefinition.load_in_progress()
	if active and active.active_script_filename.is_empty():
		active.active_script_filename = GDKataDefinition.get_script_filename(
			active.get_display_name()
		)
		GDKataDefinition.save_kata(active)

	if active and not FileAccess.file_exists(active.get_script_path()):
		active.status = GDKataDefinition.STATUS_TODO
		active.active_script_filename = ""
		GDKataDefinition.save_kata(active)
		active = null

	_current_kata = active
	_last_result = null

	dock_result_view.clear_current_kata()
	if _current_kata:
		dock_result_view.set_current_kata(_current_kata)
		var result := GDKataResultDefinition.load_from_file()
		if result:
			_last_result = result
			dock_result_view.update_results(result, _current_kata.is_completed_by_result(result))

	dock_selector.set_active_kata_id(_current_kata.id if _current_kata else "")
	dock_selector.reload_data(_current_kata.id if _current_kata else "")
	_update_highlights()


func _on_selector_refresh_requested() -> void:
	_restore_state()


func _on_kata_start_requested(kata_id: String) -> void:
	if kata_id.is_empty():
		return

	var katas := GDKataDefinition.load_catalog()
	var selected: GDKataDefinition

	for kata in katas:
		if kata.id == kata_id:
			selected = kata
			kata.status = GDKataDefinition.STATUS_IN_PROGRESS
		elif kata.status == GDKataDefinition.STATUS_IN_PROGRESS:
			kata.status = GDKataDefinition.STATUS_TODO
			kata.active_script_filename = ""

	if not selected:
		return

	selected.active_script_filename = GDKataDefinition.get_script_filename(
		selected.get_display_name()
	)
	GDKataDefinition.save_catalog(katas)
	_create_template_script(selected)
	GDKataDefinition.clear_workspace_result()

	_current_kata = selected
	_last_result = null

	dock_selector.set_active_kata_id(selected.id)
	dock_selector.reload_data(selected.id)
	dock_result_view.set_current_kata(selected)
	_update_highlights()
	_open_kata_script()


func _on_run_tests_requested() -> void:
	if not _current_kata:
		return

	_current_kata.apply_locale(TranslationServer.get_locale())
	var result := GDKataTestRunner.run_tests(_current_kata)
	GDKataTestRunner.save_results(result)
	_last_result = result
	dock_result_view.update_results(result, _current_kata.is_completed_by_result(result))
	_update_highlights_after_test(result)


func _on_kata_cancel_requested() -> void:
	if not _current_kata:
		return

	var script_filename := _current_kata.active_script_filename
	_current_kata.status = GDKataDefinition.STATUS_TODO
	_current_kata.active_script_filename = ""
	GDKataDefinition.save_kata(_current_kata)
	GDKataDefinition.delete_workspace_script(script_filename)
	GDKataDefinition.clear_workspace_result()

	_current_kata = null
	_last_result = null

	dock_result_view.clear_current_kata()
	dock_selector.set_active_kata_id("")
	dock_selector.reload_data()
	_update_highlights()


func _on_kata_submit_requested() -> void:
	if not _current_kata:
		return
	if not _current_kata.is_completed_by_result(_last_result):
		return

	var script_filename := _current_kata.active_script_filename
	_current_kata.status = GDKataDefinition.STATUS_DONE
	_current_kata.active_script_filename = ""
	GDKataDefinition.save_kata(_current_kata)
	GDKataDefinition.delete_workspace_script(script_filename)
	GDKataDefinition.clear_workspace_result()

	_current_kata = null
	_last_result = null

	dock_result_view.clear_current_kata()
	dock_selector.set_active_kata_id("")
	dock_selector.reload_data()
	_update_highlights()


func _create_template_script(kata: GDKataDefinition) -> void:
	var template_file := FileAccess.open(GDKataDefinition.TEMPLATE_PATH, FileAccess.READ)
	if not template_file:
		return

	var template := template_file.get_as_text()
	template_file.close()
	template = template.replace(GDKataDefinition.TEMPLATE_METHOD_NAME_PLACEHOLDER, kata.method_name)
	template = template.replace(
		GDKataDefinition.TEMPLATE_EXPECTED_TYPE_PLACEHOLDER, type_string(kata.expected_type_hint)
	)
	template = template.replace(
		GDKataDefinition.TEMPLATE_ARGUMENTS_PLACEHOLDER, _build_arguments_string(kata)
	)
	template = template.replace(
		GDKataDefinition.TEMPLATE_TITLE_PLACEHOLDER, kata.get_display_name()
	)
	template = template.replace(
		GDKataDefinition.TEMPLATE_DESCRIPTION_PLACEHOLDER, kata.get_display_description()
	)
	template = template.replace(
		GDKataDefinition.TEMPLATE_DEFAULT_RETURN_PLACEHOLDER,
		GDKataDefinition.get_default_return_for_type(kata.expected_type_hint)
	)

	var script_path := kata.get_script_path()
	var dest_file := FileAccess.open(script_path, FileAccess.WRITE)
	if not dest_file:
		printerr("[GDKata] Could not write script: ", script_path)
		return
	dest_file.store_string(template)
	dest_file.close()
	EditorInterface.get_resource_filesystem().scan()


func _build_arguments_string(kata: GDKataDefinition) -> String:
	var parts: PackedStringArray = []
	for i in range(kata.arguments.size()):
		var arg := kata.arguments[i]
		var letter := arg.name if not arg.name.is_empty() else char(ord("a") + i)
		var type := type_string(arg.type_hint)
		parts.append("%s: %s" % [letter, type])
	return ", ".join(parts)


func _open_kata_script() -> void:
	if not _current_kata:
		return

	await get_tree().process_frame
	var script: Script = load(_current_kata.get_script_path())
	if script:
		EditorInterface.edit_script(script)
		EditorInterface.set_main_screen_editor(GDKataDefinition.MAINSCREEN_SCRIPT)


func _update_highlights() -> void:
	if not _current_kata:
		dock_selector.set_highlight(true)
		dock_result_view.set_highlight(false)
	else:
		dock_selector.set_highlight(false)
		dock_result_view.set_highlight(true)


func _update_highlights_after_test(result: GDKataResultDefinition) -> void:
	if not result:
		return
	dock_selector.set_highlight(false)
	dock_result_view.set_highlight(true)
