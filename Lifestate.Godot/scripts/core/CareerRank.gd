class_name CareerRank
extends RefCounted

## Immutable single rank inside a career track. Rank 1 is the hiring rank and
## carries no promotion requirement (promotion_xp 0, empty attribute).
## Ranks 2+ carry the requirement to ENTER that rank: the player must hold at
## least promotion_xp total Career XP in this career plus the named attribute
## minimum. Definitions are never serialized; saves persist only progress.

var rank: int
var title: String
var wage: int
var promotion_xp: int = 0
var promotion_attribute: String = ""
var promotion_attribute_min: float = 0.0


func _init(
	p_rank: int, p_title: String, p_wage: int,
	p_promotion_xp: int = 0, p_promotion_attribute: String = "",
	p_promotion_attribute_min: float = 0.0
) -> void:
	rank = p_rank
	title = p_title
	wage = p_wage
	promotion_xp = p_promotion_xp
	promotion_attribute = p_promotion_attribute
	promotion_attribute_min = p_promotion_attribute_min


func is_entry_rank() -> bool:
	return rank == 1
