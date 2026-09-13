class_name PlayerState
extends RefCounted

## Ported 1:1 from the C# reference implementation (PlayerState.cs).
##
## Sub-hour accumulators are load-bearing for simulation correctness: rewards
## only apply on completed hours while remainders carry across calls, so partial
## hours must never be dropped or simplified away.

const INT32_MAX: int = 2147483647
const INT64_MAX: int = 9223372036854775807

const NEEDS_MAX: int = 100
const MINUTES_PER_HOUR: int = 60

const STARTING_MONEY: int = 1000

# --- Rates (identical to the reference) ---
const ENERGY_PER_SLEEP_HOUR: int = 5
const ENERGY_PER_AWAKE_HOUR: int = 1
const HUNGER_PER_HOUR: int = 1
const THIRST_PER_HOUR: int = 2
## Historical flat work wage, kept for reference/legacy-tooling parity only.
## It no longer drives gameplay: work pay comes from the held JobDefinition
## (CareerState.hourly_wage). Laborer matches this value exactly.
const MONEY_PER_WORK_HOUR: int = 10
const STUDY_XP_PER_HOUR: int = 10
const INTELLIGENCE_PER_STUDY_HOUR: float = 0.05
const ACADEMICS_XP_PER_STUDY_HOUR: int = 10
const CURIOSITY_PER_STUDY_HOUR: float = 0.02
const PATIENCE_PER_STUDY_HOUR: float = 0.01
const AMBITION_PER_STUDY_HOUR: float = 0.01
const FITNESS_PER_PLAY_HOUR: float = 0.03
const CREATIVITY_PER_PLAY_HOUR: float = 0.03
const CONFIDENCE_PER_PLAY_HOUR: float = 0.02
const CURIOSITY_PER_PLAY_HOUR: float = 0.01
const CLOSENESS_PER_FAMILY_HOUR: float = 0.25
const SOCIAL_PER_FAMILY_HOUR: float = 0.02
const EMPATHY_PER_FAMILY_HOUR: float = 0.02
const CONFIDENCE_PER_FAMILY_HOUR: float = 0.01

const WORK_MIN_AGE: int = 18
const STUDY_MIN_AGE: int = 6
const PLAY_MIN_AGE: int = 2
const ENROLL_MIN_AGE: int = 6
const SECONDARY_ENROLL_MIN_AGE: int = 12

const MAX_EDUCATION_PROGRESS_PER_BULK: int = 100

var _clock: GameClock

var attributes: PlayerAttributes = PlayerAttributes.new()
var skills: PlayerSkills = PlayerSkills.new()
var education: EducationState = EducationState.new()
var traits: PlayerTraits = PlayerTraits.new()
var family: PlayerFamily = PlayerFamily.new()
var relationships: PlayerRelationships
var events: LifeEventSystem
var career: CareerState = CareerState.new()

var total_play_hours: int = 0
var money: int = STARTING_MONEY
var energy: int = NEEDS_MAX
var hunger: int = NEEDS_MAX
var thirst: int = NEEDS_MAX
var study_xp: int = 0

var is_sleeping: bool = false
var is_working: bool = false
var is_studying: bool = false
var is_playing: bool = false
var is_spending_family_time: bool = false

var _awake_minutes_accumulator: int = 0
var _sleeping_minutes_accumulator: int = 0
var _hunger_minutes_accumulator: int = 0
var _thirst_minutes_accumulator: int = 0
var _work_minutes_accumulator: int = 0
var _study_minutes_accumulator: int = 0
var _play_minutes_accumulator: int = 0
var _family_time_minutes_accumulator: int = 0


func _init(clock: GameClock) -> void:
	_clock = clock
	relationships = PlayerRelationships.new(family.mother.id, family.father.id)
	events = LifeEventSystem.new(self)


# =====================================================================
# Derived state
# =====================================================================

var age: int:
	get:
		return _clock.day / GameClock.DAYS_PER_YEAR

var life_stage: int:
	get:
		return LifeStage.for_age(age)

var life_stage_name: String:
	get:
		return LifeStage.display_name(life_stage)


## True when any exclusive activity is running.
func is_active() -> bool:
	return is_sleeping or is_working or is_studying or is_playing or is_spending_family_time


