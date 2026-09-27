extends CanvasLayer
## Native Controls handle layout and focus. The small route diagram is drawn.

signal restart_requested
signal retry_requested
signal pause_requested
signal resume_requested
signal level_selected(index: int)
signal sound_toggled(muted: bool)

const INK = Color("23383d")
const PAPER = Color("edf2df")
const GOLD = Color("f4bd46")
const MINT = Color("b7e56e")

var surface: Control
var status_label: Label
var details_label: Label
var stats_label: Label
var route_selector: OptionButton
var pause_button: Button
var modal: ColorRect
var modal_title: Label
var modal_subtitle: Label
var modal_stats: Label
var primary: Button
var secondary: Button
var modal_kind := ""
var progress := 0.0
var power := 0.0
var aiming := false
var is_yard := false
var elapsed := 0.0
var launches := 0
var _status := "READY"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "sans-serif"])
	theme.default_font = font
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", PAPER)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("385056") if state != "hover" else Color("486269")
		style.set_corner_radius_all(4)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = GOLD
			style.set_border_width_all(2)
		theme.set_stylebox(state, "Button", style)
		theme.set_stylebox(state, "OptionButton", style)
	theme.set_color("font_color", "Button", PAPER)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	surface = Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.theme = theme
	add_child(surface)
	surface.draw.connect(_draw_surface)
	_build_header()
	_build_footer()
	_build_modal()


