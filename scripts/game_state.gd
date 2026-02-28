extends Node
## GameState Autoload Singleton
## Tracks all persistent game state including loop progression, player metrics,
## corruption levels, and handles save/load functionality.

# Signals
signal loop_advanced(new_loop_count: int)
signal compliance_changed(new_value: float)
signal resistance_changed(new_value: float)
signal corruption_tier_changed(new_tier: int)
signal ending_triggered(ending_name: String)
signal game_saved()
signal game_loaded()

# Runtime State (resets on new game, saved/loaded)
var loop_count: int = 0
var compliance_score: float = 0.5  # 0.0 to 1.0, starts neutral
var resistance_score: float = 0.0  # 0.0 to 1.0
var corruption_tier: int = 0  # 0-6
var flags: Dictionary = {}  # Tracks narrative flags like "questioned_rating", "refused_signature"
var current_ending: String = ""

# Meta Progression (persists across playthroughs)
var endings_unlocked: Array[String] = []
var total_playthroughs: int = 0

# Constants
const SAVE_PATH: String = "user://save_data.json"
const META_SAVE_PATH: String = "user://meta_data.json"
const MAX_CORRUPTION_TIER: int = 6

# Ending thresholds
const ENDING_COMPLIANT_THRESHOLD: float = 0.9
const ENDING_TERMINATED_THRESHOLD: float = 0.1
const ENDING_SYSTEM_FAILURE_LOOPS: int = 10


func _ready() -> void:
	load_meta_save()


#region Loop Management

func advance_loop() -> void:
	loop_count += 1
	_recalculate_corruption_tier()
	loop_advanced.emit(loop_count)
	save_game()


func reset_loop_state() -> void:
	## Resets runtime state for a new game (does not affect meta progression)
	loop_count = 0
	compliance_score = 0.5
	resistance_score = 0.0
	corruption_tier = 0
	flags.clear()
	current_ending = ""


func start_new_game() -> void:
	reset_loop_state()
	save_game()

#endregion


#region Score Management

func adjust_compliance(delta: float) -> void:
	## Positive delta = more compliant, negative = less compliant
	compliance_score = clampf(compliance_score + delta, 0.0, 1.0)
	compliance_changed.emit(compliance_score)
	_check_ending_conditions()


func adjust_resistance(delta: float) -> void:
	## Positive delta = more resistant
	resistance_score = clampf(resistance_score + delta, 0.0, 1.0)
	resistance_changed.emit(resistance_score)
	_recalculate_corruption_tier()


func set_flag(flag_name: String, value: bool = true) -> void:
	flags[flag_name] = value


func get_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func _recalculate_corruption_tier() -> void:
	## Corruption tier formula from GDD:
	## corruption_tier = min(loop_count + int(resistance_score * 3), 6)
	var new_tier: int = mini(loop_count + int(resistance_score * 3.0), MAX_CORRUPTION_TIER)
	if new_tier != corruption_tier:
		corruption_tier = new_tier
		corruption_tier_changed.emit(corruption_tier)

#endregion


#region Ending System

func _check_ending_conditions() -> void:
	## Check if any ending conditions are met

	# COMPLIANT ending - extreme compliance
	if compliance_score >= ENDING_COMPLIANT_THRESHOLD and loop_count >= 3:
		_trigger_ending("COMPLIANT")
		return

	# TERMINATED ending - extreme non-compliance
	if compliance_score <= ENDING_TERMINATED_THRESHOLD and loop_count >= 2:
		_trigger_ending("TERMINATED")
		return

	# SYSTEM_FAILURE ending - too many loops
	if loop_count >= ENDING_SYSTEM_FAILURE_LOOPS:
		_trigger_ending("SYSTEM_FAILURE")
		return

	# PROMOTED ending - specific flag combination
	if get_flag("accepted_promotion") and compliance_score >= 0.8:
		_trigger_ending("PROMOTED")
		return

	# SELF_REALIZATION ending - hidden flag
	if get_flag("found_truth") and get_flag("rejected_system"):
		_trigger_ending("SELF_REALIZATION")
		return


