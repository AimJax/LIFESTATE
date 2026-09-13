extends RefCounted

## Education screen — Primary and Secondary School tiers.

var _service
var _column: VBoxContainer
var _status_label: Label
var _grade_label: Label
var _progress_label: Label
var _progress_bar: ProgressBar
var _year_label: Label
var _academics_label: Label
var _academics_bar: ProgressBar
var _enroll_button: Button
var _secondary_enroll_button: Button
var _empty_label: Label
var _body_card: PanelContainer
var _detail_box: VBoxContainer
var _secondary_hint_label: Label


func _init(service) -> void:
	_service = service


func build(parent: Control) -> void:
	_column = UiTheme.centered_column(parent, UiTheme.CONTENT_MAX_WIDTH, UiTheme.SPACE_LG)
	_column.add_child(UiTheme.label("EDUCATION", UiTheme.FONT_SCREEN_TITLE, UiTheme.TEXT_PRIMARY))
	_column.add_child(UiTheme.label("Formal schooling and academic progress.",
		UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY))

	var header := UiTheme.card(UiTheme.SURFACE)
	_column.add_child(header)
	var header_row := UiTheme.hbox(UiTheme.SPACE_MD)
	header.add_child(header_row)
	var titles := UiTheme.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grade_label = UiTheme.label("PRIMARY SCHOOL", UiTheme.FONT_DISPLAY, UiTheme.TEXT_PRIMARY)
	_status_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	titles.add_child(_grade_label)
	titles.add_child(_status_label)
	header_row.add_child(titles)

	var back_button := UiTheme.button("Back", UiTheme.TEXT_SECONDARY, UiTheme.BUTTON_HEIGHT_SMALL)
	back_button.pressed.connect(func() -> void:
		var main: Node = _column.get_tree().current_scene
		if main != null and main.has_method("go_to"):
			main.go_to("more")
	)
	header_row.add_child(back_button)

	_empty_label = UiTheme.label("Not enrolled in school.", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	_column.add_child(_empty_label)

	_enroll_button = UiTheme.button("ENROLL IN PRIMARY SCHOOL", UiTheme.ACCENT)
	_enroll_button.pressed.connect(_on_enroll)
	_column.add_child(_enroll_button)

	_secondary_enroll_button = UiTheme.button("ENROLL IN SECONDARY SCHOOL", UiTheme.ACCENT)
	_secondary_enroll_button.pressed.connect(_on_secondary_enroll)
	_column.add_child(_secondary_enroll_button)

	_secondary_hint_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	_column.add_child(_secondary_hint_label)

	_body_card = UiTheme.card(UiTheme.SURFACE)
	_column.add_child(_body_card)
	_detail_box = UiTheme.card_body(_body_card, UiTheme.SPACE_XS)

	var progress_row := UiTheme.vbox(0)
	progress_row.add_child(UiTheme.tag("EDUCATION PROGRESS"))
	_progress_bar = UiTheme.progress_bar(0.0, UiTheme.ACCENT)
	_progress_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_PRIMARY)
	progress_row.add_child(_progress_bar)
	progress_row.add_child(_progress_label)
	_detail_box.add_child(progress_row)

	var year_row := UiTheme.vbox(0)
	year_row.add_child(UiTheme.tag("ACADEMIC YEAR"))
	_year_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_PRIMARY)
	year_row.add_child(_year_label)
	_detail_box.add_child(year_row)

	var academics_row := UiTheme.vbox(0)
	academics_row.add_child(UiTheme.tag("ACADEMICS"))
	_academics_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_PRIMARY)
	_academics_bar = UiTheme.progress_bar(0.0, UiTheme.ACCENT)
	academics_row.add_child(_academics_bar)
	academics_row.add_child(_academics_label)
	_detail_box.add_child(academics_row)

	refresh()


func _on_enroll() -> void:
	if _service.player.enroll_primary_school():
		_service.request_feedback("Enrolled in primary school.", UiTheme.POSITIVE)
	else:
		_service.request_feedback("You must be at least 6 years old to enroll.", UiTheme.WARNING)
	refresh()


func _on_secondary_enroll() -> void:
	var player: PlayerState = _service.player
	if player.enroll_secondary_school():
		_service.request_feedback("Enrolled in secondary school.", UiTheme.POSITIVE)
	else:
		if player.education.status != EducationState.Status.COMPLETED_PRIMARY:
			_service.request_feedback("Complete primary school first.", UiTheme.WARNING)
		elif player.age < PlayerState.SECONDARY_ENROLL_MIN_AGE:
			_service.request_feedback("You must be at least 12 years old to enroll in secondary school.", UiTheme.WARNING)
		else:
			_service.request_feedback("You cannot enroll again.", UiTheme.WARNING)
	refresh()


func refresh() -> void:
	var player: PlayerState = _service.player
	var education: EducationState = player.education
	var not_enrolled: bool = education.status == EducationState.Status.NOT_ENROLLED
	var primary_eligible: bool = player.age >= PlayerState.ENROLL_MIN_AGE
	var secondary_eligible: bool = (
		player.age >= PlayerState.SECONDARY_ENROLL_MIN_AGE
		and education.status == EducationState.Status.COMPLETED_PRIMARY
	)

	_status_label.text = EducationState.display_name(education.status)
	_empty_label.visible = not_enrolled and not primary_eligible
	_enroll_button.visible = not_enrolled and primary_eligible
	_secondary_enroll_button.visible = secondary_eligible
	_secondary_hint_label.visible = (
		education.status == EducationState.Status.COMPLETED_PRIMARY
		and not secondary_eligible
	)
	_body_card.visible = not not_enrolled

	_secondary_hint_label.text = "Secondary school becomes available at age 12."

	if education.status == EducationState.Status.NOT_ENROLLED:
		_grade_label.text = "PRIMARY SCHOOL"
	elif education.status == EducationState.Status.COMPLETED_PRIMARY:
		_grade_label.text = "PRIMARY SCHOOL COMPLETED"
	elif education.status == EducationState.Status.SECONDARY_SCHOOL:
		_grade_label.text = "SECONDARY SCHOOL · GRADE %d" % education.secondary_grade
	elif education.status == EducationState.Status.COMPLETED_SECONDARY:
		_grade_label.text = "SECONDARY SCHOOL COMPLETED"
	else:
		_grade_label.text = "PRIMARY SCHOOL · GRADE %d" % education.primary_grade

	if not_enrolled:
		return

	_progress_bar.value = education.education_progress
	_progress_label.text = "%d / 100" % education.education_progress

	var days_into_year: int = _service.clock.day - education.school_year_start_day
	_year_label.text = "Day %d / 365" % clampi(days_into_year, 0, EducationState.DAYS_PER_SCHOOL_YEAR)

	var academics: SkillProgress = player.skills.academics
	_academics_label.text = "Level %d · %d XP" % [academics.level, academics.experience]
	_academics_bar.max_value = SkillProgress.MAX_EXPERIENCE
	_academics_bar.value = academics.experience
