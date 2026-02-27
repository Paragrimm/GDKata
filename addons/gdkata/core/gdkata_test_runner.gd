@tool
class_name GDKataTestRunner
extends RefCounted


static func run_tests(kata: GDKataDefinition = null) -> GDKataResultDefinition:
	var result := GDKataResultDefinition.new()

	var active_kata := kata
	if not active_kata:
		active_kata = GDKataDefinition.load_in_progress()
	if not active_kata:
		return _error(result, _tr("TESTRUNNER_ERR_CONFIG_NOT_FOUND"))

	var script_path := active_kata.get_script_path()
	if not FileAccess.file_exists(script_path):
		return _error(result, _tr("TESTRUNNER_ERR_SCRIPT_MISSING") % active_kata.ensure_active_script_filename())

	var user_script: Resource = load(script_path)
	if user_script == null:
		return _error(result, _tr("TESTRUNNER_ERR_SCRIPT_COMPILE"))

	var user_instance: Variant = user_script.new()
	var method_name: String = active_kata.method_name
	if not user_instance.has_method(method_name):
		return _error(result, _tr("TESTRUNNER_ERR_METHOD_NOT_FOUND") % method_name)

	var expected_type: int = active_kata.expected_type_hint

	for test in active_kata.tests:
		result.total_count += 1
		var actual: Variant = user_instance.callv(method_name, test.arguments)
		var expected: Variant = test.expected

		var detail := GDKataTestResultDefinition.new()
		detail.name = test.name

		var actual_type: int = typeof(actual)
		var type_matches: bool = expected_type == TYPE_NIL or actual_type == expected_type

		if not type_matches:
			result.type_check_passed = false
			result.failed_count += 1
			detail.status = false
			detail.message = (
				_tr("TESTRUNNER_TEST_RESULT_TYPE_MISMATCH")
				% [type_string(expected_type), type_string(actual_type)]
			)
		elif actual == expected:
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
	if FileAccess.file_exists(path):
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
