class_name UiTheme
extends RefCounted

## Central visual identity for the LIFESTATE Godot UI, translated from the
## approved WinForms palette. Everything visual goes through here so the
## interface stays intentional instead of default Godot grey.

# ---- Palette ---------------------------------------------------------------
const BACKGROUND := Color("0d1117")
const SURFACE := Color("151b23")
const SURFACE_RAISED := Color("1c2430")
const BORDER := Color("2a3441")

const TEXT_PRIMARY := Color("e6edf3")
const TEXT_SECONDARY := Color("8b98a7")
const TEXT_MUTED := Color("596675")

const ACCENT := Color("5fa8ff")
const ACCENT_MUTED := Color("4a7cb0")
const POSITIVE := Color("63d297")
const WARNING := Color("e5b567")
const NEGATIVE := Color("e06c75")

# ---- Spacing system --------------------------------------------------------
const SPACE_XS: int = 4
const SPACE_SM: int = 8
const SPACE_MD: int = 16
const SPACE_LG: int = 24
const SPACE_XL: int = 32

# ---- Size system -----------------------------------------------------------
const CONTENT_MAX_WIDTH: int = 1180
const LIFE_CONTENT_MAX_WIDTH: int = 1000
const TOP_BAR_HEIGHT: int = 56
const NAV_HEIGHT: int = 64
const BUTTON_HEIGHT: int = 40
const BUTTON_HEIGHT_SMALL: int = 30
const PROGRESS_BAR_HEIGHT: int = 12
const TIMELINE_ENTRY_HEIGHT: int = 78

# ---- Font sizes ------------------------------------------------------------
const FONT_TITLE: int = 22
const FONT_SCREEN_TITLE: int = 20
const FONT_DISPLAY: int = 22
const FONT_LIFE_AGE: int = 20
const FONT_HEADING: int = 15
const FONT_VALUE: int = 13
const FONT_SECTION: int = 11
const FONT_BODY: int = 10
const FONT_SMALL: int = 10
const FONT_TAG: int = 9
const FONT_NAV: int = 11

static var _theme: Theme = null


# =====================================================================
# Theme
# =====================================================================

## Builds the shared theme. Saved to res://themes/Lifestate.tres so the project
## loads it globally (gui/theme/custom) without rebuilding it at runtime.
static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_BODY

	# Buttons
	theme.set_stylebox("normal", "Button", panel_style(SURFACE_RAISED, BORDER, 1, 6))
	theme.set_stylebox("hover", "Button", panel_style(SURFACE_RAISED.lightened(0.08), ACCENT, 1, 6))
	theme.set_stylebox("pressed", "Button", panel_style(SURFACE, ACCENT, 1, 6))
	theme.set_stylebox("disabled", "Button", panel_style(SURFACE, BORDER, 1, 6))
	theme.set_stylebox("focus", "Button", panel_style(Color(0, 0, 0, 0), ACCENT, 1, 6))
	theme.set_color("font_color", "Button", TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", TEXT_PRIMARY)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_disabled_color", "Button", TEXT_MUTED)
	theme.set_constant("h_separation", "Button", 6)

	# Panels
	theme.set_stylebox("panel", "PanelContainer", panel_style(SURFACE, BORDER, 1, 6))
	theme.set_stylebox("panel", "Panel", panel_style(SURFACE, BORDER, 1, 6))

	# Progress bars
	theme.set_stylebox("background", "ProgressBar", panel_style(SURFACE_RAISED, BORDER, 1, 3))
	theme.set_stylebox("fill", "ProgressBar", panel_style(ACCENT, ACCENT, 0, 3))
	theme.set_color("font_color", "ProgressBar", TEXT_SECONDARY)
	theme.set_font_size("font_size", "ProgressBar", FONT_TAG)

	# Text
	theme.set_color("font_color", "Label", TEXT_PRIMARY)
	theme.set_color("default_color", "RichTextLabel", TEXT_PRIMARY)
	theme.set_font_size("normal_font_size", "RichTextLabel", FONT_BODY)

	# Scrollbars kept dark and unobtrusive
	theme.set_stylebox("scroll", "VScrollBar", panel_style(BACKGROUND, BORDER, 0, 0))
	theme.set_stylebox("grabber", "VScrollBar", panel_style(BORDER, BORDER, 0, 3))
	theme.set_stylebox("grabber_highlight", "VScrollBar", panel_style(TEXT_MUTED, TEXT_MUTED, 0, 3))
	theme.set_stylebox("grabber_pressed", "VScrollBar", panel_style(ACCENT, ACCENT, 0, 3))

	return theme


