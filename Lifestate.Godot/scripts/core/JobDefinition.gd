class_name JobDefinition
extends RefCounted

## Immutable career content: one job. Definitions never mutate at runtime and
## are never serialized into saves — saves persist only the job id and the
## catalog reconstructs the metadata.

enum EducationRequirement {
	NONE,
	PRIMARY_COMPLETED,
	SECONDARY_COMPLETED,
}

var id: String
var display_name: String
var description: String
var hourly_wage: int
var minimum_age: int
var education_requirement: int = EducationRequirement.NONE
## "" for no attribute requirement, otherwise "intelligence" | "social" | "discipline".
var required_attribute: String = ""
var required_attribute_min: float = 0.0


func _init(
	p_id: String, p_display_name: String, p_description: String,
	p_hourly_wage: int, p_minimum_age: int,
	p_education_requirement: int = EducationRequirement.NONE,
	p_required_attribute: String = "", p_required_attribute_min: float = 0.0
) -> void:
	id = p_id
	display_name = p_display_name
	description = p_description
	hourly_wage = p_hourly_wage
	minimum_age = p_minimum_age
	education_requirement = p_education_requirement
	required_attribute = p_required_attribute
	required_attribute_min = p_required_attribute_min


## "" when the job has no education requirement.
func education_label() -> String:
	match education_requirement:
		EducationRequirement.PRIMARY_COMPLETED:
			return "Primary school completed"
		EducationRequirement.SECONDARY_COMPLETED:
			return "Secondary school completed"
	return ""


## "" when the job has no attribute requirement.
func attribute_label() -> String:
	if required_attribute.is_empty():
		return ""
	return "%s %d+" % [required_attribute.capitalize(), int(required_attribute_min)]
