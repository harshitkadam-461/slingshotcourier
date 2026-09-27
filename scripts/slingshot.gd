extends Node2D
## Mouse/touch input stays separate from the rigid-body simulation.

var courier: RigidBody2D
var dragging := false
var drag_start := Vector2.ZERO
var drag_screen := Vector2.ZERO
var active_touch := -1
var rubber: Line2D
var rubber_shadow: Line2D
var trajectory := PackedVector2Array()


func _ready() -> void:
	z_index = 30
	rubber_shadow = _make_line(Color("263d41"), 8.0)
	rubber = _make_line(Color("f4bd46"), 4.0)


func _make_line(color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.default_color = color
	line.width = width
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(line)
	return line


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(courier):
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start(event.position)
			elif dragging and active_touch == -1:
				_release()
	elif event is InputEventMouseMotion and dragging and active_touch == -1:
		_update(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			if _start(event.position):
				active_touch = event.index
		elif event.index == active_touch and not event.pressed:
			_release()
	elif event is InputEventScreenDrag and event.index == active_touch:
		_update(event.position)


func _input(event: InputEvent) -> void:
	# Finish an existing drag even when its release lands over a UI button.
	# Starting a drag still uses _unhandled_input so clicking UI cannot launch.
	if not dragging:
		return
	var consumed := false
	if event is InputEventMouseMotion and active_touch == -1:
		_update(event.position)
		consumed = true
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and active_touch == -1:
			_release()
			consumed = true
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel()
			consumed = true
	elif event is InputEventScreenDrag and event.index == active_touch:
		_update(event.position)
		consumed = true
	elif event is InputEventScreenTouch and event.index == active_touch and not event.pressed:
		_release()
		consumed = true
	if consumed:
		get_viewport().set_input_as_handled()


func _start(screen_position: Vector2) -> bool:
	var on_screen: Vector2 = courier.get_global_transform_with_canvas().origin
	if screen_position.distance_to(on_screen) > 76.0:
		return false
	if not courier.begin_aim():
		return false
	dragging = true
	drag_start = screen_position
	drag_screen = Vector2.ZERO
	return true


func _update(screen_position: Vector2) -> void:
	drag_screen = (screen_position - drag_start).limit_length(courier.max_drag)
	courier.update_aim(drag_screen)


func _release() -> void:
	courier.release_aim()
	dragging = false
	active_touch = -1


func cancel() -> void:
	if is_instance_valid(courier):
		courier.cancel_aim()
	dragging = false
	active_touch = -1


func _physics_process(_delta: float) -> void:
	trajectory.clear()
	if not dragging or not is_instance_valid(courier):
		rubber.clear_points()
		rubber_shadow.clear_points()
		queue_redraw()
		return
	var start := courier.global_position
	var zoom := get_viewport().get_camera_2d().zoom.x
	var pulled := start + drag_screen / zoom
	var points := PackedVector2Array([start + Vector2(-12, 3), pulled, start + Vector2(12, 3)])
	rubber.points = points
	rubber_shadow.points = points
	var velocity: Vector2 = -courier.aim_drag / courier.max_drag * courier.max_launch_speed
	var previous := start
	# Ballistic preview is deliberately short: a bounce changes the actual path.
	for i in range(1, 29):
		var time := i * 0.045
		var point := start + velocity * time + Vector2(0, 490.0 * time * time)
		var query := PhysicsRayQueryParameters2D.create(previous, point, 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			trajectory.append(hit.position)
			break
		trajectory.append(point)
		previous = point
	queue_redraw()


func _draw() -> void:
	for i in trajectory.size():
		var alpha := 1.0 - float(i) / 36.0
		draw_circle(trajectory[i], 3.4, Color(1.0, 0.99, 0.91, alpha))
