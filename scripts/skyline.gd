extends Node2D
## Slow-moving layers are drawn relative to the camera for native 2D parallax.

var camera: Camera2D


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(camera):
		return
	var focus := camera.global_position
	draw_rect(Rect2(focus - Vector2(4000, 3000), Vector2(8000, 6000)), Color("c5e8e2"))
	# Broad cloud shapes are built from arcs and rectangles.
	for i in range(-2, 10):
		var cloud := Vector2(i * 470 + focus.x * 0.78, 90 + (i % 3) * 60 + focus.y * 0.62)
		draw_circle(cloud, 20.0, Color("e7f4e8"))
		draw_circle(cloud + Vector2(28, -13), 31.0, Color("e7f4e8"))
		draw_circle(cloud + Vector2(62, 0), 20.0, Color("e7f4e8"))
		draw_rect(Rect2(cloud + Vector2(0, -5), Vector2(62, 25)), Color("e7f4e8"))
	_draw_layer(focus, 0.70, 340, Color("a4cec4"), 97)
	_draw_layer(focus, 0.42, 490, Color("79afa6"), 32)


func _draw_layer(focus: Vector2, parallax: float, base_height: float, color: Color, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(-8, 40):
		var width := rng.randf_range(75, 155)
		var height := rng.randf_range(105, 310)
		var x := i * 163 + focus.x * parallax
		var y := base_height + focus.y * parallax * 0.55
		draw_rect(Rect2(x, y - height, width, height + 1800), color)
		if i % 3 == 0:
			draw_rect(Rect2(x + width * 0.3, y - height - 22, width * 0.4, 22), color)
		if parallax < 0.5:
			for row in 5:
				for col in 3:
					draw_rect(Rect2(x + 16 + col * 29, y - height + 24 + row * 33, 10, 15), color.lightened(0.14))
