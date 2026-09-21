class_name GodMode
extends RefCounted

## Ported from GodMode.cs. Developer-only helpers, gated behind is_enabled.
##
## Invariant preserved from the reference: time skips advance the clock and
## reevaluate event eligibility, but they do NOT simulate skipped needs or
## activity rewards.

var _clock: GameClock
var _player: PlayerState

var is_enabled: bool = false


func _init(clock: GameClock = null, player: PlayerState = null) -> void:
	_clock = clock
	_player = player


func set_enabled(enabled: bool) -> void:
	is_enabled = enabled


func advance_days(days: int) -> void:
	if not is_enabled:
		return
	# A dead player's clock is frozen at death; skips must not move it.
	if _player.is_dead:
		return
	var real_seconds: int = days * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND
	_clock.advance_seconds(real_seconds)
	# Skips are navigation/testing cheats: they must be predictable and must
	# NEVER kill. The mortality pointer is synced WITHOUT evaluating, so the
	# skipped days are marked as lived and only midnights crossed during real
	# engine time can roll old-age mortality.
	_player.sync_mortality_to_clock()
	# Time skips can make age-based events eligible (e.g. Found Money at age 8).
	_player.events.evaluate_triggers(_clock.day)


func add_money(amount: int) -> void:
	if not is_enabled:
		return
	_player.debug_add_money(amount)


func restore_needs() -> void:
	if not is_enabled:
		return
	_player.debug_restore_needs()


func max_attributes() -> void:
	if not is_enabled:
		return
	_player.attributes.set_all_max()


func max_skills() -> void:
	if not is_enabled:
		return
	_player.skills.academics.set_max()


func max_traits() -> void:
	if not is_enabled:
		return
	_player.traits.set_all_max()


# ---- Health / Death testing tools (Godot-only) ---------------------------

## Sets Health to an exact value (clamped 0..100). Rejected while dead —
## God Mode can provoke death but can never resurrect.
## Returns {"ok": bool, "message": String}.
func set_health(value: float) -> Dictionary:
	if not is_enabled:
		return {"ok": false, "message": "God Mode is disabled."}
	if _player.is_dead:
		return {"ok": false, "message": "Life has ended."}
	_player.debug_set_health(value)
	return {"ok": true, "message": "Health set to %d." % int(value)}


func set_hunger(value: int) -> Dictionary:
	if not is_enabled:
		return {"ok": false, "message": "God Mode is disabled."}
	if _player.is_dead:
		return {"ok": false, "message": "Life has ended."}
	_player.debug_set_hunger(value)
	return {"ok": true, "message": "Hunger set to %d." % value}


func set_thirst(value: int) -> Dictionary:
	if not is_enabled:
		return {"ok": false, "message": "God Mode is disabled."}
	if _player.is_dead:
		return {"ok": false, "message": "Life has ended."}
	_player.debug_set_thirst(value)
	return {"ok": true, "message": "Thirst set to %d." % value}


## Force Old Age Death: invokes the REAL centralized death transition so the
## terminal state is exactly what natural old-age mortality produces.
func force_old_age_death() -> Dictionary:
	if not is_enabled:
		return {"ok": false, "message": "God Mode is disabled."}
	if _player.is_dead:
		return {"ok": false, "message": "Life has ended."}
	_player.die(PlayerState.CAUSE_OLD_AGE)
	return {"ok": true, "message": "Life has ended. Cause: Old Age."}


## Career testing helper: pins the CURRENT career's XP to the cap without
## promoting, so promotion availability/acceptance can be tested directly.
## Other tracks, rank, attributes and money are untouched.
## Returns {"ok": bool, "message": String}.
func max_career_xp() -> Dictionary:
	if not is_enabled:
		return {"ok": false, "message": "God Mode is disabled."}
	if _player.is_dead:
		return {"ok": false, "message": "Life has ended."}
	if not _player.career.is_employed():
		return {"ok": false, "message": "You are not employed."}
	_player.career.max_out_experience(_player.career.current_job_id)
	return {"ok": true, "message": "Career XP set to 10000."}


## Economy testing helper: clears the informational outstanding balance so
## future economy systems can be tested from a clean slate. Totals, money,
## career, attributes and clock are untouched.
## Returns {"ok": bool, "message": String}.
func clear_economy_debt() -> Dictionary:
	if not is_enabled:
		return {"ok": false, "message": "God Mode is disabled."}
	if _player.is_dead:
		return {"ok": false, "message": "Life has ended."}
	_player.economy.clear_outstanding()
	return {"ok": true, "message": "Outstanding living expenses cleared."}


## Housing testing helper: clears the informational outstanding housing
## balance so future housing systems can be tested from a clean slate.
## Current home, totals, money and clock are untouched.
## Returns {"ok": bool, "message": String}.
func clear_housing_debt() -> Dictionary:
	if not is_enabled:
		return {"ok": false, "message": "God Mode is disabled."}
	if _player.is_dead:
		return {"ok": false, "message": "Life has ended."}
	_player.housing.clear_outstanding()
	return {"ok": true, "message": "Outstanding housing cleared."}


## Developer-only helper: satisfies the requirements of the current active
## school grade and then invokes the real progression logic so the player
## advances exactly one grade (or completes that tier).
##
## Returns {"ok": bool, "message": String}.
func complete_current_school_grade() -> Dictionary:
	if not is_enabled:
		return {"ok": false, "message": "God Mode is disabled."}

	var education: EducationState = _player.education
	var status: int = education.status

	if status == EducationState.Status.NOT_ENROLLED:
		return {"ok": false, "message": "Not currently enrolled in school."}
	if status == EducationState.Status.COMPLETED_PRIMARY:
		return {"ok": false, "message": "Primary school is already completed. Enroll in secondary school when eligible."}
	if status == EducationState.Status.COMPLETED_SECONDARY:
		return {"ok": false, "message": "Secondary school is already completed."}

	var is_primary: bool = status == EducationState.Status.PRIMARY_SCHOOL
	var grade: int = education.primary_grade if is_primary else education.secondary_grade
	var last_grade: int = EducationState.PRIMARY_LAST_GRADE if is_primary else EducationState.SECONDARY_LAST_GRADE

	var needed_progress: int = EducationState.PROGRESS_MAX - education.education_progress
	var needed_days: int = maxi(0, EducationState.DAYS_PER_SCHOOL_YEAR - (_clock.day - education.school_year_start_day))

	# Satisfy education progress without simulating studying.
	if needed_progress > 0:
		education.add_progress(needed_progress)
	# Advance clock by the minimum remaining school-year days, if any.
	if needed_days > 0:
		var real_seconds: int = needed_days * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND
		_clock.advance_seconds(real_seconds)
		_player.events.evaluate_triggers(_clock.day)

	# The authoritative progression path decides the outcome.
	education.evaluate_progression(_clock.day)

	var new_status: int = education.status
	var new_grade: int = education.primary_grade if education.status == EducationState.Status.PRIMARY_SCHOOL else education.secondary_grade
	var tier_name: String = "Primary" if is_primary else "Secondary"

	if new_status == EducationState.Status.COMPLETED_PRIMARY:
		return {"ok": true, "message": "Primary School completed."}
	if new_status == EducationState.Status.COMPLETED_SECONDARY:
		return {"ok": true, "message": "Secondary School completed."}
	return {"ok": true, "message": "Advanced to %s School Grade %d." % [tier_name, new_grade]}


## Explicit session wiring so the test harness can drive GodMode with a
## freshly constructed clock/player without needing the live autoload scene.
func wire_session(clock: GameClock, player: PlayerState) -> void:
	_clock = clock
	_player = player
