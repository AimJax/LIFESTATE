class_name JobCatalog
extends RefCounted

## Immutable known jobs. IDs are persistence-sensitive and must never be
## renamed, translated or reordered. Metadata is reconstructed from the id on
## load; saves never contain job definitions.
##
## Each track carries exactly three ranks (hiring rank + two promotions).
## Promotion gates use total cumulative Career XP plus one attribute minimum;
## entry (hiring) requirements are unchanged by progression.

const LABORER_ID: String = "laborer"
const RETAIL_WORKER_ID: String = "retail_worker"
const DELIVERY_DRIVER_ID: String = "delivery_driver"
const OFFICE_CLERK_ID: String = "office_clerk"

static var _definitions: Array[JobDefinition] = []


static func definitions() -> Array[JobDefinition]:
	_ensure_definitions()
	return _definitions


static func get_by_id(job_id: String) -> JobDefinition:
	_ensure_definitions()
	for definition in _definitions:
		if definition.id == job_id:
			return definition
	return null


static func is_known_job(job_id: String) -> bool:
	return get_by_id(job_id) != null


static func _ensure_definitions() -> void:
	if not _definitions.is_empty():
		return

	_definitions = [
		JobDefinition.new(
			LABORER_ID, "Laborer", "General manual work.",
			10, 18,
			JobDefinition.EducationRequirement.NONE, "", 0.0,
			[
				CareerRank.new(1, "Laborer", 10),
				CareerRank.new(2, "Skilled Laborer", 15, 500, "fitness", 25.0),
				CareerRank.new(3, "Crew Leader", 22, 1500, "fitness", 40.0),
			]
		),
		JobDefinition.new(
			RETAIL_WORKER_ID, "Retail Worker", "Serve customers on the shop floor.",
			12, 18,
			JobDefinition.EducationRequirement.PRIMARY_COMPLETED,
			"social", 15.0,
			[
				CareerRank.new(1, "Retail Worker", 12),
				CareerRank.new(2, "Senior Associate", 17, 500, "social", 25.0),
				CareerRank.new(3, "Store Supervisor", 25, 1500, "social", 40.0),
			]
		),
		JobDefinition.new(
			DELIVERY_DRIVER_ID, "Delivery Driver", "Move parcels around town.",
			15, 18,
			JobDefinition.EducationRequirement.PRIMARY_COMPLETED,
			"discipline", 20.0,
			[
				CareerRank.new(1, "Delivery Driver", 15),
				CareerRank.new(2, "Senior Driver", 21, 500, "discipline", 30.0),
				CareerRank.new(3, "Route Supervisor", 29, 1500, "discipline", 45.0),
			]
		),
		JobDefinition.new(
			OFFICE_CLERK_ID, "Office Clerk", "Paperwork and schedules in a quiet office.",
			18, 18,
			JobDefinition.EducationRequirement.SECONDARY_COMPLETED,
			"intelligence", 20.0,
			[
				CareerRank.new(1, "Office Clerk", 18),
				CareerRank.new(2, "Senior Clerk", 25, 500, "intelligence", 30.0),
				CareerRank.new(3, "Office Supervisor", 35, 1500, "intelligence", 45.0),
			]
		),
	]
