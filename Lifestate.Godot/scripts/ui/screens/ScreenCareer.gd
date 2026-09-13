extends RefCounted

## Career screen — deterministic foundation: current job state, quit, and the
## four-job catalog with requirement feedback. All mutations go through
## PlayerState.apply_for_job / quit_job; this screen never edits state directly.

var _service
var _column: VBoxContainer
var _status_card: PanelContainer
var _status_title: Label
var _status_detail: Label
var _quit_button: Button
var _jobs_grid: GridContainer
var _job_cards: Dictionary = {}
var _cards_last_employed: bool = false


func _init(service) -> void:
	_service = service


func build(parent: Control) -> void:
	_column = UiTheme.centered_column(parent, UiTheme.CONTENT_MAX_WIDTH, UiTheme.SPACE_LG)
	_column.add_child(UiTheme.label("CAREER", UiTheme.FONT_SCREEN_TITLE, UiTheme.TEXT_PRIMARY))
	_column.add_child(UiTheme.label("Jobs, wages and applications.",
		UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY))

	_build_status_card()

	_column.add_child(UiTheme.tag("AVAILABLE JOBS"))
	_jobs_grid = GridContainer.new()
	_jobs_grid.columns = 2
	_jobs_grid.add_theme_constant_override("h_separation", UiTheme.SPACE_SM)
	_jobs_grid.add_theme_constant_override("v_separation", UiTheme.SPACE_SM)
	_column.add_child(_jobs_grid)
	_column.resized.connect(_apply_grid_columns)

	for definition in JobCatalog.definitions():
		_jobs_grid.add_child(_build_job_card(definition))

	refresh()


