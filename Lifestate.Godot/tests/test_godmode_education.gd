extends RefCounted

## Regression coverage for GodMode.complete_current_school_grade().
## The tool satisfies the current grade's requirements and then invokes the
## real EducationState progression logic so exactly one grade advances (or a
## tier completes) with no study rewards and no needs simulation.

static func run(h: TestHarness) -> void:
	_meta(h)
	_gate(h)
	primary_grade_transitions(h)
	secondary_grade_transitions(h)
	partial_school_year(h)
	already_satisfied_year(h)
	no_study_rewards(h)
	no_needs_simulation(h)
	inactive_states_rejected(h)
	only_one_grade_per_call(h)


static func _meta(h: TestHarness) -> void:
	h.section("EduGod-M")
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	var god: GodMode = GodMode.new(clock, player)
	god.wire_session(clock, player)
	h.check("EduGod-M0 god_mode constructable", god != null)
	if not god != null:
		return
	h.eq_bool("EduGod-M1 method exists", _has_method(god, "complete_current_school_grade"), true)


static func _gate(h: TestHarness) -> void:
	h.section("EduGod-G")
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	var god: GodMode = GodMode.new(clock, player)
	god.wire_session(clock, player)
	var result: Dictionary = god.complete_current_school_grade()
	h.eq_bool("EduGod-G1 disabled tool returns failure", result["ok"], false)
	h.eq_string("EduGod-G2 disabled tool message", result["message"], "God Mode is disabled.")
	h.eq_int("EduGod-G3 disabled tool does not change grade", player.education.primary_grade, 0)
	h.eq_int("EduGod-G4 disabled tool does not change time", clock.day, 0)


static func primary_grade_transitions(h: TestHarness) -> void:
	h.section("EduGod-P")
	_grade_1_to_2(h)
	_grade_5_to_6(h)
	_grade_6_to_completed(h)


static func _grade_1_to_2(h: TestHarness) -> void:
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	var god: GodMode = GodMode.new(clock, player)
	god.wire_session(clock, player)
	god.set_enabled(true)
	advance_days(clock, 6 * 365)
	player.enroll_primary_school()
	h.eq_int("EduGod-P0 enrolled primary at grade 1", player.education.primary_grade, 1)
	god.complete_current_school_grade()
	h.eq_int("EduGod-P1 grade 1 -> 2", player.education.primary_grade, 2)
	h.eq_int("EduGod-P2 progress reset to 0", player.education.education_progress, 0)
	h.eq_int("EduGod-P3 school year restart recorded", player.education.school_year_start_day, clock.day)


static func _grade_5_to_6(h: TestHarness) -> void:
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	var god: GodMode = GodMode.new(clock, player)
	god.wire_session(clock, player)
	god.set_enabled(true)
	advance_days(clock, 6 * 365)
	player.enroll_primary_school()
	finish_grade(player, clock, 5)
	h.eq_int("EduGod-P4a reached grade 5", player.education.primary_grade, 5)
	god.complete_current_school_grade()
	h.eq_int("EduGod-P4 grade 5 -> 6", player.education.primary_grade, 6)


static func _grade_6_to_completed(h: TestHarness) -> void:
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	var god: GodMode = GodMode.new(clock, player)
	god.wire_session(clock, player)
	god.set_enabled(true)
	advance_days(clock, 6 * 365)
	player.enroll_primary_school()
	finish_grade(player, clock, 6)
	god.complete_current_school_grade()
	h.eq_int("EduGod-P5 grade 6 -> completed primary", player.education.status, EducationState.Status.COMPLETED_PRIMARY)
	h.eq_int("EduGod-P6 completed primary grade is 6", player.education.primary_grade, 6)
	h.eq_int("EduGod-P7 completed primary progress is 100", player.education.education_progress, 100)


static func secondary_grade_transitions(h: TestHarness) -> void:
	h.section("EduGod-S")
	_grade_7_to_8(h)
	_grade_11_to_12(h)
	_grade_12_to_completed(h)


