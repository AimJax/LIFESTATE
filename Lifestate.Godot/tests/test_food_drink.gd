extends RefCounted

## Food & drink purchase foundation coverage: consumable definitions, the
## authoritative purchase path (meal/drink, exact money, clamping, statistics),
## all-or-nothing shortfalls, death guards, living-expense isolation,
## deprivation recovery, zero-time semantics, Save Version 13 persistence /
## migration / validation and transactional rejection.

const TEST_PATH: String = "user://test_food_drink.json"
const FIXED_NOW: float = 1794000000.0


static func fresh() -> Array:
	var clock := GameClock.new()
	return [clock, PlayerState.new(clock)]


static func run(h: TestHarness) -> void:
	_definitions(h)
	_meal(h)
	_drink(h)
	_shortfall(h)
	_death(h)
	_isolation(h)
	_recovery(h)
	_zero_time(h)
	_save_v13(h)
	_validation(h)


# =====================================================================
# Single-authority definitions
# =====================================================================

static func _definitions(h: TestHarness) -> void:
	h.section("Food-D")

	h.check("Food-D1 exactly two consumables exist", ConsumableCatalog.definitions().size() == 2)
	h.check("Food-D2 stable IDs", ConsumableCatalog.is_known_consumable("basic_meal")
		and ConsumableCatalog.is_known_consumable("basic_drink"))
	h.check("Food-D3 unknown ID rejected",
		not ConsumableCatalog.is_known_consumable("feast") and not ConsumableCatalog.is_known_consumable(""))

	var meal: ConsumableDefinition = ConsumableCatalog.get_by_id(ConsumableCatalog.BASIC_MEAL_ID)
	h.eq_string("Food-D4 meal display name", meal.display_name, "Basic Meal")
	h.eq_int("Food-D5 meal price", meal.price, 8)
	h.eq_int("Food-D6 meal restores hunger", meal.hunger_restored, 35)
	h.eq_int("Food-D7 meal restores no thirst", meal.thirst_restored, 0)

	var drink: ConsumableDefinition = ConsumableCatalog.get_by_id(ConsumableCatalog.BASIC_DRINK_ID)
	h.eq_string("Food-D8 drink display name", drink.display_name, "Basic Drink")
	h.eq_int("Food-D9 drink price", drink.price, 3)
	h.eq_int("Food-D10 drink restores thirst", drink.thirst_restored, 30)
	h.eq_int("Food-D11 drink restores no hunger", drink.hunger_restored, 0)


# =====================================================================
# Basic Meal purchases
# =====================================================================

static func _meal(h: TestHarness) -> void:
	h.section("Food-M")

	var pair := fresh()
	var player: PlayerState = pair[1]
	player.debug_set_hunger(40)
	var result: Dictionary = player.purchase_consumable(ConsumableCatalog.BASIC_MEAL_ID)
	h.eq_bool("Food-M1 purchase succeeds", result["ok"], true)
	h.eq_string("Food-M2 success message", result["message"], "Ate Basic Meal for $8.")
	h.eq_int("Food-M3 hunger restored", player.hunger, 75)
	h.eq_int("Food-M4 money reduced", player.money, 1000 - 8)
	h.eq_int("Food-M5 spending recorded", player.economy.food_drink_spent, 8)
	h.eq_int("Food-M6 meal counted", player.economy.meals_purchased, 1)
	h.eq_int("Food-M7 drinks untouched", player.economy.drinks_purchased, 0)

	# Exact money leaves zero without debt.
	player.money = 8
	player.debug_set_hunger(50)
	var exact: Dictionary = player.purchase_consumable(ConsumableCatalog.BASIC_MEAL_ID)
	h.eq_bool("Food-M8 exact money succeeds", exact["ok"], true)
	h.eq_int("Food-M9 exact money zeroes", player.money, 0)
	h.eq_int("Food-M10 hunger restored", player.hunger, 85)

	# Clamping wastes restoration but still charges full price.
	player.money = 100
	player.debug_set_hunger(90)
	h.check("Food-M11 clamped purchase succeeds",
		player.purchase_consumable(ConsumableCatalog.BASIC_MEAL_ID)["ok"])
	h.eq_int("Food-M12 hunger clamps at 100", player.hunger, 100)
	h.eq_int("Food-M13 full price still charged", player.money, 100 - 8)

	# Unknown items fail without mutation.
	var before: int = player.money
	var unknown: Dictionary = player.purchase_consumable("feast")
	h.eq_bool("Food-M14 unknown item fails", unknown["ok"], false)
	h.eq_int("Food-M15 unknown item keeps money", player.money, before)