func current_activity_name() -> String:
	if is_sleeping:
		return "Sleeping"
	if is_working:
		return "Working"
	if is_studying:
		return "Studying"
	if is_playing:
		return "Playing"
	if is_spending_family_time:
		return "Family Time"
	return "Idle"


# =====================================================================
# Activity control (mutual exclusion preserved exactly)
# =====================================================================

func start_sleeping() -> void:
	if is_working or is_studying or is_playing or is_spending_family_time:
		return
	is_sleeping = true


func stop_sleeping() -> void:
	is_sleeping = false


func start_working() -> void:
	# Invariant: only an employed adult may Work. Hiring already enforced the
	# job's minimum age, but the check is preserved here defensively.
	if not career.is_employed() or age < WORK_MIN_AGE or is_sleeping or is_studying or is_playing or is_spending_family_time:
		return
	is_working = true


func stop_working() -> void:
	is_working = false


func start_studying() -> void:
	if age < STUDY_MIN_AGE or is_sleeping or is_working or is_playing or is_spending_family_time:
		return
	is_studying = true


func stop_studying() -> void:
	is_studying = false


func start_playing() -> bool:
	if age < PLAY_MIN_AGE or is_sleeping or is_working or is_studying or is_playing or is_spending_family_time:
		return false
	is_playing = true
	return true


func stop_playing() -> void:
	is_playing = false


func start_family_time() -> bool:
	if is_sleeping or is_working or is_studying or is_playing or is_spending_family_time:
		return false
	is_spending_family_time = true
	return true


func stop_family_time() -> void:
	is_spending_family_time = false


func enroll_primary_school() -> bool:
	if age < ENROLL_MIN_AGE:
		return false
	var enrolled: bool = education.try_enroll(_clock.day)
	if enrolled:
		# Enrolment can immediately make events eligible (First Day of School).
		events.evaluate_triggers(_clock.day)
	return enrolled

# =====================================================================
# Career (Godot-only post-migration system)
# =====================================================================

## Centralized deterministic job-requirement evaluation. UI reads the reason;
## apply_for_job enforces it. Never duplicate this logic in screens.
func evaluate_application(job_id: String) -> Dictionary:
	if not JobCatalog.is_known_job(job_id):
		return {"ok": false, "reason": "That job does not exist."}
	if career.is_employed():
		return {"ok": false, "reason": "Quit your current job first."}

	var job: JobDefinition = JobCatalog.get_by_id(job_id)
	if age < job.minimum_age:
		return {"ok": false, "reason": "You must be at least %d years old." % job.minimum_age}

	match job.education_requirement:
		JobDefinition.EducationRequirement.PRIMARY_COMPLETED:
			if education.status != EducationState.Status.COMPLETED_PRIMARY and education.status != EducationState.Status.COMPLETED_SECONDARY:
				return {"ok": false, "reason": "Complete primary school first."}
		JobDefinition.EducationRequirement.SECONDARY_COMPLETED:
			if education.status != EducationState.Status.COMPLETED_SECONDARY:
				return {"ok": false, "reason": "Complete secondary school first."}

	if not job.required_attribute.is_empty():
		var value: float = _attribute_value(job.required_attribute)
		if value < job.required_attribute_min:
			return {"ok": false, "reason": "%s must be at least %d." % [job.required_attribute.capitalize(), int(job.required_attribute_min)]}

	return {"ok": true, "reason": ""}


func can_apply(job_id: String) -> bool:
	return evaluate_application(job_id)["ok"]


## Deterministic hire: requirements met means hired immediately.
func apply_for_job(job_id: String) -> bool:
	if not evaluate_application(job_id)["ok"]:
		return false
	if not career.hire(job_id):
		return false
	events.evaluate_triggers(_clock.day)
	return true


## Quitting clears the job and stops an active Work session so the
## is_working == true while unemployed invariant can never hold.
func quit_job() -> bool:
	if not career.quit():
		return false
	if is_working:
		stop_working()
	return true


func _attribute_value(name: String) -> float:
	match name:
		"intelligence":
			return attributes.intelligence
		"social":
			return attributes.social
		"discipline":
			return attributes.discipline
	return 0.0


