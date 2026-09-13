class_name JobCatalog
extends RefCounted

## Immutable known jobs. IDs are persistence-sensitive and must never be
## renamed, translated or reordered. Metadata is reconstructed from the id on
## load; saves never contain job definitions.

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
			10, 18
		),
		JobDefinition.new(
			RETAIL_WORKER_ID, "Retail Worker", "Serve customers on the shop floor.",
			12, 18,
			JobDefinition.EducationRequirement.PRIMARY_COMPLETED,
			"social", 15.0
		),
		JobDefinition.new(
			DELIVERY_DRIVER_ID, "Delivery Driver", "Move parcels around town.",
			15, 18,
			JobDefinition.EducationRequirement.PRIMARY_COMPLETED,
			"discipline", 20.0
		),
		JobDefinition.new(
			OFFICE_CLERK_ID, "Office Clerk", "Paperwork and schedules in a quiet office.",
			18, 18,
			JobDefinition.EducationRequirement.SECONDARY_COMPLETED,
			"intelligence", 20.0
		),
	]
