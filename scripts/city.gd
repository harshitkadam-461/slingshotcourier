@tool
extends Node2D
## Layout data stays in one place. Rectangles become native StaticBody2D roofs.
## The drawing code is placeholder art; collisions use the same rectangles.

@export var test_yard := false

const INK = Color("263c41")
var buildings: Array[Dictionary] = []
var checkpoints: Array[Vector2] = []
var spawn_point := Vector2(230, 509)
var goal_x := 3570.0


func _ready() -> void:
	if test_yard:
		buildings = [
			{"rect": Rect2(-400, 560, 1050, 850), "color": Color("39726b"), "label": "TEST YARD"},
			{"rect": Rect2(740, 650, 410, 750), "color": Color("d2ae58"), "label": "02"},
			{"rect": Rect2(1260, 560, 550, 850), "color": Color("568e7b"), "label": "RECEIVING"},
		]
		checkpoints = [spawn_point, Vector2(1360, 509)]
		goal_x = 1610.0
	else:
		buildings = [
			{"rect": Rect2(-400, 560, 1010, 850), "color": Color("39726b"), "label": "DISPATCH / 01"},
			{"rect": Rect2(705, 715, 350, 690), "color": Color("dfb65b"), "label": "CAFE ROSA"},
			{"rect": Rect2(1170, 605, 510, 800), "color": Color("738b9d"), "label": "EAST BLOCK"},
			{"rect": Rect2(1940, 735, 310, 670), "color": Color("cd8173"), "label": "LAUNDRY"},
			{"rect": Rect2(2330, 630, 490, 775), "color": Color("77987b"), "label": "PRESS HOUSE"},
			{"rect": Rect2(2850, 630, 270, 775), "color": Color("d9b254"), "label": "07"},
			{"rect": Rect2(3250, 570, 670, 835), "color": Color("39726b"), "label": "RECIPIENT / 08"},
		]
		checkpoints = [spawn_point, Vector2(1450, 554), Vector2(2670, 579), Vector2(3360, 519)]
	if not Engine.is_editor_hint():
		for building in buildings:
			_add_solid(building.rect, "Roof", "roof")
		if not test_yard:
			_add_solid(Rect2(2950, 470, 60, 160), "BrickWall", "wall")
	queue_redraw()


func _add_solid(rect: Rect2, body_name: String, kind: String) -> void:
	var body := StaticBody2D.new()
	body.name = body_name
	body.position = rect.get_center()
	body.collision_layer = 1
	body.collision_mask = 6 | 16
	body.set_meta("impact_kind", kind)
	var material := PhysicsMaterial.new()
	material.friction = 0.78
	material.bounce = 0.02
	body.physics_material_override = material
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _draw() -> void:
	for building in buildings:
		_draw_building(building.rect, building.color, building.label)
	_draw_depot()
	if test_yard:
		return
	_draw_water_tank(Vector2(1270, 605))
	_draw_water_tank(Vector2(3760, 570))
	_draw_antenna(Vector2(550, 560))
	_draw_antenna(Vector2(2770, 630))
	# Billboard legs and maintenance walkway.
	for x in [2420, 2600]:
		draw_line(Vector2(x, 480), Vector2(x, 630), INK, 11.0)
	draw_line(Vector2(2350, 526), Vector2(2670, 526), INK, 9.0)
	for i in 8:
		draw_line(Vector2(2632, 543 + i * 11), Vector2(2650, 543 + i * 11), INK, 3.0)
	_draw_wall(Rect2(2950, 470, 60, 160))
	# A rooftop door is the visual destination behind the Area2D marker.
	draw_rect(Rect2(3508, 398, 126, 172), INK)
	draw_rect(Rect2(3517, 408, 108, 156), Color("d7e7cc"))
	draw_rect(Rect2(3530, 421, 82, 48), Color("7daa9c"))
	draw_circle(Vector2(3602, 506), 4.0, INK)
	draw_string(ThemeDB.fallback_font, Vector2(3544, 449), "08", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, INK)