# =====================================================================
# Basic Drink purchases
# =====================================================================

static func _drink(h: TestHarness) -> void:
	h.section("Food-K")

	var pair := fresh()
	var player: PlayerState = pair[1]
	player.debug_set_thirst(20)
	var result: Dictionary = player.purchase_consumable(ConsumableCatalog.BASIC_DRINK_ID)
	h.eq_bool("Food-K1 purchase succeeds", result["ok"], true)
	h.eq_string("Food-K2 success message", result["message"], "Drank Basic Drink for $3.")
	h.eq_int("Food-K3 thirst restored", player.thirst, 50)
	h.eq_int("Food-K4 money reduced", player.money, 1000 - 3)
	h.eq_int("Food-K5 spending recorded", player.economy.food_drink_spent, 3)
	h.eq_int("Food-K6 drink counted", player.economy.drinks_purchased, 1)
	h.eq_int("Food-K7 meals untouched", player.economy.meals_purchased, 0)

	player.money = 3
	player.debug_set_thirst(60)
	h.check("Food-K8 exact money succeeds",
		player.purchase_consumable(ConsumableCatalog.BASIC_DRINK_ID)["ok"])
	h.eq_int("Food-K9 exact money zeroes", player.money, 0)
	h.eq_int("Food-K10 thirst restored", player.thirst, 90)

	player.money = 100
	player.debug_set_thirst(95)
	h.check("Food-K11 clamped purchase succeeds",
		player.purchase_consumable(ConsumableCatalog.BASIC_DRINK_ID)["ok"])
	h.eq_int("Food-K12 thirst clamps at 100", player.thirst, 100)
	h.eq_int("Food-K13 full price still charged", player.money, 100 - 3)


# =====================================================================
# All-or-nothing shortfalls
# =====================================================================

static func _shortfall(h: TestHarness) -> void:
	h.section("Food-F")

	var pair := fresh()
	var player: PlayerState = pair[1]
	player.money = 7
	player.debug_set_hunger(40)
	player.debug_set_thirst(20)
	var meal: Dictionary = player.purchase_consumable(ConsumableCatalog.BASIC_MEAL_ID)
	h.eq_bool("Food-F1 short meal fails", meal["ok"], false)
	h.eq_string("Food-F2 shortfall message", meal["message"], "Not enough money.")
	h.eq_int("Food-F3 money unchanged", player.money, 7)
	h.eq_int("Food-F4 hunger unchanged", player.hunger, 40)
	h.eq_int("Food-F5 thirst unchanged", player.thirst, 20)
	h.eq_int("Food-F6 spending unchanged", player.economy.food_drink_spent, 0)
	h.eq_int("Food-F7 meals unchanged", player.economy.meals_purchased, 0)
	h.eq_int("Food-F8 no living-expense debt created", player.economy.outstanding, 0)
	h.eq_int("Food-F9 no missed payment created", player.economy.missed_payments, 0)

	player.money = 2
	var drink: Dictionary = player.purchase_consumable(ConsumableCatalog.BASIC_DRINK_ID)
	h.eq_bool("Food-F10 short drink fails", drink["ok"], false)
	h.eq_int("Food-F11 money unchanged", player.money, 2)
	h.eq_int("Food-F12 drinks unchanged", player.economy.drinks_purchased, 0)


# =====================================================================
# Death guards
# =====================================================================