func enroll_secondary_school() -> bool:
	if age < SECONDARY_ENROLL_MIN_AGE:
		return false
	if education.status != EducationState.Status.COMPLETED_PRIMARY:
		return false
	var enrolled: bool = education.try_enroll_secondary(_clock.day)
	if enrolled:
		events.evaluate_triggers(_clock.day)
	return enrolled


func resolve_event_choice(choice_id: String) -> bool:
	return events.resolve_choice(choice_id, _clock.day)


# =====================================================================
# Needs
# =====================================================================

func update_energy(elapsed_minutes: int) -> void:
	if is_sleeping:
		_sleeping_minutes_accumulator += elapsed_minutes
		var hours_slept: int = _sleeping_minutes_accumulator / MINUTES_PER_HOUR
		if hours_slept > 0:
			energy = mini(NEEDS_MAX, energy + hours_slept * ENERGY_PER_SLEEP_HOUR)
			_sleeping_minutes_accumulator %= MINUTES_PER_HOUR
	else:
		_awake_minutes_accumulator += elapsed_minutes
		var hours_awake: int = _awake_minutes_accumulator / MINUTES_PER_HOUR
		if hours_awake > 0:
			energy = maxi(0, energy - hours_awake * ENERGY_PER_AWAKE_HOUR)
			_awake_minutes_accumulator %= MINUTES_PER_HOUR


func update_hunger(elapsed_minutes: int) -> void:
	_hunger_minutes_accumulator += elapsed_minutes
	var hours_passed: int = _hunger_minutes_accumulator / MINUTES_PER_HOUR
	if hours_passed > 0:
		hunger = maxi(0, hunger - hours_passed * HUNGER_PER_HOUR)
		_hunger_minutes_accumulator %= MINUTES_PER_HOUR


func update_thirst(elapsed_minutes: int) -> void:
	_thirst_minutes_accumulator += elapsed_minutes
	var hours_passed: int = _thirst_minutes_accumulator / MINUTES_PER_HOUR
	if hours_passed > 0:
		thirst = maxi(0, thirst - hours_passed * THIRST_PER_HOUR)
		_thirst_minutes_accumulator %= MINUTES_PER_HOUR


func eat(hunger_restored: int) -> void:
	if hunger_restored <= 0:
		return
	hunger = mini(NEEDS_MAX, hunger + hunger_restored)


func drink(thirst_restored: int) -> void:
	if thirst_restored <= 0:
		return
	thirst = mini(NEEDS_MAX, thirst + thirst_restored)


# =====================================================================
# Activity rewards
# =====================================================================

func update_work(elapsed_minutes: int) -> void:
	if not is_working:
		return

	_work_minutes_accumulator += elapsed_minutes
	var hours_worked: int = _work_minutes_accumulator / MINUTES_PER_HOUR
	if hours_worked > 0:
		money += hours_worked * career.hourly_wage()
		_work_minutes_accumulator %= MINUTES_PER_HOUR


func update_study(elapsed_minutes: int) -> void:
	if not is_studying:
		return

	_study_minutes_accumulator += elapsed_minutes
	var hours_studied: int = _study_minutes_accumulator / MINUTES_PER_HOUR
	if hours_studied > 0:
		study_xp += hours_studied * STUDY_XP_PER_HOUR
		attributes.add_intelligence(hours_studied * INTELLIGENCE_PER_STUDY_HOUR)
		skills.academics.add_experience(hours_studied * ACADEMICS_XP_PER_STUDY_HOUR)
		if education.status == EducationState.Status.PRIMARY_SCHOOL or education.status == EducationState.Status.SECONDARY_SCHOOL:
			education.add_progress(hours_studied)
			education.evaluate_progression(_clock.day)
		traits.add_curiosity(hours_studied * CURIOSITY_PER_STUDY_HOUR)
		traits.add_patience(hours_studied * PATIENCE_PER_STUDY_HOUR)
		traits.add_ambition(hours_studied * AMBITION_PER_STUDY_HOUR)
		_study_minutes_accumulator %= MINUTES_PER_HOUR


