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
	DirAccess.make_dir_recursive_absolute(GDKataDefinition.DONE_PATH)
	return GDKataDefinition.DONE_PATH + RESULT_FILE_NAME


static func from_json(json: JSON) -> GDKataResultDefinition:
	if not json:
		return null
	var result := GDKataResultDefinition.new()

	if json.data.has("error") and json.data["error"]:
		result.error = true
		result.message = json.data["message"]
		return result

	result.passed_count = json.data["passed_count"]
	result.failed_count = json.data["failed_count"]
	result.total_count = json.data["total_count"]
	result.type_check_passed = json.data["type_check_passed"]
	for detail in json.data["details"]:
		var d := GDKataTestResultDefinition.new()
		d.name = detail.get("name", "")
		d.message = detail["message"]
		d.status = detail["status"]
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
	for detail: GDKataTestResultDefinition in details:
		(
			data["details"]
			. append(
				{
					"name": detail.name,
					"message": detail.message,
					"status": detail.status,
				}
			)
		)
	return JSON.stringify(data, "\t")
