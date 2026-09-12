class_name Person
extends RefCounted

## Ported from Person.cs. Identity is the stable Guid string; age is derived.

enum Role {
	MOTHER,
	FATHER,
}

var id: String = ""
var person_name: String = ""
var birth_day: int = 0
var role: int = Role.MOTHER


func _init(p_id: String = "", p_person_name: String = "", p_birth_day: int = 0, p_role: int = Role.MOTHER) -> void:
	id = p_id
	person_name = p_person_name
	birth_day = p_birth_day
	role = p_role


func get_age_for_day(current_day: int) -> int:
	var age: int = (current_day - birth_day) / 365
	if age < 0:
		age = 0
	return age


func get_age(clock: GameClock) -> int:
	return get_age_for_day(clock.day)


static func role_name(value: int) -> String:
	return "Mother" if value == Role.MOTHER else "Father"


func duplicate_person() -> Person:
	return Person.new(id, person_name, birth_day, role)