func _build_header() -> void:
	var header := HBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 26
	header.offset_right = -26
	header.offset_top = 16
	header.offset_bottom = 65
	header.add_theme_constant_override("separation", 16)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(header)
	var brand := HBoxContainer.new()
	brand.custom_minimum_size.x = 266
	brand.add_theme_constant_override("separation", 10)
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(brand)
	var icon := TextureRect.new()
	icon.texture = preload("res://assets/parcel.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(43, 43)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_child(icon)
	var brand_text := VBoxContainer.new()
	brand_text.add_theme_constant_override("separation", -2)
	brand_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_child(brand_text)
	brand_text.add_child(_label("SLINGSHOT", 22, PAPER))
	brand_text.add_child(_label("COURIER", 15, GOLD))
	var shipment := VBoxContainer.new()
	shipment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shipment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(shipment)
	shipment.add_child(_label("SAME-DAY / QUESTIONABLE METHODS", 11, Color("a3b9b6")))
	shipment.add_child(_label("One parcel. Across town.", 17, PAPER))
	route_selector = OptionButton.new()
	route_selector.custom_minimum_size = Vector2(172, 44)
	route_selector.add_item("Rooftop route")
	route_selector.add_item("Test yard")
	route_selector.tooltip_text = "Choose a level"
	route_selector.item_selected.connect(func(index: int): level_selected.emit(index))
	header.add_child(route_selector)
	var restart := _button("Restart", func(): restart_requested.emit())
	restart.tooltip_text = "Restart the whole route (R)"
	header.add_child(restart)
	pause_button = _button("Pause", func(): pause_requested.emit())
	pause_button.tooltip_text = "Pause / resume (Escape)"
	header.add_child(pause_button)
	var sound := _button("Sound", func(): pass)
	sound.toggle_mode = true
	sound.button_pressed = true
	sound.tooltip_text = "Toggle sound"
	sound.toggled.connect(func(enabled: bool): sound_toggled.emit(not enabled))
	header.add_child(sound)


func _build_footer() -> void:
	status_label = _label("READY", 25, GOLD)
	status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status_label.offset_left = 28
	status_label.offset_top = -91
	status_label.offset_right = 310
	status_label.offset_bottom = -58
	surface.add_child(status_label)
	details_label = _label("PARCEL SECURE", 12, Color("adbfba"))
	details_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	details_label.offset_left = 29
	details_label.offset_top = -52
	details_label.offset_right = 310
	details_label.offset_bottom = -31
	surface.add_child(details_label)
	stats_label = _label("", 18, PAPER)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	stats_label.offset_left = -310
	stats_label.offset_top = -85
	stats_label.offset_right = -28
	stats_label.offset_bottom = -28
	surface.add_child(stats_label)


func _build_modal() -> void:
	modal = ColorRect.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.color = Color(0.08, 0.15, 0.17, 0.70)
	modal.visible = false
	surface.add_child(modal)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -245
	panel.offset_right = 245
	panel.offset_top = -215
	panel.offset_bottom = 215
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(6)
	style.content_margin_left = 38
	style.content_margin_right = 38
	style.content_margin_top = 29
	style.content_margin_bottom = 29
	panel.add_theme_stylebox_override("panel", style)
	modal.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	panel.add_child(stack)
	var parcel := TextureRect.new()
	parcel.texture = preload("res://assets/parcel.svg")
	parcel.custom_minimum_size = Vector2(56, 56)
	parcel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	parcel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stack.add_child(parcel)
	modal_subtitle = _label("DISPATCH 014", 12, Color("607973"))
	modal_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(modal_subtitle)
	modal_title = _label("Delivered.", 38, INK)
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(modal_title)
	modal_stats = _label("", 17, INK)
	modal_stats.custom_minimum_size.y = 78
	modal_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(modal_stats)
	primary = _button("Another delivery", _on_primary)
	primary.custom_minimum_size.y = 45
	stack.add_child(primary)
	secondary = _button("Restart route", func(): restart_requested.emit())
	secondary.custom_minimum_size.y = 42
	stack.add_child(secondary)


func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(action)
	return button


func update_run(courier: RigidBody2D, goal_x: float, run_time: float, total_launches: int, checkpoint: int) -> void:
	elapsed = run_time
	launches = total_launches
	progress = clampf((courier.global_position.x - 230.0) / (goal_x - 230.0), 0.0, 1.0)
	aiming = courier.current_state == courier.State.AIMING
	power = courier.aim_drag.length() / courier.max_drag
	var states := ["READY", "LINING IT UP", "AIR MAIL", "ROUGH LANDING", "OOF.", "ON THE WIRE", "DELIVERED"]
	status_label.text = states[courier.current_state]
	status_label.add_theme_color_override("font_color", GOLD if not aiming else MINT)
	details_label.text = "POWER %03d%%" % roundi(power * 100) if aiming else "PARCEL SECURE  /  STOP %02d" % (checkpoint + 1)
	stats_label.text = "%02d LAUNCHES   /   %04.1f m/s\n%s" % [launches, courier.linear_velocity.length() / 100.0, format_time(elapsed)]
	surface.queue_redraw()


func _draw_surface() -> void:
	var size := surface.size
	surface.draw_rect(Rect2(0, 0, size.x, 81), INK)
	surface.draw_line(Vector2(0, 80), Vector2(size.x, 80), Color("47635f"), 1.0)
	surface.draw_rect(Rect2(0, size.y - 113, size.x, 113), INK)
	var left := 343.0
	var right := size.x - 351.0
	var y := size.y - 57.0
	var font := ThemeDB.fallback_font
	surface.draw_string(font, Vector2(left, y - 24), "ROOFTOP EXPRESS" if not is_yard else "TEST YARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("adbfba"))
	surface.draw_line(Vector2(left, y), Vector2(right, y), Color("526c67"), 4.0)
	surface.draw_line(Vector2(left, y), Vector2(lerpf(left, right, progress), y), MINT, 4.0)
	for i in 5:
		var x := lerpf(left, right, i / 4.0)
		surface.draw_circle(Vector2(x, y), 5.0, MINT if progress >= i / 4.0 else Color("688079"))
	surface.draw_circle(Vector2(lerpf(left, right, progress), y), 7.0, GOLD)
	surface.draw_string(font, Vector2(left, y + 28), "DISPATCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("adbfba"))
	surface.draw_string(font, Vector2(right - 67, y + 28), "RECEIVING", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("adbfba"))
	if aiming:
		surface.draw_rect(Rect2(29, size.y - 22, 248, 4), Color("526c67"))
		surface.draw_rect(Rect2(29, size.y - 22, power * 248, 4), MINT)


func show_modal(kind: String, breaks: int = 0) -> void:
	modal_kind = kind
	modal.visible = true
	secondary.visible = kind != "win"
	if kind == "win":
		modal_title.text = "Delivered."
		modal_subtitle.text = "SIGNED, SEALED, SLIGHTLY DENTED"
		modal_stats.text = "%s    /    %02d launches\n%d billboard demolished" % [format_time(elapsed), launches, breaks]
		primary.text = "Another delivery"
	elif kind == "fail":
		modal_title.text = "Missed the roof."
		modal_subtitle.text = "THE PARCEL HAS SEEN BETTER DAYS"
		modal_stats.text = "%02d launches    /    %s" % [launches, format_time(elapsed)]
		primary.text = "Retry from checkpoint"
	else:
		modal_title.text = "On a break."
		modal_subtitle.text = "DELIVERY IN PROGRESS"
		modal_stats.text = "%s    /    %02d launches" % [format_time(elapsed), launches]
		primary.text = "Resume delivery"
	primary.grab_focus()


func hide_modal() -> void:
	modal.visible = false
	modal_kind = ""
	get_viewport().gui_release_focus()


func _on_primary() -> void:
	match modal_kind:
		"pause": resume_requested.emit()
		"fail": retry_requested.emit()
		_: restart_requested.emit()


func format_time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]
