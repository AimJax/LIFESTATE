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
	var real_seconds: int = days * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND
	_clock.advance_seconds(real_seconds)
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
