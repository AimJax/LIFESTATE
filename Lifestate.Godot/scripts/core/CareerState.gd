class_name CareerState
extends RefCounted

## Runtime career state for one player: the currently held job plus
## independent progression history for every known career track.
## Unemployed is represented by an empty current_job_id (a state, not a fake
## job definition). Quitting never resets progress: rehiring restores the
## earned rank and XP immediately. Deterministic hiring only — no interviews,
## rejection chance or firing in the foundation tickets.

var current_job_id: String = ""

## Stable career id -> CareerProgress. Eagerly initialized for every known
## track so fresh players read Rank 1 / XP 0 without lazy branches.
var _progress: Dictionary = {}


func _init() -> void:
	_reset_progress()


func _reset_progress() -> void:
	_progress = {}
	for definition in JobCatalog.definitions():
		_progress[definition.id] = CareerProgress.new()


func is_employed() -> bool:
	return not current_job_id.is_empty()


func current_job() -> JobDefinition:
	if current_job_id.is_empty():
		return null
	return JobCatalog.get_by_id(current_job_id)


## Mutable progress for a career id, or null for unknown ids.
func progress_for(job_id: String) -> CareerProgress:
	return _progress.get(job_id)


func get_rank(job_id: String) -> int:
	var progress: CareerProgress = progress_for(job_id)
	return progress.rank if progress != null else CareerProgress.MIN_RANK


func get_experience(job_id: String) -> int:
	var progress: CareerProgress = progress_for(job_id)
	return progress.experience if progress != null else CareerProgress.MIN_EXPERIENCE


func current_rank() -> int:
	if current_job_id.is_empty():
		return CareerProgress.MIN_RANK
	return get_rank(current_job_id)


func current_experience() -> int:
	if current_job_id.is_empty():
		return CareerProgress.MIN_EXPERIENCE
	return get_experience(current_job_id)


## Authoritative current position title: the held track's rank title, or ""
## when unemployed. UI and simulation must consume this, never a local switch.
func current_title() -> String:
	var job := current_job()
	if job == null:
		return ""
	return job.title_at(current_rank())


## Money earned per completed work hour: the held track's CURRENT RANK wage.
## 0 when unemployed or if the held job no longer exists, so invalid state
## can never earn money.
func hourly_wage() -> int:
	var job := current_job()
	if job == null:
		return 0
	return job.wage_at(current_rank())


## Next-rank definition for the held career, or null at max rank / unemployed.
func next_rank_definition() -> CareerRank:
	var job := current_job()
	if job == null:
		return null
	return job.rank_definition(current_rank() + 1)


## Awards Career XP to one track (capped; unknown tracks ignored).
func award_experience(job_id: String, amount: int) -> void:
	var progress: CareerProgress = progress_for(job_id)
	if progress != null:
		progress.add_experience(amount)


## God Mode testing helper: pins one track's XP to the cap. Rank untouched.
func max_out_experience(job_id: String) -> bool:
	var progress: CareerProgress = progress_for(job_id)
	if progress == null:
		return false
	progress.max_out()
	return true


## Advances the held career exactly one rank. Fails when unemployed or at max
## rank. Never touches XP, money, attributes or the work accumulator.
func promote_current() -> bool:
	if current_job_id.is_empty():
		return false
	var progress: CareerProgress = progress_for(current_job_id)
	if progress == null:
		return false
	return progress.advance()


## Hires into a known job. Fails while already employed (one job at a time).
## Progress history is retained: rehiring restores the earned rank at once.
func hire(job_id: String) -> bool:
	if is_employed() or not JobCatalog.is_known_job(job_id):
		return false
	current_job_id = job_id
	return true


## Clears the current job. Fails when already unemployed. Progress history is
## deliberately retained so career history survives quitting.
func quit() -> bool:
	if not is_employed():
		return false
	current_job_id = ""
	return true


## Controlled restore used by the transactional save path. Unknown ids are
## rejected so a corrupted save can never install a nonexistent job.
func restore(job_id: String) -> bool:
	if job_id.is_empty():
		current_job_id = ""
		return true
	if not JobCatalog.is_known_job(job_id):
		return false
	current_job_id = job_id
	return true


## Internal progress snapshot: {career_id: {"rank": int, "experience": int}}.
func snapshot_progress() -> Dictionary:
	var state: Dictionary = {}
	for job_id in _progress:
		var progress: CareerProgress = _progress[job_id]
		state[job_id] = progress.to_dict()
	return state


## Strict all-or-nothing progress restore. The payload must carry exactly the
## known career ids with valid rank/XP pairs; anything else rejects WITHOUT
## mutating existing progress (transactional callers rely on this).
func restore_progress(state: Variant) -> bool:
	if typeof(state) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = state
	for definition in JobCatalog.definitions():
		if not data.has(definition.id):
			return false
		var entry: Variant = data[definition.id]
		if typeof(entry) != TYPE_DICTIONARY:
			return false
		if not (entry as Dictionary).has("rank") or not (entry as Dictionary).has("experience"):
			return false
		var entry_rank: Variant = (entry as Dictionary)["rank"]
		var entry_xp: Variant = (entry as Dictionary)["experience"]
		if typeof(entry_rank) != TYPE_INT or typeof(entry_xp) != TYPE_INT:
			return false
		var probe := CareerProgress.new()
		if not probe.restore(entry_rank, entry_xp):
			return false
	for definition in JobCatalog.definitions():
		var entry: Dictionary = data[definition.id]
		(_progress[definition.id] as CareerProgress).restore(entry["rank"], entry["experience"])
	return true
