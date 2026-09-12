class_name SaveManager
extends RefCounted

## Ported from SaveManager.cs.
##
## Load is transactional: everything is parsed, validated and advanced on
## temporary objects first, and the live clock/player are only touched once the
## whole pipeline succeeded. A rejected save leaves live state untouched.

const USER_SAVE_PATH: String = "user://save.json"
const WINDOWS_SAVE_RELATIVE: String = "LIFESTATE/save.json"

static var ACCUMULATOR_KEYS: PackedStringArray = PackedStringArray([
	"WorkMinutesAccumulator",
	"StudyMinutesAccumulator",
	"AwakeMinutesAccumulator",
	"SleepingMinutesAccumulator",
	"HungerMinutesAccumulator",
	"ThirstMinutesAccumulator",
	"PlayMinutesAccumulator",
	"FamilyTimeMinutesAccumulator",
])


## Default Godot save location (user:// resolves per-platform, including Android).
static func default_save_path() -> String:
	return USER_SAVE_PATH


## Location of the C#/WinForms save on Windows, if present.
static func windows_save_path() -> String:
	var local_app_data: String = OS.get_environment("LOCALAPPDATA")
	if local_app_data.is_empty():
		return ""
	return local_app_data.path_join(WINDOWS_SAVE_RELATIVE)


## Copies an existing C# build save into user:// so it can be loaded normally.
static func import_windows_save(target_path: String = "") -> Dictionary:
	var source: String = windows_save_path()
	if source.is_empty():
		return {"ok": false, "error": "LOCALAPPDATA is not available on this platform."}
	if not FileAccess.file_exists(source):
		return {"ok": false, "error": "No WinForms save found at %s" % source}

	var text: String = FileAccess.get_file_as_string(source)
	if text.is_empty():
		return {"ok": false, "error": "WinForms save is empty or unreadable."}

	var destination: String = target_path if not target_path.is_empty() else USER_SAVE_PATH
	var write := _write_text(destination, text)
	if not write["ok"]:
		return write
	return {"ok": true, "error": "", "path": destination, "source": source}


static func save_game(clock: GameClock, player: PlayerState, path: String = "", now_unix: float = NAN) -> Dictionary:
	var target: String = path if not path.is_empty() else USER_SAVE_PATH
	var data := SaveData.to_dict(clock, player, now_unix)
	return _write_text(target, JSON.stringify(data))


static func save_exists(path: String = "") -> bool:
	var target: String = path if not path.is_empty() else USER_SAVE_PATH
	return FileAccess.file_exists(target)


