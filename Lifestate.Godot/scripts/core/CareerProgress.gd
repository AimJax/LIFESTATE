class_name CareerProgress
extends RefCounted

## Mutable per-career progression: rank 1..3 plus cumulative Career XP capped
## at MAX_EXPERIENCE. Promotion never spends XP: rank 2 requires 500 total XP
## and rank 3 requires 1500 total XP, so restore/validation enforce those
## minimums (attributes may drift after promotion, so they are NOT checked).

const MIN_RANK: int = 1
const MAX_RANK: int = 3
const MIN_EXPERIENCE: int = 0
const MAX_EXPERIENCE: int = 10000
const RANK_2_MIN_XP: int = 500
const RANK_3_MIN_XP: int = 1500

var rank: int = MIN_RANK
var experience: int = MIN_EXPERIENCE


## Adds XP toward the cap. Non-positive amounts are ignored; wages are never
## affected by the cap (Work always pays, XP merely stays at 10000).
func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	experience = mini(MAX_EXPERIENCE, experience + amount)


func max_out() -> void:
	experience = MAX_EXPERIENCE


## Advances exactly one rank. Fails at max rank; never touches experience.
func advance() -> bool:
	if rank >= MAX_RANK:
		return false
	rank += 1
	return true


## Strict restore: rejects out-of-range values and rank/XP combinations the
## production promotion path can never produce.
func restore(p_rank: int, p_experience: int) -> bool:
	if p_rank < MIN_RANK or p_rank > MAX_RANK:
		return false
	if p_experience < MIN_EXPERIENCE or p_experience > MAX_EXPERIENCE:
		return false
	if p_rank >= 2 and p_experience < RANK_2_MIN_XP:
		return false
	if p_rank >= 3 and p_experience < RANK_3_MIN_XP:
		return false
	rank = p_rank
	experience = p_experience
	return true


func to_dict() -> Dictionary:
	return {"rank": rank, "experience": experience}
