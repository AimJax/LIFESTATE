class_name PlayerFamily
extends RefCounted

## Ported from PlayerFamily.cs. Parents exist immediately at player birth:
## Mother is 28 and Father is 30 at Day 0, so BirthDay = -(age * 365).

const MOTHER_START_AGE: int = 28
const FATHER_START_AGE: int = 30

var mother: Person
var father: Person


func _init() -> void:
	mother = Person.new(Uuid.new_v4(), "Mother", -MOTHER_START_AGE * 365, Person.Role.MOTHER)
	father = Person.new(Uuid.new_v4(), "Father", -FATHER_START_AGE * 365, Person.Role.FATHER)


func restore(new_mother: Person, new_father: Person) -> bool:
	if new_mother == null or new_father == null:
		return false
	if Uuid.is_empty(new_mother.id) or Uuid.is_empty(new_father.id):
		return false
	if new_mother.id == new_father.id:
		return false
	if new_mother.role != Person.Role.MOTHER or new_father.role != Person.Role.FATHER:
		return false

	mother = new_mother
	father = new_father
	return true