## Returns {"ok", "error", "offline_seconds", "offline_minutes"}.
static func load_game(clock: GameClock, player: PlayerState, path: String = "", now_unix: float = NAN) -> Dictionary:
	var target: String = path if not path.is_empty() else USER_SAVE_PATH
	if not FileAccess.file_exists(target):
		return _result(false, "Save file not found.")

	var text: String = FileAccess.get_file_as_string(target)
	if text.is_empty():
		return _result(false, "Save file is empty or unreadable.")

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _result(false, "Save file is not valid JSON.")

	var validation := validate_and_extract(parsed)
	if not validation["ok"]:
		return _result(false, validation["error"])

	var v: Dictionary = validation["values"]

	# ---- Transactional build on temporary objects -------------------------
	var temp_clock := GameClock.new()
	temp_clock.restore(v["Day"], v["Hour"], v["Minute"])

	var temp_player := PlayerState.new(temp_clock)
	temp_player.restore_values(
		v["Money"], v["Energy"], v["Hunger"], v["Thirst"], v["StudyXP"],
		v["IsSleeping"], v["IsWorking"], v["IsStudying"], v["IsPlaying"], v["IsSpendingFamilyTime"],
		v["AwakeMinutesAccumulator"], v["SleepingMinutesAccumulator"],
		v["HungerMinutesAccumulator"], v["ThirstMinutesAccumulator"],
		v["WorkMinutesAccumulator"], v["StudyMinutesAccumulator"],
		v["PlayMinutesAccumulator"], v["FamilyTimeMinutesAccumulator"]
	)
	temp_player.attributes.restore(v["Intelligence"], v["Fitness"], v["Social"], v["Discipline"], v["Creativity"])
	temp_player.skills.academics.restore(v["AcademicsExperience"])
	temp_player.education.restore(v["EducationStatus"], v["PrimaryGrade"], v["EducationProgress"], v["SchoolYearStartDay"])
	temp_player.traits.restore(v["Confidence"], v["Curiosity"], v["Patience"], v["Ambition"], v["Empathy"])

	if v["has_event_data"]:
		temp_player.restore_total_play_hours(v["TotalPlayHours"])
		temp_player.events.restore_history(v["EventHistory"])
		if v["CurrentEventId"] != null:
			temp_player.events.restore_pending(v["CurrentEventId"], v["CurrentEventTriggeredDay"])

	if v["has_family_data"]:
		temp_player.family.restore(
			Person.new(v["MotherId"], v["MotherName"], v["MotherBirthDay"], Person.Role.MOTHER),
			Person.new(v["FatherId"], v["FatherName"], v["FatherBirthDay"], Person.Role.FATHER)
		)
		temp_player.relationships.restore(
			Relationship.new(v["MotherId"], v["MotherCloseness"]),
			Relationship.new(v["FatherId"], v["FatherCloseness"])
		)

	# ---- Offline progression (O(1)) ---------------------------------------
	var now: float = now_unix if not is_nan(now_unix) else Time.get_unix_time_from_system()
	var elapsed_seconds: int = int(now - v["SavedAtUtc"])
	if elapsed_seconds < 0:
		elapsed_seconds = 0

	if elapsed_seconds > 0:
		var elapsed_minutes: int = elapsed_seconds * GameClock.MINUTES_PER_REAL_SECOND

		if not temp_clock.advance_game_minutes(elapsed_minutes):
			return _result(false, "Save time would overflow the game clock.")

		if not temp_player.preflight_work_and_study(elapsed_minutes)["ok"]:
			return _result(false, "Offline progression would overflow money or experience.")

		var rewards: Dictionary = temp_player.bulk_advance_simulation(elapsed_minutes)
		temp_player.apply_rewards(rewards["money_earned"], rewards["xp_earned"])
		temp_player.education.evaluate_progression(temp_clock.day)

	# Eligibility is evaluated ONCE against the final state; TriggeredDay is the
	# final current day.
	temp_player.events.evaluate_triggers(temp_clock.day)

	# ---- Commit to the live objects --------------------------------------
	clock.restore(temp_clock.day, temp_clock.hour, temp_clock.minute)
	player.restore_snapshot(temp_player.snapshot())
	player.attributes.restore(
		temp_player.attributes.intelligence, temp_player.attributes.fitness,
		temp_player.attributes.social, temp_player.attributes.discipline,
		temp_player.attributes.creativity
	)
	player.skills.academics.restore(temp_player.skills.academics.experience)
	player.education.restore(
		temp_player.education.status, temp_player.education.primary_grade,
		temp_player.education.education_progress, temp_player.education.school_year_start_day
	)
	player.traits.restore(
		temp_player.traits.confidence, temp_player.traits.curiosity, temp_player.traits.patience,
		temp_player.traits.ambition, temp_player.traits.empathy
	)
	player.family.restore(temp_player.family.mother, temp_player.family.father)
	player.relationships.restore(temp_player.relationships.mother_relationship, temp_player.relationships.father_relationship)
	player.restore_total_play_hours(temp_player.total_play_hours)
	player.events.clear_pending()
	player.events.restore_history(temp_player.events.duplicate_history())
	if temp_player.events.current_event != null:
		player.events.restore_pending(
			temp_player.events.current_event.event_id,
			temp_player.events.current_event.triggered_day
		)

	return {
		"ok": true,
		"error": "",
		"offline_seconds": elapsed_seconds,
		"offline_minutes": elapsed_seconds * GameClock.MINUTES_PER_REAL_SECOND,
	}