static func _grade_7_to_8(h: TestHarness) -> void:
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	var god: GodMode = GodMode.new(clock, player)
	god.wire_session(clock, player)
	god.set_enabled(true)
	advance_days(clock, 12 * 365)
	player.enroll_primary_school()
	finish_primary(player, clock)
	h.eq_bool("EduGod-S0 enrolled secondary", player.enroll_secondary_school(), true)
	h.eq_int("EduGod-S1 secondary starts at grade 7", player.education.secondary_grade, 7)
	god.complete_current_school_grade()
	h.eq_int("EduGod-S2 grade 7 -> 8", player.education.secondary_grade, 8)
	h.eq_int("EduGod-S3 progress reset", player.education.education_progress, 0)


static func _grade_11_to_12(h: TestHarness) -> void:
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	var god: GodMode = GodMode.new(clock, player)
	god.wire_session(clock, player)
	god.set_enabled(true)
	advance_days(clock, 12 * 365)
	player.enroll_primary_school()
	finish_primary(player, clock)
	player.enroll_secondary_school()
	finish_grade(player, clock, 11)
	h.eq_int("EduGod-S4a reached grade 11", player.education.secondary_grade, 11)
	god.complete_current_school_grade()
	h.eq_int("EduGod-S4 grade 11 -> 12", player.education.secondary_grade, 12)


static func _grade_12_to_completed(h: TestHarness) -> void:
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	var god: GodMode = GodMode.new(clock, player)
	god.wire_session(clock, player)
	god.set_enabled(true)
	advance_days(clock, 12 * 365)
	player.enroll_primary_school()
	finish_primary(player, clock)
	player.enroll_secondary_school()
	finish_grade(player, clock, 12)
	god.complete_current_school_grade()
	h.eq_int("EduGod-S5 grade 12 -> completed secondary", player.education.status, EducationState.Status.COMPLETED_SECONDARY)
	h.eq_int("EduGod-S6 completed secondary grade is 12", player.education.secondary_grade, 12)
	h.eq_int("EduGod-S7 completed secondary progress is 100", player.education.education_progress, 100)


static func partial_school_year(h: TestHarness) -> void:
	h.section("EduGod-Y")
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	var god: GodMode = GodMode.new(clock, player)
	god.wire_session(clock, player)
	god.set_enabled(true)
	advance_days(clock, 6 * 365)
	player.enroll_primary_school()
	player.education.school_year_start_day = clock.day - 200
	player.education.education_progress = 50
	h.eq_int("EduGod-Y0 200/365 days elapsed", clock.day - player.education.school_year_start_day, 200)
	h.eq_int("EduGod-Y1 50/100 progress", player.education.education_progress, 50)
	var day_before: int = clock.day
	god.complete_current_school_grade()
	h.eq_int("EduGod-Y2 grade advanced to 2", player.education.primary_grade, 2)
	h.eq_int("EduGod-Y3 exactly 165 days advanced", clock.day - day_before, 165)


static func already_satisfied_year(h: TestHarness) -> void:
	h.section("EduGod-A")
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	var god: GodMode = GodMode.new(clock, player)
	god.wire_session(clock, player)
	god.set_enabled(true)
	advance_days(clock, 6 * 365)
	player.enroll_primary_school()
	player.education.school_year_start_day = clock.day - 365
	player.education.education_progress = 40
	h.eq_int("EduGod-A0 year already at 365/365", clock.day - player.education.school_year_start_day, 365)
	h.eq_int("EduGod-A1 progress below 100", player.education.education_progress, 40)
	var day_before: int = clock.day
	god.complete_current_school_grade()
	h.eq_int("EduGod-A2 grade advanced without extra year", player.education.primary_grade, 2)
	h.eq_int("EduGod-A3 no unnecessary days added", clock.day, day_before)
	h.eq_int("EduGod-A4 progress brought to 100 then reset", player.education.education_progress, 0)


