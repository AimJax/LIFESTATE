class_name SkillProgress
extends RefCounted

## Ported from SkillProgress.cs. 100 experience per level, capped at 10000.

const MAX_EXPERIENCE: int = 10000
const EXPERIENCE_PER_LEVEL: int = 100

var experience: int = 0

var level: int:
	get:
		return experience / EXPERIENCE_PER_LEVEL


func add_experience(amount: int) -> void:
	if amount <= 0:
		return

	if amount >= MAX_EXPERIENCE - experience:
		experience = MAX_EXPERIENCE
	else:
		experience += amount


func restore(value: int) -> void:
	if value >= 0 and value <= MAX_EXPERIENCE:
		experience = value


func set_max() -> void:
	experience = MAX_EXPERIENCE