func update_play(elapsed_minutes: int) -> void:
	if not is_playing:
		return

	_play_minutes_accumulator += elapsed_minutes
	var hours_played: int = _play_minutes_accumulator / MINUTES_PER_HOUR
	if hours_played > 0:
		attributes.add_fitness(hours_played * FITNESS_PER_PLAY_HOUR)
		attributes.add_creativity(hours_played * CREATIVITY_PER_PLAY_HOUR)
		traits.add_confidence(hours_played * CONFIDENCE_PER_PLAY_HOUR)
		traits.add_curiosity(hours_played * CURIOSITY_PER_PLAY_HOUR)
		_play_minutes_accumulator %= MINUTES_PER_HOUR
		_add_total_play_hours_safely(hours_played)


func update_family_time(elapsed_minutes: int) -> void:
	if not is_spending_family_time:
		return

	_family_time_minutes_accumulator += elapsed_minutes
	var hours_spent: int = _family_time_minutes_accumulator / MINUTES_PER_HOUR
	if hours_spent > 0:
		relationships.mother_relationship.add_closeness(hours_spent * CLOSENESS_PER_FAMILY_HOUR)
		relationships.father_relationship.add_closeness(hours_spent * CLOSENESS_PER_FAMILY_HOUR)
		attributes.add_social(hours_spent * SOCIAL_PER_FAMILY_HOUR)
		traits.add_empathy(hours_spent * EMPATHY_PER_FAMILY_HOUR)
		traits.add_confidence(hours_spent * CONFIDENCE_PER_FAMILY_HOUR)
		_family_time_minutes_accumulator %= MINUTES_PER_HOUR


# =====================================================================
# Simulation stepping
# =====================================================================

func advance_simulation(minutes: int) -> void:
	update_energy(minutes)
	update_hunger(minutes)
	update_thirst(minutes)
	update_work(minutes)
	update_study(minutes)
	update_play(minutes)
	update_family_time(minutes)
	education.evaluate_progression(_clock.day)
	events.evaluate_triggers(_clock.day)


