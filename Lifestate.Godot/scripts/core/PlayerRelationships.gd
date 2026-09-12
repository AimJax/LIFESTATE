class_name PlayerRelationships
extends RefCounted

## Ported from PlayerRelationships.cs.

var mother_relationship: Relationship
var father_relationship: Relationship


func _init(mother_person_id: String = "", father_person_id: String = "") -> void:
	mother_relationship = Relationship.new(mother_person_id)
	father_relationship = Relationship.new(father_person_id)


func restore(new_mother: Relationship, new_father: Relationship) -> bool:
	if new_mother == null or new_father == null:
		return false
	if Uuid.is_empty(new_mother.person_id) or Uuid.is_empty(new_father.person_id):
		return false
	if new_mother.person_id == new_father.person_id:
		return false

	mother_relationship = new_mother
	father_relationship = new_father
	return true
