extends RefCounted

## Activities screen — the Melvor side of LIFESTATE. Current activity hero,
## live progression, a compact support-action strip and a wrapping activity card
## grid (two columns on desktop, one when narrow).

const ACTIVITY_DEFS: Array = [
	["SLEEP", "Rest and restore your energy.", "sleep", ""],
	["STUDY", "Improve your academic ability.", "study", "Age 6+"],
	["PLAY", "Have fun and develop through childhood.", "play", "Age 2+"],
	["FAMILY TIME", "Spend time with your parents.", "family", ""],
	["WORK", "Earn money.", "work", "Age 18+"],
]

var _service
var _column: VBoxContainer
var _grid: GridContainer

var _hero_card: PanelContainer
var _hero_name: Label
var _hero_detail: Label
var _progress_card: PanelContainer
var _progress_tag: Label
var _progress_value: Label
var _progress_detail: Label
var _progress_bar: ProgressBar
var _cards: Dictionary = {}
var _last_activity: String = ""


func _init(service) -> void:
	_service = service


func build(parent: Control) -> void:
	_column = UiTheme.centered_column(parent, UiTheme.CONTENT_MAX_WIDTH, UiTheme.SPACE_LG)
	_column.add_child(UiTheme.label("ACTIVITIES", UiTheme.FONT_SCREEN_TITLE, UiTheme.TEXT_PRIMARY))
	_column.add_child(UiTheme.label("Continuous progression — the idle side of life.",
		UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY))

	_build_hero()
	_build_progress()
	_build_support_actions()
	_build_grid()
	refresh()


func _build_hero() -> void:
	_hero_card = UiTheme.card(UiTheme.SURFACE)
	_column.add_child(_hero_card)
	var body := UiTheme.card_body(_hero_card, UiTheme.SPACE_XS)
	body.add_child(UiTheme.tag("CURRENT ACTIVITY"))
	_hero_name = UiTheme.label("IDLE", UiTheme.FONT_DISPLAY, UiTheme.TEXT_PRIMARY)
	_hero_detail = UiTheme.label("Choose an activity below.", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	body.add_child(_hero_name)
	body.add_child(_hero_detail)


func _build_progress() -> void:
	_progress_card = UiTheme.card(UiTheme.SURFACE_RAISED, UiTheme.ACCENT)
	_progress_card.visible = false
	_column.add_child(_progress_card)
	var body := UiTheme.card_body(_progress_card, UiTheme.SPACE_XS)
	_progress_tag = UiTheme.tag("PROGRESSION", UiTheme.ACCENT)
	_progress_bar = UiTheme.progress_bar(0.0, UiTheme.ACCENT)
	_progress_value = UiTheme.label("", UiTheme.FONT_VALUE, UiTheme.TEXT_PRIMARY)
	_progress_detail = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	body.add_child(_progress_tag)
	body.add_child(_progress_bar)
	body.add_child(_progress_value)
	body.add_child(_progress_detail)


func _build_support_actions() -> void:
	var card := UiTheme.card(UiTheme.SURFACE)
	_column.add_child(card)
	var row := UiTheme.hbox(UiTheme.SPACE_SM)
	card.add_child(row)

	var tag := UiTheme.tag("SUPPORT")
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tag)

	var wait_button := UiTheme.button("Wait 1 Hour", UiTheme.TEXT_SECONDARY, UiTheme.BUTTON_HEIGHT_SMALL)
	wait_button.pressed.connect(func() -> void:
		_service.wait_one_hour()
		refresh()
	)
	row.add_child(wait_button)

	var eat_button := UiTheme.button("Eat +20", UiTheme.TEXT_SECONDARY, UiTheme.BUTTON_HEIGHT_SMALL)
	eat_button.pressed.connect(func() -> void:
		_service.player.eat(20)
		refresh()
	)
	row.add_child(eat_button)

	var drink_button := UiTheme.button("Drink +20", UiTheme.TEXT_SECONDARY, UiTheme.BUTTON_HEIGHT_SMALL)
	drink_button.pressed.connect(func() -> void:
		_service.player.drink(20)
		refresh()
	)
	row.add_child(drink_button)


func _build_grid() -> void:
	_column.add_child(UiTheme.tag("ALL ACTIVITIES"))

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", UiTheme.SPACE_SM)
	_grid.add_theme_constant_override("v_separation", UiTheme.SPACE_SM)
	_column.add_child(_grid)
	_column.resized.connect(_apply_grid_columns)

	for definition in ACTIVITY_DEFS:
		_grid.add_child(_build_activity_card(definition))


func _apply_grid_columns() -> void:
	_grid.columns = 2 if _column.size.x >= 760.0 else 1


func _build_activity_card(definition: Array) -> Control:
	var name: String = definition[0]
	var description: String = definition[1]
	var key: String = definition[2]
	var requirement: String = definition[3]

	var card := UiTheme.card(UiTheme.SURFACE)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := UiTheme.card_body(card, UiTheme.SPACE_XS)
	body.add_child(UiTheme.label(name, UiTheme.FONT_HEADING, UiTheme.TEXT_PRIMARY))

	var description_label := UiTheme.label(description, UiTheme.FONT_SMALL, UiTheme.TEXT_SECONDARY)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(description_label)

	var status := UiTheme.label("", UiTheme.FONT_TAG, UiTheme.TEXT_MUTED)
	body.add_child(status)

	var action := UiTheme.button("START", UiTheme.TEXT_PRIMARY, UiTheme.BUTTON_HEIGHT_SMALL)
	action.pressed.connect(func() -> void: _toggle(key))
	body.add_child(action)

	_cards[key] = {
		"card": card,
		"status": status,
		"action": action,
		"requirement": requirement,
	}
	return card