## O(1) offline/bulk progression using closed-form arithmetic — never a per-minute
## loop. Returns {"money_earned": int, "xp_earned": int}.
func bulk_advance_simulation(elapsed_minutes: int) -> Dictionary:
	var result := {"money_earned": 0, "xp_earned": 0}

	if elapsed_minutes <= 0:
		return result

	# Energy
	if is_sleeping:
		var total_slept: int = _sleeping_minutes_accumulator + elapsed_minutes
		var hours_slept: int = total_slept / MINUTES_PER_HOUR
		energy = mini(NEEDS_MAX, energy + hours_slept * ENERGY_PER_SLEEP_HOUR)
		_sleeping_minutes_accumulator = total_slept % MINUTES_PER_HOUR
	else:
		var total_awake: int = _awake_minutes_accumulator + elapsed_minutes
		var hours_awake: int = total_awake / MINUTES_PER_HOUR
		energy = maxi(0, energy - hours_awake * ENERGY_PER_AWAKE_HOUR)
		_awake_minutes_accumulator = total_awake % MINUTES_PER_HOUR

	# Hunger
	var total_hunger: int = _hunger_minutes_accumulator + elapsed_minutes
	var hours_hunger: int = total_hunger / MINUTES_PER_HOUR
	hunger = maxi(0, hunger - hours_hunger * HUNGER_PER_HOUR)
	_hunger_minutes_accumulator = total_hunger % MINUTES_PER_HOUR

	# Thirst
	var total_thirst: int = _thirst_minutes_accumulator + elapsed_minutes
	var hours_thirst: int = total_thirst / MINUTES_PER_HOUR
	thirst = maxi(0, thirst - hours_thirst * THIRST_PER_HOUR)
	_thirst_minutes_accumulator = total_thirst % MINUTES_PER_HOUR

	# Work/Study rewards are linear.
	if is_working:
		var total_work_minutes: int = _work_minutes_accumulator + elapsed_minutes
		result["money_earned"] = (total_work_minutes / MINUTES_PER_HOUR) * career.hourly_wage()
		_work_minutes_accumulator = total_work_minutes % MINUTES_PER_HOUR

	if is_studying:
		var total_study_minutes: int = _study_minutes_accumulator + elapsed_minutes
		var hours_studied: int = total_study_minutes / MINUTES_PER_HOUR
		result["xp_earned"] = hours_studied * STUDY_XP_PER_HOUR
		attributes.add_intelligence(hours_studied * INTELLIGENCE_PER_STUDY_HOUR)
		skills.academics.add_experience(hours_studied * ACADEMICS_XP_PER_STUDY_HOUR)
		if education.status == EducationState.Status.PRIMARY_SCHOOL or education.status == EducationState.Status.SECONDARY_SCHOOL:
			var education_hours: int = mini(hours_studied, MAX_EDUCATION_PROGRESS_PER_BULK)
			education.add_progress(education_hours)
		traits.add_curiosity(hours_studied * CURIOSITY_PER_STUDY_HOUR)
		traits.add_patience(hours_studied * PATIENCE_PER_STUDY_HOUR)
		traits.add_ambition(hours_studied * AMBITION_PER_STUDY_HOUR)
		_study_minutes_accumulator = total_study_minutes % MINUTES_PER_HOUR

	# Play rewards are linear and O(1).
	if is_playing:
		var total_play_minutes: int = _play_minutes_accumulator + elapsed_minutes
		var hours_played: int = total_play_minutes / MINUTES_PER_HOUR
		attributes.add_fitness(hours_played * FITNESS_PER_PLAY_HOUR)
		attributes.add_creativity(hours_played * CREATIVITY_PER_PLAY_HOUR)
		traits.add_confidence(hours_played * CONFIDENCE_PER_PLAY_HOUR)
		traits.add_curiosity(hours_played * CURIOSITY_PER_PLAY_HOUR)
		_play_minutes_accumulator = total_play_minutes % MINUTES_PER_HOUR
		_add_total_play_hours_safely(hours_played)

	# Family Time rewards are linear and O(1).
	if is_spending_family_time:
		var total_family_minutes: int = _family_time_minutes_accumulator + elapsed_minutes
		var hours_spent: int = total_family_minutes / MINUTES_PER_HOUR
		relationships.mother_relationship.add_closeness(hours_spent * CLOSENESS_PER_FAMILY_HOUR)
		relationships.father_relationship.add_closeness(hours_spent * CLOSENESS_PER_FAMILY_HOUR)
		attributes.add_social(hours_spent * SOCIAL_PER_FAMILY_HOUR)
		traits.add_empathy(hours_spent * EMPATHY_PER_FAMILY_HOUR)
		traits.add_confidence(hours_spent * CONFIDENCE_PER_FAMILY_HOUR)
		_family_time_minutes_accumulator = total_family_minutes % MINUTES_PER_HOUR

	education.evaluate_progression(_clock.day)
	events.evaluate_triggers(_clock.day)
	return result


## Preflight so a load can reject a save that would overflow the 32-bit money or
## XP accumulators instead of saturating silently. Returns
## {"ok": bool, "total_money": int, "total_xp": int}.
func preflight_work_and_study(elapsed_minutes: int) -> Dictionary:
	var total_money: int = money
	var total_xp: int = study_xp

	if is_working:
		var total_work_minutes: int = _work_minutes_accumulator + elapsed_minutes
		total_money += (total_work_minutes / MINUTES_PER_HOUR) * career.hourly_wage()

	if is_studying:
		var total_study_minutes: int = _study_minutes_accumulator + elapsed_minutes
		total_xp += (total_study_minutes / MINUTES_PER_HOUR) * STUDY_XP_PER_HOUR

	return {
		"ok": total_money <= INT32_MAX and total_xp <= INT32_MAX,
		"total_money": total_money,
		"total_xp": total_xp,
	}


func apply_rewards(money_earned: int, xp_earned: int) -> void:
	money += money_earned
	study_xp += xp_earned


# =====================================================================
# Controlled mutations
# =====================================================================

## Saturates at int.MaxValue (never wraps) and never goes below zero.
func add_money_safely(amount: int) -> void:
	money = clampi(money + amount, 0, INT32_MAX)


## Lifetime completed Play hours with safe saturation at long.MaxValue.
func _add_total_play_hours_safely(hours: int) -> void:
	if hours <= 0:
		return
	if hours >= INT64_MAX - total_play_hours:
		total_play_hours = INT64_MAX
	else:
		total_play_hours += hours


func restore_total_play_hours(hours: int) -> void:
	if hours < 0:
		return
	total_play_hours = hours


func debug_add_money(amount: int) -> void:
	if amount > 0:
		money += amount


