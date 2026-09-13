class_name CareerState
extends RefCounted

## Runtime career state for one player: the currently held job. Unemployed is
## represented by an empty current_job_id (a state, not a fake job definition).
## Deterministic hiring only — no interviews, rejection chance or firing in the
## foundation ticket.

var current_job_id: String = ""


func is_employed() -> bool:
	return not current_job_id.is_empty()


func current_job() -> JobDefinition:
	if current_job_id.is_empty():
		return null
	return JobCatalog.get_by_id(current_job_id)


## Money earned per completed work hour with the current job. 0 when unemployed
## or if the held job no longer exists, so invalid state can never earn money.
func hourly_wage() -> int:
	var job := current_job()
	return job.hourly_wage if job != null else 0


## Hires into a known job. Fails while already employed (one job at a time).
func hire(job_id: String) -> bool:
	if is_employed() or not JobCatalog.is_known_job(job_id):
		return false
	current_job_id = job_id
	return true


## Clears the current job. Fails when already unemployed.
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