static func _death(h: TestHarness) -> void:
	h.section("Food-X")

	var pair := fresh()
	var player: PlayerState = pair[1]
	player.debug_set_hunger(10)
	player.die(PlayerState.CAUSE_STARVATION)
	var meal: Dictionary = player.purchase_consumable(ConsumableCatalog.BASIC_MEAL_ID)
	h.eq_bool("Food-X1 dead meal fails", meal["ok"], false)
	h.eq_string("Food-X2 dead message", meal["message"], "Life has ended.")
	var drink: Dictionary = player.purchase_consumable(ConsumableCatalog.BASIC_DRINK_ID)
	h.eq_bool("Food-X3 dead drink fails", drink["ok"], false)
	h.eq_int("Food-X4 dead money frozen", player.money, 1000)
	h.eq_int("Food-X5 dead hunger frozen", player.hunger, 10)
	h.eq_int("Food-X6 dead spending frozen", player.economy.food_drink_spent, 0)


# =====================================================================
# Living-expense isolation
# =====================================================================

static func _isolation(h: TestHarness) -> void:
	h.section("Food-I")

	var pair := fresh()
	var player: PlayerState = pair[1]
	player.debug_set_hunger(40)
	h.check("Food-I1 purchase succeeds", player.purchase_consumable(ConsumableCatalog.BASIC_MEAL_ID)["ok"])
	h.eq_int("Food-I2 living paid untouched", player.economy.total_paid, 0)
	h.eq_int("Food-I3 outstanding untouched", player.economy.outstanding, 0)
	h.eq_int("Food-I4 missed untouched", player.economy.missed_payments, 0)

	# Outstanding living expenses never block an affordable purchase.
	player.economy.restore(50, 100, 3)
	player.money = 20
	player.debug_set_hunger(40)
	var result: Dictionary = player.purchase_consumable(ConsumableCatalog.BASIC_MEAL_ID)
	h.eq_bool("Food-I5 purchase with debt succeeds", result["ok"], true)
	h.eq_int("Food-I6 cash reduced", player.money, 12)
	h.eq_int("Food-I7 outstanding unchanged", player.economy.outstanding, 100)
	h.eq_int("Food-I8 living paid unchanged", player.economy.total_paid, 50)
	h.eq_int("Food-I9 missed unchanged", player.economy.missed_payments, 3)


# =====================================================================
# Deprivation recovery through the controlled restoration path
# =====================================================================

static func _recovery(h: TestHarness) -> void:
	h.section("Food-R")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	player.debug_set_hunger(0)
	player.debug_set_thirst(100)
	player.advance_simulation(45)
	h.eq_int("Food-R1 streak accumulates pre-purchase", player.get_starving_minutes_accumulator(), 45)
	h.check("Food-R2 meal purchase succeeds",
		player.purchase_consumable(ConsumableCatalog.BASIC_MEAL_ID)["ok"])
	h.eq_int("Food-R3 hunger revived", player.hunger, 35)
	h.eq_int("Food-R4 streak resets", player.get_starving_minutes_accumulator(), 0)
	player.advance_simulation(60)
	h.near_float("Food-R5 no stale starvation damage", player.health, 100.0)
	h.eq_int("Food-R6 hunger drains normally", player.hunger, 34)

	var thirst_pair := fresh()
	var thirsty: PlayerState = thirst_pair[1]
	thirsty.debug_set_thirst(0)
	thirsty.debug_set_hunger(100)
	thirsty.advance_simulation(45)
	h.check("Food-R7 drink purchase succeeds",
		thirsty.purchase_consumable(ConsumableCatalog.BASIC_DRINK_ID)["ok"])
	h.eq_int("Food-R8 thirst revived", thirsty.thirst, 30)
	h.eq_int("Food-R9 streak resets", thirsty.get_dehydrated_minutes_accumulator(), 0)
	thirsty.advance_simulation(60)
	h.near_float("Food-R10 no stale dehydration damage", thirsty.health, 100.0)
	h.eq_int("Food-R11 thirst drains normally", thirsty.thirst, 28)


# =====================================================================
# Purchases advance zero time and disturb no activity
# =====================================================================