static func theme() -> Theme:
	if _theme == null:
		_theme = build_theme()
	return _theme


static func panel_style(background: Color, border: Color, border_width: int = 1, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_border_width_all(border_width)
	style.border_color = border
	style.set_corner_radius_all(radius)
	style.content_margin_left = SPACE_MD
	style.content_margin_right = SPACE_MD
	style.content_margin_top = SPACE_SM + 2
	style.content_margin_bottom = SPACE_SM + 2
	return style


# =====================================================================
# Node helpers
# =====================================================================

static func label(text: String, size: int = FONT_BODY, color: Color = TEXT_PRIMARY, bold: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if bold:
		node.add_theme_constant_override("outline_size", 0)
	return node


## Small uppercase tag used for section labels and status markers.
static func tag(text: String, color: Color = TEXT_MUTED) -> Label:
	return label(text.to_upper(), FONT_TAG, color)


static func heading(text: String, size: int = FONT_HEADING, color: Color = TEXT_PRIMARY) -> Label:
	return label(text, size, color)


static func spacer(height: int = SPACE_MD) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func vbox(separation: int = SPACE_SM) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func hbox(separation: int = SPACE_SM) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


## A themed card: PanelContainer + border + inner padding + vertical content box.
static func card(background: Color = SURFACE, border: Color = BORDER) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(background, border))
	return panel


static func card_body(panel: PanelContainer, separation: int = SPACE_XS) -> VBoxContainer:
	var body := vbox(separation)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(body)
	return body


static func button(text: String, color: Color = TEXT_PRIMARY, height: int = BUTTON_HEIGHT) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0, height)
	node.add_theme_font_size_override("font_size", FONT_BODY)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_hover_color", color)
	node.focus_mode = Control.FOCUS_NONE
	return node


static func progress_bar(value: float, bar_color: Color = ACCENT) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = clampf(value, 0, 100)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, PROGRESS_BAR_HEIGHT)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("fill", panel_style(bar_color, bar_color, 0, 3))
	return bar


## Centered reading column, so wide windows do not stretch cards absurdly.
## The width is recomputed on resize: capped at max_width on desktop sizes and
## allowed to shrink on narrower windows, which prevents clipping.
static func centered_column(parent: Control, max_width: int, horizontal_pad: int = SPACE_LG) -> VBoxContainer:
	var host := Control.new()
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	host.add_child(center)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(max_width, 0)
	center.add_child(scroll)

	var column := vbox(SPACE_MD)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)

	host.resized.connect(func() -> void:
		var available: float = host.size.x - float(horizontal_pad) * 2.0
		var width: float = minf(float(max_width), maxf(320.0, available))
		scroll.custom_minimum_size = Vector2(width, 0)
	)
	return column


## Thousands-separated integer, matching the C# "N0" formatting.
static func format_int(value: int) -> String:
	var text: String = str(absi(value))
	var result: String = ""
	var count: int = 0
	for index in range(text.length() - 1, -1, -1):
		result = text[index] + result
		count += 1
		if count % 3 == 0 and index > 0:
			result = "," + result
	return ("-" if value < 0 else "") + result


static func format_money(value: int) -> String:
	return "$" + format_int(value)