func _trigger_ending(ending_name: String) -> void:
	if current_ending != "":
		return  # Already triggered an ending

	current_ending = ending_name

	# Update meta progression
	if ending_name not in endings_unlocked:
		endings_unlocked.append(ending_name)
	total_playthroughs += 1
	save_meta()

	ending_triggered.emit(ending_name)


func get_available_endings() -> Array[String]:
	return ["COMPLIANT", "PROMOTED", "TERMINATED", "SELF_REALIZATION", "SYSTEM_FAILURE"]

#endregion


#region Save System - Runtime

func save_game() -> void:
	var save_data: Dictionary = {
		"loop_count": loop_count,
		"compliance_score": compliance_score,
		"resistance_score": resistance_score,
		"corruption_tier": corruption_tier,
		"flags": flags,
		"current_ending": current_ending,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		game_saved.emit()
	else:
		push_error("GameState: Failed to save game - " + str(FileAccess.get_open_error()))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("GameState: Failed to load game - " + str(FileAccess.get_open_error()))
		return false

	var json_string: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("GameState: Failed to parse save data")
		return false

	var save_data: Dictionary = json.data

	loop_count = save_data.get("loop_count", 0)
	compliance_score = save_data.get("compliance_score", 0.5)
	resistance_score = save_data.get("resistance_score", 0.0)
	corruption_tier = save_data.get("corruption_tier", 0)
	flags = save_data.get("flags", {})
	current_ending = save_data.get("current_ending", "")

	game_loaded.emit()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

#endregion


#region Save System - Meta Progression

func save_meta() -> void:
	var meta_data: Dictionary = {
		"endings_unlocked": endings_unlocked,
		"total_playthroughs": total_playthroughs,
	}

	var file := FileAccess.open(META_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(meta_data, "\t"))
		file.close()


func load_meta_save() -> void:
	if not FileAccess.file_exists(META_SAVE_PATH):
		return

	var file := FileAccess.open(META_SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var json_string: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		return

	var meta_data: Dictionary = json.data

	# Convert Array to typed Array[String]
	var unlocked: Array = meta_data.get("endings_unlocked", [])
	endings_unlocked.clear()
	for ending in unlocked:
		endings_unlocked.append(str(ending))

	total_playthroughs = meta_data.get("total_playthroughs", 0)

#endregion


#region Condition Evaluation (for dialogue system)

func evaluate_condition(condition: String) -> bool:
	## Evaluates condition strings from dialogue.json safely (no eval)
	## Supported formats:
	##   "loop_count >= 2"
	##   "compliance_score < 0.3"
	##   "corruption_tier == 4"
	##   "flag:questioned_rating"
	##   "flag:!signed_quickly" (negation)

	condition = condition.strip_edges()

	# Flag check
	if condition.begins_with("flag:"):
		var flag_name: String = condition.substr(5)
		if flag_name.begins_with("!"):
			return not get_flag(flag_name.substr(1))
		return get_flag(flag_name)

	# Comparison operations
	var parts: PackedStringArray
	var operator: String = ""
	var operators: Array[String] = [">=", "<=", "==", "!=", ">", "<"]

	for op in operators:
		if condition.contains(op):
			operator = op
			parts = condition.split(op)
			break

	if parts.size() != 2 or operator == "":
		push_warning("GameState: Invalid condition format - " + condition)
		return false

	var variable_name: String = parts[0].strip_edges()
	var compare_value: String = parts[1].strip_edges()

	var current_value: float = 0.0
	match variable_name:
		"loop_count":
			current_value = float(loop_count)
		"compliance_score":
			current_value = compliance_score
		"resistance_score":
			current_value = resistance_score
		"corruption_tier":
			current_value = float(corruption_tier)
		_:
			push_warning("GameState: Unknown variable in condition - " + variable_name)
			return false

	var target_value: float = compare_value.to_float()

	match operator:
		">=":
			return current_value >= target_value
		"<=":
			return current_value <= target_value
		"==":
			return is_equal_approx(current_value, target_value)
		"!=":
			return not is_equal_approx(current_value, target_value)
		">":
			return current_value > target_value
		"<":
			return current_value < target_value

	return false

#endregion