func _toggle(key: String) -> void:
	var player: PlayerState = _service.player
	var accepted: bool = true

	match key:
		"sleep":
			if player.is_sleeping:
				player.stop_sleeping()
			else:
				player.start_sleeping()
				accepted = player.is_sleeping
		"study":
			if player.is_studying:
				player.stop_studying()
			else:
				player.start_studying()
				accepted = player.is_studying
		"play":
			if player.is_playing:
				player.stop_playing()
			else:
				accepted = player.start_playing()
		"family":
			if player.is_spending_family_time:
				player.stop_family_time()
			else:
				accepted = player.start_family_time()
		"work":
			if player.is_working:
				player.stop_working()
			else:
				player.start_working()
				accepted = player.is_working

	if accepted:
		_service.request_feedback("", UiTheme.TEXT_SECONDARY)
	else:
		_service.request_feedback(_rejection_reason(key), UiTheme.WARNING)
	refresh()


func _rejection_reason(key: String) -> String:
	var player: PlayerState = _service.player
	if key == "work" and player.age < PlayerState.WORK_MIN_AGE:
		return "You must be at least 18 to work."
	if key == "study" and player.age < PlayerState.STUDY_MIN_AGE:
		return "You must be at least 6 to study."
	if key == "play" and player.age < PlayerState.PLAY_MIN_AGE:
		return "You must be at least 2 to play."
	return "You are already busy with another activity."


func refresh() -> void:
	var player: PlayerState = _service.player
	var activity: String = player.current_activity_name()

	_hero_name.text = activity.to_upper()
	if activity == "Idle":
		_hero_detail.text = "Choose an activity below."
		_hero_card.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE, UiTheme.BORDER))
	else:
		_hero_detail.text = "Time keeps moving while you are busy."
		_hero_card.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE, UiTheme.ACCENT))

	_refresh_progress(player, activity)
	_refresh_cards(player)
	_last_activity = activity


func _refresh_progress(player: PlayerState, activity: String) -> void:
	if activity == "Idle":
		_progress_card.visible = false
		return

	_progress_card.visible = true
	_progress_bar.visible = true

	if player.is_studying:
		_progress_tag.text = "STUDY PROGRESSION"
		var experience: int = player.skills.academics.experience
		_progress_bar.max_value = SkillProgress.MAX_EXPERIENCE
		_progress_bar.value = experience
		_progress_value.text = "Academics · Level %d" % player.skills.academics.level
		var detail: String = "%d / %d XP" % [experience, SkillProgress.MAX_EXPERIENCE]
		if player.education.status == EducationState.Status.PRIMARY_SCHOOL:
			detail += "   ·   School progress %d / 100" % player.education.education_progress
		_progress_detail.text = detail
	elif player.is_playing:
		_progress_tag.text = "PLAY PROGRESSION"
		_progress_bar.visible = false
		_progress_value.text = "Lifetime play: %s hours" % UiTheme.format_int(player.total_play_hours)
		_progress_detail.text = "Broken Toy becomes possible after 10 hours."
	elif player.is_spending_family_time:
		_progress_tag.text = "FAMILY TIME"
		_progress_bar.max_value = 100
		_progress_bar.value = player.relationships.mother_relationship.closeness
		_progress_value.text = "Mother closeness %.1f" % player.relationships.mother_relationship.closeness
		_progress_detail.text = "Father closeness %.1f" % player.relationships.father_relationship.closeness
	elif player.is_working:
		_progress_tag.text = "WORK"
		_progress_bar.visible = false
		_progress_value.text = UiTheme.format_money(player.money)
		_progress_detail.text = "10 money per completed hour."
	else:
		_progress_tag.text = "SLEEP"
		_progress_bar.max_value = 100
		_progress_bar.value = player.energy
		_progress_value.text = "Energy %d / 100" % player.energy
		_progress_detail.text = "5 energy per completed hour of sleep."


func _refresh_cards(player: PlayerState) -> void:
	var states: Dictionary = {
		"sleep": player.is_sleeping,
		"study": player.is_studying,
		"play": player.is_playing,
		"family": player.is_spending_family_time,
		"work": player.is_working,
	}

	for key in _cards:
		var entry: Dictionary = _cards[key]
		var card: PanelContainer = entry["card"]
		var status: Label = entry["status"]
		var action: Button = entry["action"]
		var requirement: String = entry["requirement"]
		var active: bool = states[key]

		if active:
			card.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE_RAISED, UiTheme.ACCENT))
			status.text = "● ACTIVE"
			status.add_theme_color_override("font_color", UiTheme.ACCENT)
			action.text = "STOP"
			action.add_theme_color_override("font_color", UiTheme.NEGATIVE)
			action.add_theme_color_override("font_hover_color", UiTheme.NEGATIVE)
		else:
			card.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE, UiTheme.BORDER))
			status.text = requirement if not requirement.is_empty() else "Available"
			status.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
			action.text = "START"
			action.add_theme_color_override("font_color", UiTheme.TEXT_PRIMARY)
			action.add_theme_color_override("font_hover_color", UiTheme.ACCENT)
