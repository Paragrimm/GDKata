@tool
class_name GDKataTestRunner
extends RefCounted


static func run_tests() -> GDKataResultDefinition:
	var result := GDKataResultDefinition.new()

	if not FileAccess.file_exists(GDKataDefinition.get_config_path()):
		return _error(result, _tr("TESTRUNNER_ERR_CONFIG_NOT_FOUND"))

	var config_text := FileAccess.get_file_as_string(GDKataDefinition.get_config_path())
	var config: Variant = JSON.parse_string(config_text)
	if config == null:
		return _error(result, _tr("TESTRUNNER_ERR_CONFIG_PARSE"))

	var kata_name: String = config["name"]
	var script_path := GDKataDefinition.get_script_path_for(kata_name)

	if not FileAccess.file_exists(script_path):
		return _error(result, _tr("TESTRUNNER_ERR_SCRIPT_MISSING"))

	var user_script: Resource = load(script_path)
	if user_script == null:
		return _error(result, _tr("TESTRUNNER_ERR_SCRIPT_COMPILE"))

	var user_instance: Variant = user_script.new()
	var method_name: String = config["method_name"]

	if not user_instance.has_method(method_name):
		return _error(result, _tr("TESTRUNNER_ERR_METHOD_NOT_FOUND") % method_name)

	for test: Variant in config["tests"]:
		result.total_count += 1
		var args: Array = test["arguments"]
		var expected: Variant = test["expected"]
		var test_name: String = test.get("name", "Test %d" % result.total_count)
		var actual: Variant = user_instance.callv(method_name, args)

		var detail := GDKataTestResultDefinition.new()
		detail.name = test_name

		if actual == expected:
			result.passed_count += 1
			detail.status = true
			detail.message = _tr("TESTRUNNER_TEST_RESULT_PASS") % str(actual)
		else:
			result.failed_count += 1
			detail.status = false
			detail.message = _tr("TESTRUNNER_TEST_RESULT_FAIL") % [str(expected), str(actual)]

		result.details.append(detail)

	return result


static func save_results(result: GDKataResultDefinition) -> void:
	var path := GDKataResultDefinition.get_result_file_path()
	DirAccess.remove_absolute(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(result.to_json())
		file.close()


static func _error(result: GDKataResultDefinition, msg: String) -> GDKataResultDefinition:
	result.error = true
	result.message = msg
	return result


static func _tr(key: String) -> String:
	return GDKataTr.translate(key)
