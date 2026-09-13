class_name EducationState
extends RefCounted

## Primary and secondary school: 100 progress units and one 365-day academic
## year per grade.

enum Status {
	NOT_ENROLLED,
	PRIMARY_SCHOOL,
	COMPLETED_PRIMARY,
	SECONDARY_SCHOOL,
	COMPLETED_SECONDARY,
}

const PRIMARY_FIRST_GRADE: int = 1
const PRIMARY_LAST_GRADE: int = 6
const SECONDARY_FIRST_GRADE: int = 7
const SECONDARY_LAST_GRADE: int = 12
const PROGRESS_MAX: int = 100
const DAYS_PER_SCHOOL_YEAR: int = 365

var status: int = Status.NOT_ENROLLED
var primary_grade: int = 0
var secondary_grade: int = 0
var education_progress: int = 0
var school_year_start_day: int = 0


func try_enroll(current_day: int) -> bool:
	if status != Status.NOT_ENROLLED:
		return false

	status = Status.PRIMARY_SCHOOL
	primary_grade = 1
	education_progress = 0
	school_year_start_day = current_day
	return true

func try_enroll_secondary(current_day: int) -> bool:
	if status != Status.COMPLETED_PRIMARY:
		return false

	status = Status.SECONDARY_SCHOOL
	secondary_grade = SECONDARY_FIRST_GRADE
	education_progress = 0
	school_year_start_day = current_day
	return true


func add_progress(hours: int) -> void:
	if status != Status.PRIMARY_SCHOOL and status != Status.SECONDARY_SCHOOL:
		return
	if hours <= 0:
		return
	education_progress = mini(PROGRESS_MAX, education_progress + hours)


## Advances at most one grade because progress resets after advancement.
func evaluate_progression(current_day: int) -> void:
	if status != Status.PRIMARY_SCHOOL and status != Status.SECONDARY_SCHOOL:
		return
	if education_progress < PROGRESS_MAX or current_day - school_year_start_day < DAYS_PER_SCHOOL_YEAR:
		return

	var is_primary: bool = status == Status.PRIMARY_SCHOOL
	var grade: int = primary_grade if is_primary else secondary_grade
	var last_grade: int = PRIMARY_LAST_GRADE if is_primary else SECONDARY_LAST_GRADE
	if grade < last_grade:
		if is_primary:
			primary_grade += 1
		else:
			secondary_grade += 1
		education_progress = 0
		school_year_start_day = current_day
	else:
		status = Status.COMPLETED_PRIMARY if is_primary else Status.COMPLETED_SECONDARY
		education_progress = PROGRESS_MAX


## Defense-in-depth invariant protection. Invalid input is a no-op (false).
func restore(new_status: int, primary_grade: int, progress: int, start_day: int, secondary_grade: int = 0) -> bool:
	if new_status == Status.NOT_ENROLLED:
		if primary_grade != 0 or secondary_grade != 0 or progress != 0 or start_day != 0:
			return false
	elif new_status == Status.PRIMARY_SCHOOL:
		if primary_grade < 1 or primary_grade > PRIMARY_LAST_GRADE or secondary_grade != 0 or progress < 0 or progress > PROGRESS_MAX or start_day < 0:
			return false
	elif new_status == Status.COMPLETED_PRIMARY:
		if primary_grade != PRIMARY_LAST_GRADE or secondary_grade != 0 or progress != PROGRESS_MAX or start_day < 0:
			return false
	elif new_status == Status.SECONDARY_SCHOOL:
		if primary_grade != PRIMARY_LAST_GRADE or secondary_grade < SECONDARY_FIRST_GRADE or secondary_grade > SECONDARY_LAST_GRADE or progress < 0 or progress > PROGRESS_MAX or start_day < 0:
			return false
	elif new_status == Status.COMPLETED_SECONDARY:
		if primary_grade != PRIMARY_LAST_GRADE or secondary_grade != SECONDARY_LAST_GRADE or progress != PROGRESS_MAX or start_day < 0:
			return false
	else:
		return false

	status = new_status
	self.primary_grade = primary_grade
	self.secondary_grade = secondary_grade
	education_progress = progress
	school_year_start_day = start_day
	return true


static func display_name(value: int) -> String:
	match value:
		Status.NOT_ENROLLED:
			return "Not enrolled"
		Status.PRIMARY_SCHOOL:
			return "Currently enrolled"
		Status.COMPLETED_PRIMARY:
			return "Primary school completed"
		Status.SECONDARY_SCHOOL:
			return "Currently enrolled"
		Status.COMPLETED_SECONDARY:
			return "Secondary school completed"
	return "Unknown"