## Parses and validates a save dictionary. Returns {"ok", "error", "values"}.
static func validate_and_extract(data: Dictionary) -> Dictionary:
	var errors: PackedStringArray = []

	var version: int = _get_int(data, "Version", SaveData.VERSION, errors)
	if not SaveData.SUPPORTED_VERSIONS.has(version):
		return _result(false, "Unsupported save version %d." % version)

	var values: Dictionary = {"version": version}

	# ---- Basic fields -----------------------------------------------------
	values["Day"] = _get_int(data, "Day", 0, errors)
	values["Hour"] = _get_int(data, "Hour", 0, errors)
	values["Minute"] = _get_int(data, "Minute", 0, errors)
	values["Money"] = _get_int(data, "Money", 0, errors)
	values["Energy"] = _get_int(data, "Energy", 0, errors)
	values["Hunger"] = _get_int(data, "Hunger", 0, errors)
	values["Thirst"] = _get_int(data, "Thirst", 0, errors)
	values["StudyXP"] = _get_int(data, "StudyXP", 0, errors)
	values["IsSleeping"] = _get_bool(data, "IsSleeping", false, errors)
	values["IsWorking"] = _get_bool(data, "IsWorking", false, errors)
	values["IsStudying"] = _get_bool(data, "IsStudying", false, errors)
	values["IsPlaying"] = _get_bool(data, "IsPlaying", false, errors)
	values["IsSpendingFamilyTime"] = _get_bool(data, "IsSpendingFamilyTime", false, errors)
	for key in ACCUMULATOR_KEYS:
		values[key] = _get_int(data, key, 0, errors)

	if not errors.is_empty():
		return _result(false, "Save contains malformed fields: %s" % ", ".join(errors))

	if values["Day"] < 0:
		return _result(false, "Day must not be negative.")
	if values["Hour"] < 0 or values["Hour"] > 23:
		return _result(false, "Hour is out of range.")
	if values["Minute"] < 0 or values["Minute"] > 59:
		return _result(false, "Minute is out of range.")
	if values["Energy"] < 0 or values["Energy"] > 100:
		return _result(false, "Energy is out of range.")
	if values["Hunger"] < 0 or values["Hunger"] > 100:
		return _result(false, "Hunger is out of range.")
	if values["Thirst"] < 0 or values["Thirst"] > 100:
		return _result(false, "Thirst is out of range.")
	if values["Money"] < 0 or values["StudyXP"] < 0:
		return _result(false, "Money and StudyXP must not be negative.")
	for key in ACCUMULATOR_KEYS:
		if values[key] < 0 or values[key] >= 60:
			return _result(false, "%s is out of range." % key)

	var active_flags: int = 0
	for key in ["IsSleeping", "IsWorking", "IsStudying", "IsPlaying", "IsSpendingFamilyTime"]:
		if values[key]:
			active_flags += 1
	if active_flags > 1:
		return _result(false, "More than one activity is active.")

	var saved_at: float = SaveData.parse_utc(data.get("SavedAtUtc", null))
	if is_nan(saved_at):
		return _result(false, "SavedAtUtc is missing or invalid.")
	values["SavedAtUtc"] = saved_at

	# ---- Academics --------------------------------------------------------
	values["AcademicsExperience"] = _get_int(data, "AcademicsExperience", 0, errors)
	if not errors.is_empty():
		return _result(false, "Save contains malformed fields: %s" % ", ".join(errors))
	if values["AcademicsExperience"] < 0 or values["AcademicsExperience"] > SkillProgress.MAX_EXPERIENCE:
		return _result(false, "Academics experience is out of range.")

	# ---- Attributes (nullable in the reference; null means "use default") --
	for key in ["Intelligence", "Fitness", "Social", "Discipline", "Creativity"]:
		var raw: Variant = data.get(key, null)
		if raw == null:
			values[key] = PlayerAttributes.DEFAULT_VALUE
			continue
		if not _is_number(raw):
			return _result(false, "%s is not a number." % key)
		var attr_value: float = float(raw)
		if is_nan(attr_value) or is_inf(attr_value) or attr_value < 0.0 or attr_value > 100.0:
			return _result(false, "%s is out of range." % key)
		values[key] = attr_value

	# ---- Education (version 3+) -------------------------------------------
	values["EducationStatus"] = EducationState.Status.NOT_ENROLLED
	values["PrimaryGrade"] = 0
	values["EducationProgress"] = 0
	values["SchoolYearStartDay"] = 0
	if version >= 3:
		values["EducationStatus"] = _get_int(data, "EducationStatus", 0, errors)
		values["PrimaryGrade"] = _get_int(data, "PrimaryGrade", 0, errors)
		values["EducationProgress"] = _get_int(data, "EducationProgress", 0, errors)
		values["SchoolYearStartDay"] = _get_int(data, "SchoolYearStartDay", 0, errors)
		if not errors.is_empty():
			return _result(false, "Save contains malformed education fields.")
		if not _validate_education(
			values["EducationStatus"], values["PrimaryGrade"],
			values["EducationProgress"], values["SchoolYearStartDay"], values["Day"]
		):
			return _result(false, "Education state is invalid.")

	# ---- Traits (version 4+) ----------------------------------------------
	for key in ["Confidence", "Curiosity", "Patience", "Ambition", "Empathy"]:
		values[key] = PlayerTraits.DEFAULT_VALUE
	if version >= 4:
		if not errors.is_empty():
			return _result(false, "Save contains malformed fields: %s" % ", ".join(errors))
		for key in ["Confidence", "Curiosity", "Patience", "Ambition", "Empathy"]:
			var raw: Variant = data.get(key, null)
			if not _is_number(raw):
				return _result(false, "%s is not a number." % key)
			var trait_value: float = float(raw)
			if is_nan(trait_value) or is_inf(trait_value) or trait_value < 0.0 or trait_value > 100.0:
				return _result(false, "%s is out of range." % key)
			values[key] = trait_value

	# ---- Family (version 6+) ----------------------------------------------
	values["has_family_data"] = version >= 6
	values["has_event_data"] = version >= 7
	if version >= 6:
		values["MotherId"] = _get_uuid(data, "MotherId", errors)
		values["FatherId"] = _get_uuid(data, "FatherId", errors)
		values["MotherName"] = _get_string(data, "MotherName", "", errors)
		values["FatherName"] = _get_string(data, "FatherName", "", errors)
		values["MotherBirthDay"] = _get_int(data, "MotherBirthDay", 0, errors)
		values["FatherBirthDay"] = _get_int(data, "FatherBirthDay", 0, errors)
		values["MotherCloseness"] = _get_float(data, "MotherCloseness", 0.0, errors)
		values["FatherCloseness"] = _get_float(data, "FatherCloseness", 0.0, errors)
		values["MotherRelationshipPersonId"] = _get_uuid(data, "MotherRelationshipPersonId", errors)
		values["FatherRelationshipPersonId"] = _get_uuid(data, "FatherRelationshipPersonId", errors)

		if not errors.is_empty():
			return _result(false, "Save contains malformed family fields: %s" % ", ".join(errors))

		if Uuid.is_empty(values["MotherId"]) or Uuid.is_empty(values["FatherId"]) or values["MotherId"] == values["FatherId"]:
			return _result(false, "Parent identities are missing or duplicated.")
		if values["MotherName"].strip_edges().is_empty() or values["FatherName"].strip_edges().is_empty():
			return _result(false, "Parent names are missing.")
		if values["MotherBirthDay"] > values["Day"] or values["FatherBirthDay"] > values["Day"]:
			return _result(false, "A parent is born after the current day.")
		if not _is_valid_closeness(values["MotherCloseness"]) or not _is_valid_closeness(values["FatherCloseness"]):
			return _result(false, "Parent closeness is out of range.")
		if values["MotherRelationshipPersonId"] != values["MotherId"] or values["FatherRelationshipPersonId"] != values["FatherId"]:
			return _result(false, "Relationship cross-reference does not match parent identity.")

	# ---- Events + TotalPlayHours (version 7+) -----------------------------
	values["TotalPlayHours"] = 0
	values["CurrentEventId"] = null
	values["CurrentEventTriggeredDay"] = 0
	values["EventHistory"] = [] as Array[EventHistoryEntry]
	if version >= 7:
		values["TotalPlayHours"] = _get_int(data, "TotalPlayHours", 0, errors)
		if not errors.is_empty():
			return _result(false, "Save contains malformed event fields.")
		if values["TotalPlayHours"] < 0:
			return _result(false, "TotalPlayHours must not be negative.")

		var pending_raw: Variant = data.get("CurrentEventId", null)
		if pending_raw != null:
			if typeof(pending_raw) != TYPE_STRING or not LifeEventCatalog.is_known_event(pending_raw):
				return _result(false, "Pending event is unknown.")
			values["CurrentEventId"] = pending_raw
			values["CurrentEventTriggeredDay"] = _get_int(data, "CurrentEventTriggeredDay", 0, errors)
			if not errors.is_empty():
				return _result(false, "Save contains malformed pending event fields.")
			if values["CurrentEventTriggeredDay"] < 0 or values["CurrentEventTriggeredDay"] > values["Day"]:
				return _result(false, "Pending event trigger day is out of range.")

		var history_raw: Variant = data.get("EventHistory", [])
		if history_raw == null:
			history_raw = []
		if typeof(history_raw) != TYPE_ARRAY:
			return _result(false, "EventHistory is not an array.")

		var seen: Dictionary = {}
		var entries: Array[EventHistoryEntry] = []
		for entry in (history_raw as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				return _result(false, "EventHistory contains an invalid entry.")
			var event_id: Variant = entry.get("EventId", null)
			var choice_id: Variant = entry.get("ChoiceId", null)
			if typeof(event_id) != TYPE_STRING or not LifeEventCatalog.is_known_event(event_id):
				return _result(false, "EventHistory references an unknown event.")
			if typeof(choice_id) != TYPE_STRING or not LifeEventCatalog.is_known_choice(event_id, choice_id):
				return _result(false, "EventHistory references an invalid choice.")
			var triggered: int = _get_int(entry, "TriggeredDay", -1, errors)
			var resolved: int = _get_int(entry, "ResolvedDay", -1, errors)
			if not errors.is_empty():
				return _result(false, "EventHistory contains malformed day fields.")
			if triggered < 0:
				return _result(false, "EventHistory trigger day must not be negative.")
			if resolved < triggered:
				return _result(false, "EventHistory resolved before it triggered.")
			if resolved > values["Day"]:
				return _result(false, "EventHistory resolves in the future.")
			if seen.has(event_id):
				return _result(false, "EventHistory contains a duplicate one-shot event.")
			seen[event_id] = true
			entries.append(EventHistoryEntry.new(event_id, choice_id, triggered, resolved))

		if values["CurrentEventId"] != null and seen.has(values["CurrentEventId"]):
			return _result(false, "Pending event is already resolved in history.")
		values["EventHistory"] = entries

	return {"ok": true, "error": "", "values": values}


static func _validate_education(status: int, grade: int, progress: int, start_day: int, current_day: int) -> bool:
	if start_day < 0 or start_day > current_day:
		return false

	if status == EducationState.Status.NOT_ENROLLED:
		return grade == 0 and progress == 0 and start_day == 0
	if status == EducationState.Status.PRIMARY_SCHOOL:
		return grade >= 1 and grade <= EducationState.GRADE_COUNT and progress >= 0 and progress <= EducationState.PROGRESS_MAX
	if status == EducationState.Status.COMPLETED_PRIMARY:
		return grade == EducationState.GRADE_COUNT and progress == EducationState.PROGRESS_MAX
	return false


static func _is_valid_closeness(value: float) -> bool:
	return not (is_nan(value) or is_inf(value)) and value >= 0.0 and value <= 100.0


static func _result(ok: bool, error: String) -> Dictionary:
	return {
		"ok": ok,
		"error": error,
		"offline_seconds": 0,
		"offline_minutes": 0,
	}


static func _write_text(path: String, text: String) -> Dictionary:
	var base_dir: String = path.get_base_dir()
	if not base_dir.is_empty() and not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not write %s (error %d)." % [path, FileAccess.get_open_error()]}
	file.store_string(text)
	file.close()
	return {"ok": true, "error": "", "path": path}


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _get_int(data: Dictionary, key: String, default_value: int, errors: PackedStringArray) -> int:
	if not data.has(key):
		return default_value
	var value: Variant = data[key]
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and float(value) == floor(float(value)):
		return int(value)
	errors.append(key)
	return default_value


static func _get_float(data: Dictionary, key: String, default_value: float, errors: PackedStringArray) -> float:
	if not data.has(key):
		return default_value
	var value: Variant = data[key]
	if _is_number(value):
		return float(value)
	errors.append(key)
	return default_value


static func _get_bool(data: Dictionary, key: String, default_value: bool, errors: PackedStringArray) -> bool:
	if not data.has(key):
		return default_value
	var value: Variant = data[key]
	if typeof(value) == TYPE_BOOL:
		return value
	errors.append(key)
	return default_value


static func _get_string(data: Dictionary, key: String, default_value: String, errors: PackedStringArray) -> String:
	if not data.has(key):
		return default_value
	var value: Variant = data[key]
	if value == null:
		return ""
	if typeof(value) == TYPE_STRING:
		return value
	errors.append(key)
	return default_value


static func _get_uuid(data: Dictionary, key: String, errors: PackedStringArray) -> String:
	var value: Variant = data.get(key, null)
	if typeof(value) != TYPE_STRING:
		errors.append(key)
		return ""
	if not Uuid.is_valid(value) and not Uuid.is_empty(value):
		errors.append(key)
		return ""
	return value
