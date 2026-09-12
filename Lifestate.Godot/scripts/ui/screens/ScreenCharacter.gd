extends RefCounted

## Character screen — the RPG-style sheet: attributes, traits and skills.
## Reads derived values only; never exposes backing accumulators.

var _service
var _column: VBoxContainer
var _age_label: Label
var _stage_label: Label
var _attribute_values: Dictionary = {}
var _attribute_bars: Dictionary = {}
var _trait_values: Dictionary = {}
var _trait_bars: Dictionary = {}
var _skills_value: Label
var _skills_detail: Label
var _skills_bar: ProgressBar


func _init(service) -> void:
	_service = service


func build(parent: Control) -> void:
	_column = UiTheme.centered_column(parent, UiTheme.CONTENT_MAX_WIDTH, UiTheme.SPACE_LG)

	var header := UiTheme.card(UiTheme.SURFACE)
	_column.add_child(header)
	var header_row := UiTheme.hbox(UiTheme.SPACE_MD)
	header.add_child(header_row)
	var identity := UiTheme.vbox(0)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_age_label = UiTheme.label("Age 0", UiTheme.FONT_DISPLAY, UiTheme.TEXT_PRIMARY)
	_stage_label = UiTheme.label("Infant", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	identity.add_child(_age_label)
	identity.add_child(_stage_label)
	header_row.add_child(identity)

	var back_button := UiTheme.button("Back", UiTheme.TEXT_SECONDARY, UiTheme.BUTTON_HEIGHT_SMALL)
	back_button.pressed.connect(func() -> void: _service_go_back())
	header_row.add_child(back_button)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", UiTheme.SPACE_MD)
	_column.add_child(columns)

	var left := UiTheme.vbox(UiTheme.SPACE_MD)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)

	var right := UiTheme.vbox(UiTheme.SPACE_MD)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)

	_build_stat_section(left, "ATTRIBUTES", [
		["Intelligence", UiTheme.ACCENT],
		["Fitness", UiTheme.ACCENT],
		["Social", UiTheme.ACCENT],
		["Discipline", UiTheme.ACCENT],
		["Creativity", UiTheme.ACCENT],
	], _attribute_values, _attribute_bars)

	_build_stat_section(right, "TRAITS", [
		["Confidence", UiTheme.POSITIVE],
		["Curiosity", UiTheme.POSITIVE],
		["Patience", UiTheme.POSITIVE],
		["Ambition", UiTheme.POSITIVE],
		["Empathy", UiTheme.POSITIVE],
	], _trait_values, _trait_bars)

	var skills_card := UiTheme.card(UiTheme.SURFACE)
	right.add_child(skills_card)
	var body := UiTheme.card_body(skills_card, UiTheme.SPACE_XS)
	body.add_child(UiTheme.tag("SKILLS"))
	_skills_value = UiTheme.label("", UiTheme.FONT_VALUE, UiTheme.TEXT_PRIMARY)
	_skills_detail = UiTheme.label("", UiTheme.FONT_SMALL, UiTheme.TEXT_SECONDARY)
	_skills_bar = UiTheme.progress_bar(0.0, UiTheme.ACCENT)
	body.add_child(_skills_value)
	body.add_child(_skills_detail)
	body.add_child(_skills_bar)

	refresh()


func _service_go_back() -> void:
	var main: Node = _column.get_tree().current_scene
	if main != null and main.has_method("go_to"):
		main.go_to("more")


func _build_stat_section(parent: Control, title: String, rows: Array, values: Dictionary, bars: Dictionary) -> void:
	var card := UiTheme.card(UiTheme.SURFACE)
	parent.add_child(card)
	var body := UiTheme.card_body(card, UiTheme.SPACE_XS)
	body.add_child(UiTheme.tag(title))

	for entry in rows:
		var name: String = entry[0]
		var color: Color = entry[1]
		var row := UiTheme.hbox(UiTheme.SPACE_SM)
		var name_label := UiTheme.label(name, UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
		name_label.custom_minimum_size = Vector2(90, 0)
		row.add_child(name_label)
		var bar := UiTheme.progress_bar(0.0, color)
		row.add_child(bar)
		var value := UiTheme.label("0", UiTheme.FONT_SMALL, UiTheme.TEXT_PRIMARY)
		value.custom_minimum_size = Vector2(48, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		body.add_child(row)
		values[name] = value
		bars[name] = bar


func refresh() -> void:
	var player: PlayerState = _service.player
	var attributes: PlayerAttributes = player.attributes
	var traits: PlayerTraits = player.traits

	_age_label.text = "Age %d" % player.age
	_stage_label.text = player.life_stage_name

	_apply(_attribute_values, _attribute_bars, "Intelligence", attributes.intelligence)
	_apply(_attribute_values, _attribute_bars, "Fitness", attributes.fitness)
	_apply(_attribute_values, _attribute_bars, "Social", attributes.social)
	_apply(_attribute_values, _attribute_bars, "Discipline", attributes.discipline)
	_apply(_attribute_values, _attribute_bars, "Creativity", attributes.creativity)

	_apply(_trait_values, _trait_bars, "Confidence", traits.confidence)
	_apply(_trait_values, _trait_bars, "Curiosity", traits.curiosity)
	_apply(_trait_values, _trait_bars, "Patience", traits.patience)
	_apply(_trait_values, _trait_bars, "Ambition", traits.ambition)
	_apply(_trait_values, _trait_bars, "Empathy", traits.empathy)

	var academics: SkillProgress = player.skills.academics
	_skills_value.text = "Academics · Level %d" % academics.level
	if academics.experience >= SkillProgress.MAX_EXPERIENCE:
		_skills_detail.text = "Maxed at %d XP" % SkillProgress.MAX_EXPERIENCE
	else:
		_skills_detail.text = "%d / %d XP" % [academics.experience, SkillProgress.MAX_EXPERIENCE]
	_skills_bar.max_value = SkillProgress.MAX_EXPERIENCE
	_skills_bar.value = academics.experience


static func _apply(values: Dictionary, bars: Dictionary, name: String, value: float) -> void:
	values[name].text = "%.1f" % value
	bars[name].value = value