func _draw_building(rect: Rect2, color: Color, title: String) -> void:
	draw_rect(rect, color)
	draw_rect(Rect2(rect.position + Vector2(0, 14), Vector2(rect.size.x, 17)), color.darkened(0.22))
	draw_rect(Rect2(rect.position + Vector2(-6, -3), Vector2(rect.size.x + 12, 10)), INK)
	draw_rect(Rect2(rect.position + Vector2(-6, -3), Vector2(rect.size.x + 12, 4)), Color("e7eed7"))
	var rows := 6
	var columns := int(rect.size.x / 78.0)
	for row in rows:
		for col in columns:
			var position_2d := rect.position + Vector2(28 + col * 78, 112 + row * 101)
			var window := Rect2(position_2d, Vector2(37, 52))
			draw_rect(Rect2(position_2d - Vector2(4, 4), Vector2(45, 60)), color.darkened(0.17))
			draw_rect(window, Color("294d50"))
			if (row + col * 3) % 4 != 0:
				draw_rect(Rect2(position_2d + Vector2(4, 4), Vector2(29, 20)), Color("abc8b1"))
			draw_line(position_2d + Vector2(-5, 56), position_2d + Vector2(43, 56), color.lightened(0.23), 4.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(27, 70), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("e9efda"))


func _draw_depot() -> void:
	# Landing pad, small parcel stack, and a cloth dispatch pennant.
	draw_rect(Rect2(159, 548, 141, 10), Color("f4bd46"))
	for i in 7:
		draw_line(Vector2(159 + i * 20, 558), Vector2(171 + i * 20, 549), INK, 4.0)
	draw_line(Vector2(93, 560), Vector2(93, 397), INK, 5.0)
	draw_colored_polygon(PackedVector2Array([Vector2(93, 400), Vector2(172, 411), Vector2(93, 438)]), Color("ed655b"))
	draw_texture_rect(preload("res://assets/parcel.svg"), Rect2(9, 516, 42, 42), false)
	draw_texture_rect(preload("res://assets/parcel.svg"), Rect2(47, 524, 34, 34), false)
	draw_string(ThemeDB.fallback_font, Vector2(161, 600), "DISPATCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f4bd46"))


func _draw_water_tank(base: Vector2) -> void:
	for x in [-30.0, 30.0]:
		draw_line(base + Vector2(x, 0), base + Vector2(x, -52), INK, 6.0)
	draw_line(base + Vector2(-30, -3), base + Vector2(30, -52), INK, 3.0)
	draw_rect(Rect2(base + Vector2(-46, -145), Vector2(92, 96)), Color("c6aba0"))
	for x in range(-40, 41, 10):
		draw_line(base + Vector2(x, -143), base + Vector2(x, -51), Color("a08f8b"), 2.0)
	for y in [-131, -67]:
		draw_line(base + Vector2(-47, y), base + Vector2(47, y), INK, 5.0)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-53, -145), base + Vector2(0, -174), base + Vector2(53, -145)]), INK)


func _draw_antenna(base: Vector2) -> void:
	draw_line(base, base + Vector2(0, -109), INK, 3.0)
	draw_line(base + Vector2(-35, -77), base + Vector2(35, -87), INK, 3.0)
	for i in 4:
		var point := base + Vector2(-26 + i * 17, -78 - i * 3)
		draw_line(point + Vector2(0, -12), point + Vector2(0, 12), INK, 2.0)


func _draw_wall(rect: Rect2) -> void:
	draw_rect(rect, Color("bd655e"))
	for row in 8:
		var y := rect.position.y + row * 20
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color("f3be98"), 2.0)
		var x := rect.position.x + (15 if row % 2 else 30)
		for column in 2:
			draw_line(Vector2(x + column * 30, y), Vector2(x + column * 30, y + 20), Color("f3be98"), 2.0)
	draw_rect(Rect2(rect.position - Vector2(5, 4), Vector2(rect.size.x + 10, 9)), INK)
