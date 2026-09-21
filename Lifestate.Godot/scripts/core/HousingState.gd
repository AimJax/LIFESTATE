class_name HousingState
extends RefCounted

## Mutable housing state: current home plus payment history. Independent from
## the immutable HousingCatalog definitions and from living-expense totals:
## housing outstanding never merges into living-expense outstanding.
##
## Fresh players live with their parents with zeroed counters. Moving never
## resets history; leaving a home keeps its unpaid balance on record.

const MIN_VALUE: int = 0
const MAX_VALUE: int = 9223372036854775807

var current_housing_id: String = HousingCatalog.PARENTS_ID
var total_paid: int = 0
var outstanding: int = 0
var missed_payments: int = 0
var moves_completed: int = 0


func current_definition() -> HousingDefinition:
	return HousingCatalog.get_by_id(current_housing_id)


## Applies one daily housing charge against available money. Never mutates the
## passed money directly: returns {"new_money": int} and records history
## internally. Zero charges are no-ops. Shortfalls never touch money and never
## partially pay: the full amount accrues to outstanding with one miss. No
## eviction, downgrade or repayment happens here.
func apply_daily_charge(housing_cost: int, available_money: int) -> Dictionary:
	if housing_cost <= 0:
		return {"new_money": available_money}
	if available_money >= housing_cost:
		total_paid = _saturating_add(total_paid, housing_cost)
		return {"new_money": available_money - housing_cost}
	outstanding = _saturating_add(outstanding, housing_cost)
	missed_payments = _saturating_add(missed_payments, 1)
	return {"new_money": available_money}


## God Mode / future-systems helper: clears the informational balance only.
## Current home, totals, money and clock are untouched.
func clear_outstanding() -> void:
	outstanding = 0


## Strict restore for the transactional save path. The housing id must be
## known and every counter non-negative; anything else rejects without
## mutating state. Note: parents + adult age is explicitly legal (no forced
## eviction on birthdays or migration).
func restore(
	p_housing_id: String, p_paid: int, p_outstanding: int, p_missed: int,
	p_moves: int
) -> bool:
	if not HousingCatalog.is_known_housing(p_housing_id):
		return false
	if p_paid < MIN_VALUE or p_outstanding < MIN_VALUE or p_missed < MIN_VALUE:
		return false
	if p_moves < MIN_VALUE:
		return false
	current_housing_id = p_housing_id
	total_paid = p_paid
	outstanding = p_outstanding
	missed_payments = p_missed
	moves_completed = p_moves
	return true


func to_dict() -> Dictionary:
	return {
		"housing_id": current_housing_id,
		"paid": total_paid,
		"outstanding": outstanding,
		"missed": missed_payments,
		"moves": moves_completed,
	}


static func _saturating_add(current: int, amount: int) -> int:
	if amount <= 0:
		return current
	if current >= MAX_VALUE - amount:
		return MAX_VALUE
	return current + amount