func _build_status_card() -> void:
	_status_card = UiTheme.card(UiTheme.SURFACE)
	_column.add_child(_status_card)
	var body := UiTheme.card_body(_status_card, UiTheme.SPACE_XS)
	_status_title = UiTheme.label("UNEMPLOYED", UiTheme.FONT_DISPLAY, UiTheme.TEXT_PRIMARY)
	_status_detail = UiTheme.label("No current occupation.", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	body.add_child(_status_title)
	body.add_child(_status_detail)
	_quit_button = UiTheme.button("Quit Job", UiTheme.NEGATIVE, UiTheme.BUTTON_HEIGHT_SMALL)
	_quit_button.pressed.connect(_on_quit)
	body.add_child(_quit_button)


func _build_job_card(definition: JobDefinition) -> Control:
	var card := UiTheme.card(UiTheme.SURFACE)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := UiTheme.card_body(card, UiTheme.SPACE_XS)

	var header := UiTheme.hbox(UiTheme.SPACE_SM)
	var title := UiTheme.label(definition.display_name.to_upper(), UiTheme.FONT_HEADING, UiTheme.TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiTheme.label("$%d/hour" % definition.hourly_wage, UiTheme.FONT_VALUE, UiTheme.POSITIVE))
	body.add_child(header)

	body.add_child(UiTheme.label(definition.description, UiTheme.FONT_SMALL, UiTheme.TEXT_SECONDARY))
	body.add_child(UiTheme.tag("REQUIREMENTS"))

	var requirements := UiTheme.vbox(0)
	var age_label := UiTheme.label("", UiTheme.FONT_SMALL, UiTheme.TEXT_MUTED)
	requirements.add_child(age_label)
	var edu_label := UiTheme.label("", UiTheme.FONT_SMALL, UiTheme.TEXT_MUTED)
	edu_label.visible = not definition.education_label().is_empty()
	requirements.add_child(edu_label)
	var attr_label := UiTheme.label("", UiTheme.FONT_SMALL, UiTheme.TEXT_MUTED)
	attr_label.visible = not definition.attribute_label().is_empty()
	requirements.add_child(attr_label)
	body.add_child(requirements)

	var apply_button := UiTheme.button("APPLY", UiTheme.ACCENT, UiTheme.BUTTON_HEIGHT_SMALL)
	apply_button.pressed.connect(func() -> void: _on_apply(definition.id))
	body.add_child(apply_button)

	_job_cards[definition.id] = {
		"card": card,
		"age_label": age_label,
		"edu_label": edu_label,
		"attr_label": attr_label,
		"apply_button": apply_button,
	}
	return card


func _apply_grid_columns() -> void:
	_jobs_grid.columns = 2 if _column.size.x >= 760.0 else 1


func _on_apply(job_id: String) -> void:
	var player: PlayerState = _service.player
	var evaluation: Dictionary = player.evaluate_application(job_id)
	if not evaluation["ok"]:
		_service.request_feedback(evaluation["reason"], UiTheme.WARNING)
		refresh()
		return
	if player.apply_for_job(job_id):
		_service.request_feedback("Hired as %s." % JobCatalog.get_by_id(job_id).display_name, UiTheme.POSITIVE)
	else:
		_service.request_feedback("Application failed.", UiTheme.WARNING)
	refresh()


func _on_quit() -> void:
	if _service.player.quit_job():
		_service.request_feedback("You quit your job.", UiTheme.TEXT_SECONDARY)
	else:
		_service.request_feedback("You are not employed.", UiTheme.WARNING)
	refresh()


func refresh() -> void:
	var player: PlayerState = _service.player
	var career: CareerState = player.career
	var employed: bool = career.is_employed()

	if employed:
		var job: JobDefinition = career.current_job()
		_status_title.text = "CURRENT JOB"
		_status_detail.text = "%s · $%d/hour" % [job.display_name, job.hourly_wage]
		_status_detail.add_theme_color_override("font_color", UiTheme.TEXT_PRIMARY)
	else:
		_status_title.text = "UNEMPLOYED"
		_status_detail.text = "No current occupation."
		_status_detail.add_theme_color_override("font_color", UiTheme.TEXT_SECONDARY)

	_quit_button.visible = employed

	# Only rebuild requirement markers when player state actually changed;
	# this keeps the per-second refresh churn-free.
	if employed != _cards_last_employed or _requirements_changed(player):
		_refresh_job_cards(player, employed)
		_cards_last_employed = employed


func _requirement_states(player: PlayerState, definition: JobDefinition) -> Dictionary:
	var evaluation: Dictionary = player.evaluate_application(definition.id)
	var age_ok: bool = player.age >= definition.minimum_age
	var edu_ok: bool = definition.education_label().is_empty() or (
		(definition.education_requirement == JobDefinition.EducationRequirement.PRIMARY_COMPLETED
			and (player.education.status == EducationState.Status.COMPLETED_PRIMARY
				or player.education.status == EducationState.Status.COMPLETED_SECONDARY))
		or (definition.education_requirement == JobDefinition.EducationRequirement.SECONDARY_COMPLETED
			and player.education.status == EducationState.Status.COMPLETED_SECONDARY))
	var attr_ok: bool = definition.required_attribute.is_empty() \
		or player._attribute_value(definition.required_attribute) >= definition.required_attribute_min
	return {"ok": evaluation["ok"], "age_ok": age_ok, "edu_ok": edu_ok, "attr_ok": attr_ok}


func _requirements_changed(player: PlayerState) -> bool:
	for definition in JobCatalog.definitions():
		var states: Dictionary = _requirement_states(player, definition)
		var entry: Dictionary = _job_cards[definition.id]
		if not entry.has("last_ok") or (states["ok"] as bool) != (entry["last_ok"] as bool):
			return true
		entry["last_ok"] = states["ok"]
	return false


func _refresh_job_cards(player: PlayerState, employed: bool) -> void:
	for definition in JobCatalog.definitions():
		var states: Dictionary = _requirement_states(player, definition)
		var entry: Dictionary = _job_cards[definition.id]

		var age_label: Label = entry["age_label"]
		age_label.text = "%s Age %d+" % ["✓" if states["age_ok"] else "✕", definition.minimum_age]
		age_label.add_theme_color_override("font_color",
			UiTheme.POSITIVE if states["age_ok"] else UiTheme.NEGATIVE)

		if not definition.education_label().is_empty():
			var edu_label: Label = entry["edu_label"]
			edu_label.text = "%s %s" % ["✓" if states["edu_ok"] else "✕", definition.education_label()]
			edu_label.add_theme_color_override("font_color",
				UiTheme.POSITIVE if states["edu_ok"] else UiTheme.NEGATIVE)

		if not definition.attribute_label().is_empty():
			var attr_label: Label = entry["attr_label"]
			attr_label.text = "%s %s" % ["✓" if states["attr_ok"] else "✕", definition.attribute_label()]
			attr_label.add_theme_color_override("font_color",
				UiTheme.POSITIVE if states["attr_ok"] else UiTheme.NEGATIVE)

		# While employed, every Apply button is disabled so a second job can
		# never be hired; while unemployed, clicking always gives deterministic
		# feedback (hired, or the unmet requirement).
		var apply_button: Button = entry["apply_button"]
		apply_button.disabled = employed
		apply_button.text = "APPLY"
		entry["last_ok"] = states["ok"]
