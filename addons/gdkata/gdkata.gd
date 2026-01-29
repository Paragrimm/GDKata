@tool
extends EditorPlugin

var main_screen: GDKataMainScreen
var dock_selector: GDKataSelector
var dock_result_view: GDKataResultView

var _kata_active: bool = false
var _main_screen_visible: bool = false


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return GDKataDefinition.MAINSCREEN_NAME


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(
		GDKataDefinition.EDITOR_ICON_SCRIPT, GDKataDefinition.EDITOR_ICON_CATEGORY
	)


func _enter_tree() -> void:
	GDKataTr.setup()

	main_screen = preload("res://addons/gdkata/core/KataMainScreen.tscn").instantiate()
	EditorInterface.get_editor_main_screen().add_child(main_screen)
	main_screen.visible = false
	main_screen.tests_completed.connect(_on_tests_completed)
	main_screen.kata_cancelled.connect(_on_kata_cancelled)

	dock_selector = preload("res://addons/gdkata/core/docks/KataSelector.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, dock_selector)
	dock_selector.kata_started.connect(_on_kata_started)

	dock_result_view = preload("res://addons/gdkata/core/docks/ResultView.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock_result_view)
	dock_result_view.kata_submitted.connect(_on_kata_submitted)

	_set_docks_visible(false)
	_update_highlights()

	# Validierung erst nach dem initialen Dateisystem-Scan ausfuehren,
	# sonst kollidiert unser scan() mit Godots first_scan_filesystem.
	if EditorInterface.get_resource_filesystem().is_scanning():
		EditorInterface.get_resource_filesystem().filesystem_changed.connect(
			_on_initial_scan_done, CONNECT_ONE_SHOT
		)
	else:
		_validate_in_progress()
		_restore_active_kata()


func _exit_tree() -> void:
	GDKataTr.teardown()

	if main_screen:
		main_screen.queue_free()
	remove_control_from_docks(dock_selector)
	remove_control_from_docks(dock_result_view)
	dock_selector.queue_free()
	dock_result_view.queue_free()


func _make_visible(visible: bool) -> void:
	_main_screen_visible = visible
	if main_screen:
		main_screen.visible = visible
	_update_dock_visibility()
	if visible and _kata_active:
		_select_dock_tabs()


func _on_initial_scan_done() -> void:
	_validate_in_progress()
	_restore_active_kata()


func _validate_in_progress() -> void:
	if GDKataDefinition.has_valid_in_progress():
		return

	# Inkonsistenter Zustand: nicht beide Dateien vorhanden -> aufraumen
	_wipe_in_progress_folder()


func _restore_active_kata() -> void:
	if not GDKataDefinition.has_valid_in_progress():
		return

	var kata := GDKataDefinition.load_in_progress()
	if not kata:
		return

	_kata_active = true
	main_screen.set_kata(kata)
	dock_result_view.set_current_kata(kata)
	main_screen.show_external_editor_hint(GDKataDefinition.is_external_editor_configured())
	_update_highlights()


func _on_kata_started(kata: GDKataDefinition) -> void:
	_kata_active = true
	main_screen.set_kata(kata)
	dock_result_view.set_current_kata(kata)
	_update_dock_visibility()
	_update_highlights()

	if GDKataDefinition.is_external_editor_configured():
		main_screen.show_external_editor_hint(true)
		if not _main_screen_visible:
			EditorInterface.set_main_screen_editor(GDKataDefinition.MAINSCREEN_NAME)
		_select_dock_tabs_delayed()
	else:
		main_screen.show_external_editor_hint(false)
		_open_kata_script()


func _on_kata_cancelled(kata: GDKataDefinition) -> void:
	var source := GDKataDefinition.get_config_path()
	var target := "%s%s.json" % [GDKataDefinition.TODO_PATH, kata.name]
	if FileAccess.file_exists(source):
		DirAccess.rename_absolute(source, target)

	_wipe_in_progress_folder()

	_kata_active = false
	dock_result_view.clear_current_kata()
	dock_selector.on_kata_finished()
	_update_highlights()
	EditorInterface.set_main_screen_editor(GDKataDefinition.MAINSCREEN_NAME)


func _on_kata_submitted(_kata: GDKataDefinition) -> void:
	_kata_active = false
	main_screen.show_no_kata_state()
	dock_selector.on_kata_finished()
	_update_highlights()
	EditorInterface.set_main_screen_editor(GDKataDefinition.MAINSCREEN_NAME)


func _on_tests_completed(result: GDKataResultDefinition) -> void:
	dock_result_view.update_results(result)
	_update_highlights_after_test(result)


func _open_kata_script() -> void:
	await EditorInterface.get_resource_filesystem().filesystem_changed
	var script: Script = load(GDKataDefinition.get_script_path())
	if script:
		EditorInterface.edit_script(script)
		EditorInterface.set_main_screen_editor(GDKataDefinition.MAINSCREEN_SCRIPT)
		_select_dock_tabs_delayed()


func _wipe_in_progress_folder() -> void:
	var dir := DirAccess.open(GDKataDefinition.IN_PROGRESS_PATH)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			DirAccess.remove_absolute(GDKataDefinition.IN_PROGRESS_PATH + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	EditorInterface.get_resource_filesystem().scan()


func _update_dock_visibility() -> void:
	_set_docks_visible(_main_screen_visible or _kata_active)


func _set_docks_visible(visible: bool) -> void:
	if dock_selector:
		dock_selector.visible = visible
	if dock_result_view:
		dock_result_view.visible = visible


func _update_highlights() -> void:
	if not _kata_active:
		# Kein Kata aktiv: Selector heller, MainScreen und ResultView dunkler
		dock_selector.set_highlight(true)
		main_screen.set_highlight(false)
		dock_result_view.set_highlight(false)
	else:
		# Kata aktiv: MainScreen heller, Selector und ResultView dunkler
		dock_selector.set_highlight(false)
		main_screen.set_highlight(true)
		dock_result_view.set_highlight(false)


func _update_highlights_after_test(result: GDKataResultDefinition) -> void:
	if not result:
		return
	if result.error:
		# Fehler (z.B. falscher Methodenname): nur MainScreen hell
		dock_selector.set_highlight(false)
		main_screen.set_highlight(true)
		dock_result_view.set_highlight(false)
	else:
		# Ergebnis vorhanden: MainScreen und ResultView hell
		dock_selector.set_highlight(false)
		main_screen.set_highlight(true)
		dock_result_view.set_highlight(true)


func _select_dock_tabs_delayed() -> void:
	_select_dock_tabs()
	get_tree().create_timer(0.3).timeout.connect(_select_dock_tabs)


func _select_dock_tabs() -> void:
	_activate_dock_tab(dock_selector)
	_activate_dock_tab(dock_result_view)


func _activate_dock_tab(dock: Control) -> void:
	var parent := dock.get_parent()
	while parent:
		if parent.get_parent() is TabContainer:
			var tab_container: TabContainer = parent.get_parent()
			tab_container.current_tab = parent.get_index()
			return
		parent = parent.get_parent()
