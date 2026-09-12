class_name LifeStage
extends RefCounted

## Ported from LifeStage.cs. Stage is derived from Age and never stored.

enum Stage {
	INFANT,
	EARLY_CHILDHOOD,
	CHILD,
	TEEN,
	ADULT,
	ELDER,
}

const DISPLAY_NAMES: PackedStringArray = [
	"Infant",
	"EarlyChildhood",
	"Child",
	"Teen",
	"Adult",
	"Elder",
]


static func for_age(age: int) -> int:
	if age <= 1:
		return Stage.INFANT
	if age <= 5:
		return Stage.EARLY_CHILDHOOD
	if age <= 12:
		return Stage.CHILD
	if age <= 17:
		return Stage.TEEN
	if age <= 64:
		return Stage.ADULT
	return Stage.ELDER


static func display_name(stage: int) -> String:
	return DISPLAY_NAMES[stage]
