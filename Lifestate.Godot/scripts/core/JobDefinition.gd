class_name JobDefinition
extends RefCounted

## Immutable career content: one job. Definitions never mutate at runtime and
## are never serialized into saves — saves persist only the job id plus
## per-career rank/XP progress, and the catalog reconstructs the metadata.
##
## hourly_wage is the Rank 1 (hiring) wage, kept for the job-card display and
## hiring economics. The authoritative current wage is wage_at(rank), resolved
## through persisted CareerProgress — never duplicate rank/wage switches
## elsewhere; consume CareerState.hourly_wage() / current_title() instead.

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
## Ordered rank ladder, index 0 == Rank 1. Empty for legacy constructions;
## every catalog job defines exactly three ranks.
var ranks: Array[CareerRank] = []


func _init(
	p_id: String, p_display_name: String, p_description: String,
	p_hourly_wage: int, p_minimum_age: int,
	p_education_requirement: int = EducationRequirement.NONE,
	p_required_attribute: String = "", p_required_attribute_min: float = 0.0,
	p_ranks: Array[CareerRank] = []
) -> void:
	id = p_id
	display_name = p_display_name
	description = p_description
	hourly_wage = p_hourly_wage
	minimum_age = p_minimum_age
	education_requirement = p_education_requirement
	required_attribute = p_required_attribute
	required_attribute_min = p_required_attribute_min
	ranks = p_ranks


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


## Highest defined rank (3 for every catalog job). 1 when no ranks exist.
func max_rank() -> int:
	return ranks.size() if not ranks.is_empty() else 1


## Rank definition for 1-based rank, or null when out of range.
func rank_definition(p_rank: int) -> CareerRank:
	if p_rank < 1 or p_rank > ranks.size():
		return null
	return ranks[p_rank - 1]


## Resolved position title for a rank; falls back to the hiring title.
func title_at(p_rank: int) -> String:
	var definition := rank_definition(p_rank)
	return definition.title if definition != null else display_name


## Resolved hourly wage for a rank; falls back to the hiring wage.
func wage_at(p_rank: int) -> int:
	var definition := rank_definition(p_rank)
	return definition.wage if definition != null else hourly_wage