static func _zero_time(h: TestHarness) -> void:
	h.section("Food-Z")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	clock.restore(500, 12, 30)
	player.debug_set_hunger(40)
	player.purchase_consumable(ConsumableCatalog.BASIC_MEAL_ID)
	h.eq_int("Food-Z1 clock day frozen", clock.day, 500)
	h.eq_int("Food-Z2 clock time frozen", clock.hour * 60 + clock.minute, 12 * 60 + 30)

	# Work continues straight through a purchase.
	var work_pair := fresh()
	var work_clock: GameClock = work_pair[0]
	var worker: PlayerState = work_pair[1]
	work_clock.restore(18 * 365, 9, 0)
	worker.apply_for_job(JobCatalog.LABORER_ID)
	worker.start_working()
	worker.debug_set_hunger(40)
	worker.purchase_consumable(ConsumableCatalog.BASIC_MEAL_ID)
	h.eq_bool("Food-Z3 Work continues", worker.is_working, true)
	h.eq_int("Food-Z4 work accumulator untouched", worker.get_work_minutes_accumulator(), 0)
	h.eq_int("Food-Z5 clock untouched", work_clock.hour * 60 + work_clock.minute, 9 * 60)


# =====================================================================
# Save Version 13 persistence and migration
# =====================================================================

static func _save_v13(h: TestHarness) -> void:
	h.section("Food-S")

	var pair := fresh()
	var player: PlayerState = pair[1]
	player.debug_set_hunger(10)
	player.debug_set_thirst(10)
	for _i in range(5):
		player.purchase_consumable(ConsumableCatalog.BASIC_MEAL_ID)
		player.debug_set_hunger(10)
	for _i in range(2):
		player.purchase_consumable(ConsumableCatalog.BASIC_DRINK_ID)
		player.debug_set_thirst(10)
	player.economy.restore(500, 20, 2,
		player.economy.food_drink_spent, player.economy.meals_purchased, player.economy.drinks_purchased)
	SaveManager.save_game(pair[0], player, TEST_PATH, FIXED_NOW)

	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	h.eq_int("Food-S1 save version is exactly 13", raw["Version"], 13)
	var stored: Dictionary = raw["Economy"]
	h.eq_int("Food-S2 spent persisted", stored["FoodDrinkSpent"], 5 * 8 + 2 * 3)
	h.eq_int("Food-S3 meals persisted", stored["MealsPurchased"], 5)
	h.eq_int("Food-S4 drinks persisted", stored["DrinksPurchased"], 2)
	h.eq_int("Food-S5 living paid persisted", stored["TotalLivingExpensesPaid"], 500)

	var loaded := fresh()
	var load_result: Dictionary = SaveManager.load_game(loaded[0], loaded[1], TEST_PATH, FIXED_NOW)
	h.check("Food-S6 load succeeds", load_result["ok"], load_result["error"])
	h.eq_int("Food-S7 spent round trips", loaded[1].economy.food_drink_spent, 46)
	h.eq_int("Food-S8 meals round trip", loaded[1].economy.meals_purchased, 5)
	h.eq_int("Food-S9 drinks round trip", loaded[1].economy.drinks_purchased, 2)
	h.eq_int("Food-S10 living paid intact", loaded[1].economy.total_paid, 500)
	h.eq_int("Food-S11 outstanding intact", loaded[1].economy.outstanding, 20)
	h.eq_int("Food-S12 missed intact", loaded[1].economy.missed_payments, 2)

	# v12 migration: new counters default to zero, living totals intact.
	var v12_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	v12_data["Version"] = 12
	(v12_data["Economy"] as Dictionary).erase("FoodDrinkSpent")
	(v12_data["Economy"] as Dictionary).erase("MealsPurchased")
	(v12_data["Economy"] as Dictionary).erase("DrinksPurchased")
	_write(TEST_PATH, JSON.stringify(v12_data))
	var migrated := fresh()
	var migrate_result: Dictionary = SaveManager.load_game(migrated[0], migrated[1], TEST_PATH, FIXED_NOW)
	h.check("Food-S13 v12 save still loads", migrate_result["ok"], migrate_result["error"])
	h.eq_int("Food-S14 v12 spent defaults to 0", migrated[1].economy.food_drink_spent, 0)
	h.eq_int("Food-S15 v12 meals default to 0", migrated[1].economy.meals_purchased, 0)
	h.eq_int("Food-S16 v12 drinks default to 0", migrated[1].economy.drinks_purchased, 0)
	h.eq_int("Food-S17 v12 living paid intact", migrated[1].economy.total_paid, 500)


