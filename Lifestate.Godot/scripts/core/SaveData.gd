class_name SaveData
extends RefCounted

## Save schema, ported from SaveData.cs.
##
## The JSON field names are PascalCase and must stay byte-compatible with
## System.Text.Json output so a save written by the C# build loads here and
## vice versa. Do not rename or reorder-couple these keys to GDScript style.

const VERSION: int = 9
static var SUPPORTED_VERSIONS: PackedInt32Array = PackedInt32Array([2, 3, 4, 5, 6, 7, 8, 9])

static var HISTORY_KEYS: PackedStringArray = PackedStringArray([
	"EventId", "ChoiceId", "TriggeredDay", "ResolvedDay",
])


## Serializes live state to the C#-compatible dictionary. now_unix is UTC seconds.
static func to_dict(clock: GameClock, player: PlayerState, now_unix: float = NAN) -> Dictionary:
	var history: Array = []
	for entry in player.events.history:
		history.append({
			"EventId": entry.event_id,
			"ChoiceId": entry.choice_id,
			"TriggeredDay": entry.triggered_day,
			"ResolvedDay": entry.resolved_day,
		})

	var pending_id: Variant = null
	var pending_day: int = 0
	if player.events.current_event != null:
		pending_id = player.events.current_event.event_id
		pending_day = player.events.current_event.triggered_day

	var stamp: float = now_unix if not is_nan(now_unix) else Time.get_unix_time_from_system()

	return {
		"Version": VERSION,
		"Day": clock.day,
		"Hour": clock.hour,
		"Minute": clock.minute,
		"Money": player.money,
		"Energy": player.energy,
		"Hunger": player.hunger,
		"Thirst": player.thirst,
		"StudyXP": player.study_xp,
		"IsSleeping": player.is_sleeping,
		"IsWorking": player.is_working,
		"IsStudying": player.is_studying,
		"IsPlaying": player.is_playing,
		"IsSpendingFamilyTime": player.is_spending_family_time,
		"WorkMinutesAccumulator": player.get_work_minutes_accumulator(),
		"StudyMinutesAccumulator": player.get_study_minutes_accumulator(),
		"AwakeMinutesAccumulator": player.get_awake_minutes_accumulator(),
		"SleepingMinutesAccumulator": player.get_sleeping_minutes_accumulator(),
		"HungerMinutesAccumulator": player.get_hunger_minutes_accumulator(),
		"ThirstMinutesAccumulator": player.get_thirst_minutes_accumulator(),
		"PlayMinutesAccumulator": player.get_play_minutes_accumulator(),
		"FamilyTimeMinutesAccumulator": player.get_family_time_minutes_accumulator(),
		"AcademicsExperience": player.skills.academics.experience,
		"EducationStatus": player.education.status,
		"PrimaryGrade": player.education.primary_grade,
		"SecondaryGrade": player.education.secondary_grade,
		"EducationProgress": player.education.education_progress,
		"SchoolYearStartDay": player.education.school_year_start_day,
		"CurrentJobId": player.career.current_job_id,
		"TotalPlayHours": player.total_play_hours,
		"CurrentEventId": pending_id,
		"CurrentEventTriggeredDay": pending_day,
		"EventHistory": history,
		"MotherId": player.family.mother.id,
		"MotherName": player.family.mother.person_name,
		"MotherBirthDay": player.family.mother.birth_day,
		"FatherId": player.family.father.id,
		"FatherName": player.family.father.person_name,
		"FatherBirthDay": player.family.father.birth_day,
		"MotherRelationshipPersonId": player.relationships.mother_relationship.person_id,
		"MotherCloseness": player.relationships.mother_relationship.closeness,
		"FatherRelationshipPersonId": player.relationships.father_relationship.person_id,
		"FatherCloseness": player.relationships.father_relationship.closeness,
		"Confidence": player.traits.confidence,
		"Curiosity": player.traits.curiosity,
		"Patience": player.traits.patience,
		"Ambition": player.traits.ambition,
		"Empathy": player.traits.empathy,
		"Intelligence": player.attributes.intelligence,
		"Fitness": player.attributes.fitness,
		"Social": player.attributes.social,
		"Discipline": player.attributes.discipline,
		"Creativity": player.attributes.creativity,
		"SavedAtUtc": format_utc(stamp),
	}


