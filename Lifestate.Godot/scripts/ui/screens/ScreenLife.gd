extends RefCounted

## Life screen — the BitLife side of LIFESTATE. One centered vertical feed:
## compact identity header, compact needs, optional pending event, then the
## dominant life-history feed. No attributes, traits, academics or education
## here; those have their own destinations.

var _service
var _column: VBoxContainer

var _age_label: Label
var _stage_label: Label
var _money_label: Label
var _daily_cost_label: Label
var _activity_label: Label
var _needs_card: PanelContainer
var _need_bars: Dictionary = {}
var _need_values: Dictionary = {}

var _terminal_card: PanelContainer
var _terminal_summary: VBoxContainer

var _pending_card: PanelContainer
var _pending_tag: Label
var _pending_title: Label
var _pending_description: Label
var _pending_choices: VBoxContainer

var _feed_header: Label
var _empty_label: Label
var _feed_container: VBoxContainer

var _last_history_count: int = -1
var _last_pending_id: String = ""


func _init(service) -> void:
	_service = service


func build(parent: Control) -> void:
	_column = UiTheme.centered_column(parent, UiTheme.LIFE_CONTENT_MAX_WIDTH, UiTheme.SPACE_LG)

	_build_identity_header()
	_build_terminal()
	_build_needs()
	_build_pending_event()
	_build_feed()
	refresh()