# =====================================================================
# Version 13 validation and transactional rejection
# =====================================================================

static func _validation(h: TestHarness) -> void:
	h.section("Food-V")

	var pair := fresh()
	SaveManager.save_game(pair[0], pair[1], TEST_PATH, FIXED_NOW)
	var base_text: String = FileAccess.get_file_as_string(TEST_PATH)

	# Live state that must survive every rejected load untouched.
	var live := fresh()
	var live_clock: GameClock = live[0]
	var live_player: PlayerState = live[1]
	live_player.money = 4242
	live_player.debug_set_hunger(40)
	live_player.purchase_consumable(ConsumableCatalog.BASIC_MEAL_ID)
	live_player.economy.restore(50, 20, 2, 46, 5, 2)
	live_clock.restore(4321, 7, 8)

	var cases: Array = [
		["negative spent", {"__econ__": ["FoodDrinkSpent", -1]}],
		["negative meals", {"__econ__": ["MealsPurchased", -1]}],
		["negative drinks", {"__econ__": ["DrinksPurchased", -1]}],
		["fractional spent", {"__econ__": ["FoodDrinkSpent", 46.5]}],
		["string meals", {"__econ__": ["MealsPurchased", "5"]}],
		["null drinks", {"__econ__": ["DrinksPurchased", null]}],
		["boolean spent", {"__econ__": ["FoodDrinkSpent", true]}],
		["overflow meals", {"__econ__": ["MealsPurchased", 1.0e30]}],
		["missing spent", {"__erase_econ__": "FoodDrinkSpent"}],
		["missing meals", {"__erase_econ__": "MealsPurchased"}],
		["missing drinks", {"__erase_econ__": "DrinksPurchased"}],
	]
	for entry in cases:
		var data: Dictionary = JSON.parse_string(base_text)
		_apply_patch(data, entry[1])
		_write(TEST_PATH, JSON.stringify(data))
		var result: Dictionary = SaveManager.load_game(live_clock, live_player, TEST_PATH, FIXED_NOW)
		h.eq_bool("Food-V rejects %s" % entry[0], result["ok"], false)

	h.eq_int("Food-V live clock untouched", live_clock.day, 4321)
	h.eq_int("Food-V live money untouched", live_player.money, 4242 - 8)
	h.eq_int("Food-V live hunger untouched", live_player.hunger, 75)
	h.eq_int("Food-V live paid untouched", live_player.economy.total_paid, 50)
	h.eq_int("Food-V live outstanding untouched", live_player.economy.outstanding, 20)
	h.eq_int("Food-V live missed untouched", live_player.economy.missed_payments, 2)
	h.eq_int("Food-V live spent untouched", live_player.economy.food_drink_spent, 46)
	h.eq_int("Food-V live meals untouched", live_player.economy.meals_purchased, 5)
	h.eq_int("Food-V live drinks untouched", live_player.economy.drinks_purchased, 2)

	# Whole-float interop still loads.
	var whole: Dictionary = JSON.parse_string(base_text)
	(whole["Economy"] as Dictionary)["MealsPurchased"] = 5.0
	_write(TEST_PATH, JSON.stringify(whole))
	var whole_loaded := fresh()
	h.check("Food-V whole-float counts load",
		SaveManager.load_game(whole_loaded[0], whole_loaded[1], TEST_PATH, FIXED_NOW)["ok"])


static func _apply_patch(data: Dictionary, patch: Dictionary) -> void:
	for key in patch:
		if key == "__erase_econ__":
			(data["Economy"] as Dictionary).erase(patch[key])
		elif key == "__econ__":
			var econ_patch: Array = patch[key]
			(data["Economy"] as Dictionary)[econ_patch[0]] = econ_patch[1]
		else:
			data[key] = patch[key]


static func _write(path: String, text: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false}
	file.store_string(text)
	file.close()
	return {"ok": true}
