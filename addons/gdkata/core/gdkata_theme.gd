@tool
class_name GDKataTheme
extends RefCounted

const COLOR_BACKGROUND: Color = Color(0.1, 0.1, 0.1, 1.0)
const COLOR_BACKGROUND_ACTIVE: Color = Color(0.16, 0.16, 0.16, 1.0)
const EDITOR_SETTING_BASE_COLOR: String = "interface/theme/base_color"


static func get_base_color() -> Color:
	var setting: EditorSettings = EditorInterface.get_editor_settings()
	return (
		setting.get_setting(EDITOR_SETTING_BASE_COLOR)
		if setting.has_setting(EDITOR_SETTING_BASE_COLOR)
		else COLOR_BACKGROUND
	)


static func get_base_color_active() -> Color:
	return get_base_color().lightened(0.06)
