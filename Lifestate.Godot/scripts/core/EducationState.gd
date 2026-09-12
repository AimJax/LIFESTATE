class_name EducationState
extends RefCounted

## Ported from EducationState.cs. Primary school only: enrolment at age 6+,
## 100 progress units, one grade per 365-day academic year, grades 1..6.

enum Status {
	NOT_ENROLLED,
	PRIMARY_SCHOOL,
	COMPLETED_PRIMARY,
}

const GRADE_COUNT: int = 6
const PROGRESS_MAX: int = 100
const DAYS_PER_SCHOOL_YEAR: int = 365

var status: int = Status.NOT_ENROLLED
var primary_grade: int = 0
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


func add_progress(hours: int) -> void:
	if status != Status.PRIMARY_SCHOOL or hours <= 0:
		return
	education_progress = mini(PROGRESS_MAX, education_progress + hours)


## Advances grades. Bounded to GRADE_COUNT iterations, requires both the
## calendar year and 100 progress, and completes after grade 6.
func evaluate_progression(current_day: int) -> void:
	if status != Status.PRIMARY_SCHOOL:
		return

	for _i in range(GRADE_COUNT):
		if status != Status.PRIMARY_SCHOOL:
			break

		var calendar_eligible: bool = (current_day - school_year_start_day) >= DAYS_PER_SCHOOL_YEAR
		var progress_eligible: bool = education_progress >= PROGRESS_MAX

		if calendar_eligible and progress_eligible:
			if primary_grade < GRADE_COUNT:
				primary_grade += 1
				education_progress = 0
				school_year_start_day = current_day
			else:
				status = Status.COMPLETED_PRIMARY
				primary_grade = GRADE_COUNT
				education_progress = PROGRESS_MAX
				break
		else:
			break


## Defense-in-depth invariant protection. Invalid input is a no-op (false).
func restore(new_status: int, grade: int, progress: int, start_day: int) -> bool:
	if new_status == Status.NOT_ENROLLED:
		if grade != 0 or progress != 0 or start_day != 0:
			return false
	elif new_status == Status.PRIMARY_SCHOOL:
		if grade < 1 or grade > GRADE_COUNT or progress < 0 or progress > PROGRESS_MAX or start_day < 0:
			return false
	elif new_status == Status.COMPLETED_PRIMARY:
		if grade != GRADE_COUNT or progress != PROGRESS_MAX or start_day < 0:
			return false
	else:
		return false

	status = new_status
	primary_grade = grade
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
	return "Unknown"