static func no_study_rewards(h: TestHarness) -> void:
	h.section("EduGod-R")
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	var god: GodMode = GodMode.new(clock, player)
	god.wire_session(clock, player)
	god.set_enabled(true)
	advance_days(clock, 6 * 365)
	player.enroll_primary_school()
	var before: Dictionary = _rewards_before(player)
	god.complete_current_school_grade()
	h.eq_int("EduGod-R1 StudyXP unchanged", player.study_xp, before.study_xp)
	h.eq_int("EduGod-R2 Academics XP unchanged", player.skills.academics.experience, before.academics_xp)
	eq_float_near("EduGod-R3 Intelligence unchanged", player.attributes.intelligence, before.intelligence)
	eq_float_near("EduGod-R4 Curiosity unchanged", player.traits.curiosity, before.curiosity)
	eq_float_near("EduGod-R5 Patience unchanged", player.traits.patience, before.patience)
	eq_float_near("EduGod-R6 Ambition unchanged", player.traits.ambition, before.ambition)


static func no_needs_simulation(h: TestHarness) -> void:
	h.section("EduGod-N")
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	var god: GodMode = GodMode.new(clock, player)
	god.wire_session(clock, player)
	god.set_enabled(true)
	advance_days(clock, 6 * 365)
	player.enroll_primary_school()
	player.energy = 47
	player.hunger = 63
	player.thirst = 81
	player.money = 1234
	player.education.school_year_start_day = clock.day - 300
	player.education.education_progress = 20
	god.complete_current_school_grade()
	h.eq_int("EduGod-N1 energy unchanged", player.energy, 47)
	h.eq_int("EduGod-N2 hunger unchanged", player.hunger, 63)
	h.eq_int("EduGod-N3 thirst unchanged", player.thirst, 81)
	h.eq_int("EduGod-N4 money unchanged", player.money, 1234)


static func inactive_states_rejected(h: TestHarness) -> void:
	h.section("EduGod-I")
	_check_not_enrolled(h)
	_check_completed_primary(h)
	_check_completed_secondary(h)


static func _check_not_enrolled(h: TestHarness) -> void:
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	var god: GodMode = GodMode.new(clock, player)
	god.wire_session(clock, player)
	god.set_enabled(true)
	var result: Dictionary = god.complete_current_school_grade()
	h.eq_bool("EduGod-I1 not enrolled rejected", result["ok"], false)
	h.eq_string("EduGod-I2 not enrolled message", result["message"], "Not currently enrolled in school.")


static func _check_completed_primary(h: TestHarness) -> void:
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	var god: GodMode = GodMode.new(clock, player)
	god.wire_session(clock, player)
	god.set_enabled(true)
	advance_days(clock, 365)
	player.education.restore(EducationState.Status.COMPLETED_PRIMARY, 6, 100, clock.day - 365)
	var result: Dictionary = god.complete_current_school_grade()
	h.eq_bool("EduGod-I3 completed primary rejected", result["ok"], false)
	h.eq_string("EduGod-I4 completed primary message", result["message"], "Primary school is already completed. Enroll in secondary school when eligible.")


static func _check_completed_secondary(h: TestHarness) -> void:
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	var god: GodMode = GodMode.new(clock, player)
	god.wire_session(clock, player)
	god.set_enabled(true)
	advance_days(clock, 365)
	player.education.restore(EducationState.Status.COMPLETED_SECONDARY, 6, 100, clock.day - 365, 12)
	var result: Dictionary = god.complete_current_school_grade()
	h.eq_bool("EduGod-I5 completed secondary rejected", result["ok"], false)
	h.eq_string("EduGod-I6 completed secondary message", result["message"], "Secondary school is already completed.")