func _build_identity_header() -> void:
	var card := UiTheme.card(UiTheme.SURFACE)
	_column.add_child(card)
	var row := UiTheme.hbox(UiTheme.SPACE_MD)
	card.add_child(row)

	var identity := UiTheme.vbox(0)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_age_label = UiTheme.label("Age 0", UiTheme.FONT_LIFE_AGE, UiTheme.TEXT_PRIMARY)
	_stage_label = UiTheme.label("Infant", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	identity.add_child(_age_label)
	identity.add_child(_stage_label)
	row.add_child(identity)

	var status := UiTheme.vbox(0)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	_money_label = UiTheme.label("$1,000", UiTheme.FONT_VALUE, UiTheme.POSITIVE)
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_activity_label = UiTheme.label("Currently Idle", UiTheme.FONT_SMALL, UiTheme.TEXT_SECONDARY)
	_activity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_daily_cost_label = UiTheme.label("Daily Cost $0", UiTheme.FONT_SMALL, UiTheme.TEXT_MUTED)
	_daily_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(_money_label)
	status.add_child(_daily_cost_label)
	status.add_child(_activity_label)
	row.add_child(status)


func _build_needs() -> void:
	_needs_card = UiTheme.card(UiTheme.SURFACE)
	_column.add_child(_needs_card)
	var body := UiTheme.card_body(_needs_card, UiTheme.SPACE_XS)
	body.add_child(UiTheme.tag("NEEDS"))

	var definitions: Array = [
		["Energy", UiTheme.ACCENT],
		["Hunger", UiTheme.WARNING],
		["Thirst", UiTheme.ACCENT_MUTED],
		["Health", UiTheme.NEGATIVE],
	]
	for entry in definitions:
		var name: String = entry[0]
		var bar_color: Color = entry[1]
		var row := UiTheme.hbox(UiTheme.SPACE_SM)

		var name_label := UiTheme.label(name, UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
		name_label.custom_minimum_size = Vector2(70, 0)
		row.add_child(name_label)

		var bar := UiTheme.progress_bar(100.0, bar_color)
		row.add_child(bar)

		var value_label := UiTheme.label("100", UiTheme.FONT_SMALL, UiTheme.TEXT_PRIMARY)
		value_label.custom_minimum_size = Vector2(42, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)

		body.add_child(row)
		_need_bars[name] = bar
		_need_values[name] = value_label


## Terminal state card, shown only when the player has died. The Life screen
## becomes a life record: cause, death day/age and a concise life summary.
func _build_terminal() -> void:
	_terminal_card = UiTheme.card(UiTheme.SURFACE_RAISED, UiTheme.NEGATIVE)
	_terminal_card.visible = false
	_column.add_child(_terminal_card)

	var body := UiTheme.card_body(_terminal_card, UiTheme.SPACE_MD)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.name = "CardBody"

	var ended := UiTheme.label("LIFE ENDED", UiTheme.FONT_DISPLAY, UiTheme.NEGATIVE)
	ended.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(ended)

	var subtitle := UiTheme.label("", UiTheme.FONT_HEADING, UiTheme.TEXT_PRIMARY)
	subtitle.name = "TerminalSubtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(subtitle)

	var cause := UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	cause.name = "TerminalCause"
	cause.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(cause)

	_terminal_summary = UiTheme.vbox(UiTheme.SPACE_XS)
	_terminal_summary.name = "TerminalSummary"
	body.add_child(_terminal_summary)


func _build_pending_event() -> void:
	_pending_card = UiTheme.card(UiTheme.SURFACE_RAISED, UiTheme.ACCENT)
	_pending_card.visible = false
	_column.add_child(_pending_card)

	var body := UiTheme.card_body(_pending_card, UiTheme.SPACE_XS)
	_pending_tag = UiTheme.tag("LIFE EVENT", UiTheme.ACCENT)
	_pending_title = UiTheme.label("", UiTheme.FONT_HEADING, UiTheme.TEXT_PRIMARY)
	_pending_description = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	_pending_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pending_choices = UiTheme.vbox(UiTheme.SPACE_XS)

	body.add_child(_pending_tag)
	body.add_child(_pending_title)
	body.add_child(_pending_description)
	body.add_child(_pending_choices)


func _build_feed() -> void:
	_feed_header = UiTheme.label("LIFE", UiTheme.FONT_HEADING, UiTheme.TEXT_PRIMARY)
	_column.add_child(_feed_header)

	_empty_label = UiTheme.label("Your life story is just beginning.", UiTheme.FONT_BODY, UiTheme.TEXT_MUTED)
	_empty_label.visible = false
	_column.add_child(_empty_label)

	_feed_container = UiTheme.vbox(UiTheme.SPACE_XS)
	_column.add_child(_feed_container)


func refresh() -> void:
	var player: PlayerState = _service.player

	_age_label.text = "Age %d" % player.age
	_stage_label.text = player.life_stage_name
	_money_label.text = UiTheme.format_money(player.money)
	_daily_cost_label.text = "Daily Cost $%d" % EconomyState.daily_rate_for_age(player.age)
	var activity_name: String = player.current_activity_name()
	_activity_label.text = "Currently " + activity_name
	if player.is_working:
		# Position identity rides along with the working label; Life stays lean.
		_activity_label.text = "Currently Working · %s" % player.career.current_title()

	# Terminal state: the needs area is replaced by the LIFE ENDED record.
	_needs_card.visible = not player.is_dead
	_pending_card.visible = not player.is_dead and _pending_card.visible
	_terminal_card.visible = player.is_dead
	if player.is_dead:
		_refresh_terminal(player)
		_refresh_feed()
		return

	_set_need("Energy", player.energy)
	_set_need("Hunger", player.hunger)
	_set_need("Thirst", player.thirst)
	_set_need("Health", int(round(player.health)))

	_refresh_pending_event()
	_refresh_feed()


func _refresh_terminal(player: PlayerState) -> void:
	var subtitle: Label = _terminal_card.get_node("CardBody/TerminalSubtitle")
	var cause: Label = _terminal_card.get_node("CardBody/TerminalCause")
	subtitle.text = "Age %d   ·   Day %s" % [player.death_age, UiTheme.format_int(player.death_day)]
	cause.text = "Cause: %s" % PlayerState.display_cause(player.cause_of_death)

	# Concise life summary (foundation scope: no statistics system).
	_clear_children(_terminal_summary)
	_summary_row("Final Money", UiTheme.format_money(player.money))
	_summary_row("Education", EducationState.display_name(player.education.status))
	_summary_row("Final Occupation", _final_occupation(player))


func _final_occupation(player: PlayerState) -> String:
	if player.career.is_employed():
		return player.career.current_title()
	return "Unemployed"


func _summary_row(name: String, value: String) -> void:
	var row := UiTheme.hbox(UiTheme.SPACE_SM)
	var key := UiTheme.label(name, UiTheme.FONT_SMALL, UiTheme.TEXT_SECONDARY)
	key.custom_minimum_size = Vector2(120, 0)
	row.add_child(key)
	row.add_child(UiTheme.label(value, UiTheme.FONT_BODY, UiTheme.TEXT_PRIMARY))
	_terminal_summary.add_child(row)


func _set_need(name: String, value: int) -> void:
	_need_bars[name].value = value
	_need_values[name].text = str(value)


func _refresh_pending_event() -> void:
	var pending: PendingLifeEvent = _service.player.events.current_event
	var pending_id: String = pending.event_id if pending != null else ""

	if pending_id == _last_pending_id:
		return
	_last_pending_id = pending_id

	_clear_children(_pending_choices)
	if pending == null:
		_pending_card.visible = false
		return

	var definition := LifeEventCatalog.get_by_id(pending.event_id)
	if definition == null:
		_pending_card.visible = false
		return

	_pending_title.text = definition.title
	_pending_description.text = definition.description
	for choice in definition.choices:
		var button := UiTheme.button(choice.text, UiTheme.TEXT_PRIMARY)
		var captured: EventChoice = choice
		button.pressed.connect(func() -> void: _resolve(captured.id))
		_pending_choices.add_child(button)

	_pending_card.visible = true


func _resolve(choice_id: String) -> void:
	if _service.player.resolve_event_choice(choice_id):
		_service.request_feedback("Choice made.", UiTheme.POSITIVE)
	else:
		_service.request_feedback("That choice is no longer available.", UiTheme.WARNING)
	refresh()


## The feed is only rebuilt when the history or pending event actually changes,
## so the per-second refresh never churns hundreds of nodes.
func _refresh_feed() -> void:
	var history: Array[EventHistoryEntry] = _service.player.events.history
	if history.size() == _last_history_count:
		return
	_last_history_count = history.size()

	_clear_children(_feed_container)

	if history.is_empty():
		_empty_label.visible = true
		return
	_empty_label.visible = false

	# Newest first; the newest entry carries the accent marker.
	var first: bool = true
	for index in range(history.size() - 1, -1, -1):
		_feed_container.add_child(_build_entry(history[index], first))
		first = false


func _build_entry(entry: EventHistoryEntry, is_newest: bool) -> Control:
	var definition := LifeEventCatalog.get_by_id(entry.event_id)
	var title: String = definition.title if definition != null else entry.event_id
	var choice := definition.get_choice(entry.choice_id) if definition != null else null
	var outcome: String = choice.text if choice != null else entry.choice_id
	var age: int = entry.triggered_day / GameClock.DAYS_PER_YEAR

	var row := UiTheme.hbox(UiTheme.SPACE_SM)

	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 0)
	rail.custom_minimum_size = Vector2(12, 0)
	var dot := ColorRect.new()
	dot.color = UiTheme.ACCENT if is_newest else UiTheme.TEXT_MUTED
	dot.custom_minimum_size = Vector2(9, 9)
	var rail_line := ColorRect.new()
	rail_line.color = UiTheme.BORDER
	rail_line.custom_minimum_size = Vector2(1, 0)
	rail_line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail.add_child(dot)
	rail.add_child(rail_line)
	row.add_child(rail)

	var content := UiTheme.vbox(0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(UiTheme.tag("AGE %d" % age))
	content.add_child(UiTheme.label(title, UiTheme.FONT_BODY, UiTheme.TEXT_PRIMARY))
	content.add_child(UiTheme.label(outcome, UiTheme.FONT_SMALL, UiTheme.TEXT_SECONDARY))
	row.add_child(content)

	return row


static func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