## .NET-compatible UTC stamp: "yyyy-MM-ddTHH:mm:ss.fffffff+00:00".
static func format_utc(unix_seconds: float) -> String:
	var whole: int = int(floor(unix_seconds))
	var fraction: int = int(round((unix_seconds - float(whole)) * 10000000.0))
	if fraction >= 10000000:
		fraction = 9999999
	var parts: Dictionary = Time.get_datetime_dict_from_unix_time(whole)
	return "%04d-%02d-%02dT%02d:%02d:%02d.%07d+00:00" % [
		parts["year"], parts["month"], parts["day"],
		parts["hour"], parts["minute"], parts["second"], fraction,
	]


## Parses an ISO-8601 / .NET round-trip timestamp to UTC seconds.
## Returns NAN for anything unparseable. DateTimeOffset.MinValue (year 1) is
## treated as invalid, matching the C# "SavedAtUtc == MinValue" rejection.
static func parse_utc(value: Variant) -> float:
	if typeof(value) != TYPE_STRING:
		return NAN
	var text: String = (value as String).strip_edges()
	if text.is_empty():
		return NAN

	var t_index: int = text.find("T")
	if t_index < 0:
		t_index = text.find("t")
	if t_index < 0:
		return NAN

	var date_part: String = text.substr(0, t_index)
	var time_part: String = text.substr(t_index + 1)

	var date_bits: PackedStringArray = date_part.split("-")
	if date_bits.size() != 3:
		return NAN

	# Zone handling: trailing Z, or a +/-HH:MM offset.
	var offset_seconds: int = 0
	if time_part.ends_with("Z") or time_part.ends_with("z"):
		time_part = time_part.substr(0, time_part.length() - 1)
	else:
		var sign_index: int = maxi(time_part.find("+"), time_part.find("-"))
		if sign_index > 0:
			var offset_text: String = time_part.substr(sign_index + 1)
			var sign: int = 1 if time_part[sign_index] == "+" else -1
			time_part = time_part.substr(0, sign_index)
			var offset_bits: PackedStringArray = offset_text.split(":")
			if offset_bits.size() >= 2:
				offset_seconds = sign * (int(offset_bits[0]) * 3600 + int(offset_bits[1]) * 60)
			elif offset_bits.size() == 1:
				offset_seconds = sign * int(offset_bits[0]) * 3600
			else:
				return NAN

	var time_bits: PackedStringArray = time_part.split(":")
	if time_bits.size() < 2:
		return NAN

	var second_text: String = time_bits[2] if time_bits.size() >= 3 else "0"
	var fraction: float = 0.0
	var dot_index: int = second_text.find(".")
	if dot_index >= 0:
		fraction = float("0." + second_text.substr(dot_index + 1))
		second_text = second_text.substr(0, dot_index)

	var year: int = int(date_bits[0])
	var month: int = int(date_bits[1])
	var day: int = int(date_bits[2])
	var hour: int = int(time_bits[0])
	var minute: int = int(time_bits[1])
	var second: int = int(second_text)

	if year < 1970 or month < 1 or month > 12 or day < 1 or day > 31:
		return NAN
	if hour < 0 or hour > 23 or minute < 0 or minute > 59 or second < 0 or second > 60:
		return NAN
	if is_nan(fraction) or fraction < 0.0 or fraction >= 1.0:
		fraction = 0.0

	var unix: float = Time.get_unix_time_from_datetime_dict({
		"year": year, "month": month, "day": day,
		"hour": hour, "minute": minute, "second": second,
	})
	return unix - float(offset_seconds) + fraction