static func only_one_grade_per_call(h: TestHarness) -> void:
	h.section("EduGod-O")
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	var god: GodMode = GodMode.new(clock, player)
	god.wire_session(clock, player)
	god.set_enabled(true)
	advance_days(clock, 6 * 365)
	player.enroll_primary_school()
	finish_grade(player, clock, 4)
	player.education.school_year_start_day = clock.day - 250
	player.education.education_progress = 50
	h.eq_int("EduGod-O0 start grade 4", player.education.primary_grade, 4)
	god.complete_current_school_grade()
	h.eq_int("EduGod-O1 advanced once to grade 5", player.education.primary_grade, 5)
	h.eq_int("EduGod-O2 progress reset", player.education.education_progress, 0)
	h.eq_int("EduGod-O3 new school year recorded", player.education.school_year_start_day, clock.day)

	var nc := GameClock.new()
	var np := PlayerState.new(nc)
	god.wire_session(nc, np)
	god.set_enabled(true)
	nc.restore(clock.day, clock.hour, clock.minute)
	np.restore_snapshot(player.snapshot())
	np.attributes.restore(player.attributes.intelligence, player.attributes.fitness, player.attributes.social, player.attributes.discipline, player.attributes.creativity)
	np.skills.academics.restore(player.skills.academics.experience)
	np.traits.restore(player.traits.confidence, player.traits.curiosity, player.traits.patience, player.traits.ambition, player.traits.empathy)
	np.education.restore(player.education.status, player.education.primary_grade, player.education.education_progress, player.education.school_year_start_day)
	np.family.restore(player.family.mother, player.family.father)
	np.relationships.restore(player.relationships.mother_relationship, player.relationships.father_relationship)
	np.restore_total_play_hours(player.total_play_hours)
	np.events.clear_pending()
	np.events.restore_history(player.events.duplicate_history())
	god.complete_current_school_grade()
	h.eq_int("EduGod-O4 advanced once more to grade 6", np.education.primary_grade, 6)


static func _mark_done(h: TestHarness) -> void:
	h.section("EduGod-Done")


static func _has_method(node: Object, name: String) -> bool:
	return node != null and node.has_method(name)


static func _rewards_before(player: PlayerState) -> Dictionary:
	return {
		"study_xp": player.study_xp,
		"academics_xp": player.skills.academics.experience,
		"intelligence": player.attributes.intelligence,
		"curiosity": player.traits.curiosity,
		"patience": player.traits.patience,
		"ambition": player.traits.ambition,
	}


static func advance_days(clock: GameClock, days: int) -> void:
	clock.advance_seconds(days * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND)


static func fresh() -> Array:
	var clock := GameClock.new()
	return [clock, PlayerState.new(clock)]


static func finish_primary(player: PlayerState, clock: GameClock) -> void:
	var guard: int = 0
	while player.education.status == EducationState.Status.PRIMARY_SCHOOL and guard < 12:
		player.start_studying()
		player.advance_simulation(60 * 100)
		player.stop_studying()
		advance_days(clock, 365)
		player.education.evaluate_progression(clock.day)
		guard += 1


static func finish_grade(player: PlayerState, clock: GameClock, target_grade: int) -> void:
	var guard: int = 0
	while player.education.status == EducationState.Status.PRIMARY_SCHOOL and player.education.primary_grade < target_grade:
		player.start_studying()
		player.advance_simulation(60 * 100)
		player.stop_studying()
		advance_days(clock, 365)
		player.education.evaluate_progression(clock.day)
		guard += 1
		if guard > 12:
			return
	guard = 0
	while player.education.status == EducationState.Status.SECONDARY_SCHOOL and player.education.secondary_grade < target_grade:
		player.start_studying()
		player.advance_simulation(60 * 100)
		player.stop_studying()
		advance_days(clock, 365)
		player.education.evaluate_progression(clock.day)
		guard += 1
		if guard > 12:
			return


static func eq_float_near(name: String, actual: float, expected: float) -> bool:
	return absf(actual - expected) <= 0.000001
