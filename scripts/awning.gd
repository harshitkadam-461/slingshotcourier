@tool
extends StaticBody2D
## The bounce comes from PhysicsMaterial, not a scripted second launch.

@export var canopy_width := 290.0
var wobble := 0.0
var clock := 0.0


func _ready() -> void:
	set_meta("impact_kind", "awning")
	if Engine.is_editor_hint():
		return
	var material := PhysicsMaterial.new()
	material.bounce = 0.94
	material.friction = 0.08
	physics_material_override = material
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(canopy_width, 16)
	shape.shape = rectangle
	add_child(shape)


func react() -> void:
	wobble = 1.0


func _process(delta: float) -> void:
	clock += delta
	wobble = maxf(0.0, wobble - delta * 2.0)
	queue_redraw()


func _draw() -> void:
	var half := canopy_width / 2.0
	var dip := sin(clock * 32.0) * wobble * 6.0
	draw_line(Vector2(-half + 12, 7), Vector2(-half + 42, 69), Color("263c41"), 5.0)
	draw_line(Vector2(half - 12, 7), Vector2(half - 42, 69), Color("263c41"), 5.0)
	draw_rect(Rect2(-half - 4, -12, canopy_width + 8, 26), Color("24393e"))
	for i in 10:
		var color := Color("f185a4") if i % 2 == 0 else Color("fff2df")
		var x := -half + i * canopy_width / 10.0
		draw_rect(Rect2(x, -8 + dip, canopy_width / 10.0, 25), color)
		draw_circle(Vector2(x + canopy_width / 20.0, 16 + dip), canopy_width / 20.0, color)
	draw_line(Vector2(-half, -8), Vector2(half, -8), Color("fff7e9"), 3.0)