func debug_restore_needs() -> void:
	energy = NEEDS_MAX
	hunger = NEEDS_MAX
	thirst = NEEDS_MAX


# =====================================================================
# Save/load support
# =====================================================================

## Complete mutable-state snapshot used by the transactional commit path.
func snapshot() -> Dictionary:
	return {
		"money": money,
		"energy": energy,
		"hunger": hunger,
		"thirst": thirst,
		"study_xp": study_xp,
		"is_sleeping": is_sleeping,
		"is_working": is_working,
		"is_studying": is_studying,
		"is_playing": is_playing,
		"is_spending_family_time": is_spending_family_time,
		"awake_minutes_accumulator": _awake_minutes_accumulator,
		"sleeping_minutes_accumulator": _sleeping_minutes_accumulator,
		"hunger_minutes_accumulator": _hunger_minutes_accumulator,
		"thirst_minutes_accumulator": _thirst_minutes_accumulator,
		"work_minutes_accumulator": _work_minutes_accumulator,
		"study_minutes_accumulator": _study_minutes_accumulator,
		"play_minutes_accumulator": _play_minutes_accumulator,
		"family_time_minutes_accumulator": _family_time_minutes_accumulator,
		"total_play_hours": total_play_hours,
	}


func restore_snapshot(state: Dictionary) -> void:
	restore_values(
		state["money"], state["energy"], state["hunger"], state["thirst"], state["study_xp"],
		state["is_sleeping"], state["is_working"], state["is_studying"], state["is_playing"],
		state["is_spending_family_time"],
		state["awake_minutes_accumulator"], state["sleeping_minutes_accumulator"],
		state["hunger_minutes_accumulator"], state["thirst_minutes_accumulator"],
		state["work_minutes_accumulator"], state["study_minutes_accumulator"],
		state["play_minutes_accumulator"], state["family_time_minutes_accumulator"]
	)
	restore_total_play_hours(state["total_play_hours"])


## Controlled restore. Parameter order matches the C# reference exactly.
func restore_values(
	p_money: int, p_energy: int, p_hunger: int, p_thirst: int, p_study_xp: int,
	p_is_sleeping: bool, p_is_working: bool, p_is_studying: bool, p_is_playing: bool,
	p_is_spending_family_time: bool,
	p_awake_minutes_accumulator: int, p_sleeping_minutes_accumulator: int,
	p_hunger_minutes_accumulator: int, p_thirst_minutes_accumulator: int,
	p_work_minutes_accumulator: int, p_study_minutes_accumulator: int,
	p_play_minutes_accumulator: int, p_family_time_minutes_accumulator: int
) -> void:
	money = p_money
	energy = p_energy
	hunger = p_hunger
	thirst = p_thirst
	study_xp = p_study_xp
	is_sleeping = p_is_sleeping
	is_working = p_is_working
	is_studying = p_is_studying
	is_playing = p_is_playing
	is_spending_family_time = p_is_spending_family_time
	_awake_minutes_accumulator = p_awake_minutes_accumulator
	_sleeping_minutes_accumulator = p_sleeping_minutes_accumulator
	_hunger_minutes_accumulator = p_hunger_minutes_accumulator
	_thirst_minutes_accumulator = p_thirst_minutes_accumulator
	_work_minutes_accumulator = p_work_minutes_accumulator
	_study_minutes_accumulator = p_study_minutes_accumulator
	_play_minutes_accumulator = p_play_minutes_accumulator
	_family_time_minutes_accumulator = p_family_time_minutes_accumulator


func get_awake_minutes_accumulator() -> int:
	return _awake_minutes_accumulator


func get_sleeping_minutes_accumulator() -> int:
	return _sleeping_minutes_accumulator


func get_hunger_minutes_accumulator() -> int:
	return _hunger_minutes_accumulator


func get_thirst_minutes_accumulator() -> int:
	return _thirst_minutes_accumulator


func get_work_minutes_accumulator() -> int:
	return _work_minutes_accumulator


func get_study_minutes_accumulator() -> int:
	return _study_minutes_accumulator


func get_play_minutes_accumulator() -> int:
	return _play_minutes_accumulator


func get_family_time_minutes_accumulator() -> int:
	return _family_time_minutes_accumulator
