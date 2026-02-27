class_name GDKataResultDefinition
extends Resource

const RESULT_FILE_NAME: String = "result.json"

@export var passed_count: int = 0
@export var failed_count: int = 0
@export var total_count: int = 0
@export var type_check_passed: bool = true
@export var error: bool = false
@export var message: String
@export var details: Array[GDKataTestResultDefinition] = []


static func get_result_file_path() -> String:
	GDKataDefinition.ensure_directories()
	return GDKataDefinition.WORKSPACE_PATH + RESULT_FILE_NAME


static func from_json(json: JSON) -> GDKataResultDefinition:
	if not json:
		return null
	var result := GDKataResultDefinition.new()

	if json.data.has("error") and json.data["error"]:
		result.error = true
		result.message = json.data["message"]
		return result

	result.passed_count = int(json.data.get("passed_count", 0))
	result.failed_count = int(json.data.get("failed_count", 0))
	result.total_count = int(json.data.get("total_count", result.passed_count + result.failed_count))
	result.type_check_passed = bool(json.data.get("type_check_passed", true))
	for detail_data in json.data.get("details", []):
		if typeof(detail_data) != TYPE_DICTIONARY:
			continue
		var d := GDKataTestResultDefinition.new()
		d.name = str(detail_data.get("name", ""))
		d.message = str(detail_data.get("message", ""))
		d.status = bool(detail_data.get("status", false))
		result.details.append(d)

	return result


static func load_from_file() -> GDKataResultDefinition:
	var path := get_result_file_path()
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return from_json(json)


func to_json() -> String:
	if error:
		return JSON.stringify({"error": true, "message": message}, "\t")

	var data: Variant = {
		"passed_count": passed_count,
		"failed_count": failed_count,
		"total_count": total_count,
		"type_check_passed": type_check_passed,
		"details": [],
	}
	for detail in details:
		data["details"].append(
			{
				"name": detail.name,
				"message": detail.message,
				"status": detail.status,
			}
		)
	return JSON.stringify(data, "\t")
