@tool
extends Area2D

signal delivered(courier: RigidBody2D)

var completed := false
var clock := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	# Only the torso counts. Loose debris or an outstretched foot cannot win.
	if completed or not body.is_in_group("courier"):
		return
	completed = true
	set_deferred("monitoring", false)
	delivered.emit(body)


func _process(delta: float) -> void:
	clock += delta
	queue_redraw()


func _draw() -> void:
	var color := Color("b7e56e") if not completed else Color("f4bd46")
	draw_rect(Rect2(-104, -64, 208, 125), Color(color, 0.13))
	draw_rect(Rect2(-104, 47, 208, 14), color)
	for x in [-104, 104]:
		draw_line(Vector2(x, -64), Vector2(x, 61), color, 3.0)
		draw_line(Vector2(x, -64), Vector2(x - signf(x) * 22, -64), color, 3.0)
	var float_y := sin(clock * 2.8) * 5.0
	draw_texture_rect(preload("res://assets/parcel.svg"), Rect2(-24, -29 + float_y, 48, 48), false)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-74, -126), "DELIVERY ZONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("263c41"))
