@tool
extends Node2D
## Real PinJoint2D cable links, plus a spring-suspended sliding grip.
## The grip is an arcade trolley: it follows the current link geometry.
## Godot solves the rope and the courier suspension; no rope solver is coded here.

signal grabbed
signal released

@export var end_offset := Vector2(830, 145)
@export_range(6, 40) var segment_count := 24
@export var sag := 24.0
@export var grab_radius := 56.0

var segments: Array[RigidBody2D] = []
var lengths: Array[float] = []
var cable_points := PackedVector2Array()
var courier: RigidBody2D
var rider: RigidBody2D
var trolley: StaticBody2D
var suspension: DampedSpringJoint2D
var travel := 0.0
var slide_speed := 0.0
var slide_time := 0.0
var previous_hook := Vector2.ZERO
var has_previous_hook := false
var active_segment := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var start_anchor := _anchor("StartAnchor", Vector2.ZERO)
	var end_anchor := _anchor("EndAnchor", end_offset)
	var previous_body: PhysicsBody2D = start_anchor
	for i in segment_count:
		var a := _initial_point(float(i) / segment_count)
		var b := _initial_point(float(i + 1) / segment_count)
		var segment := RigidBody2D.new()
		segment.name = "CableLink%02d" % i
		segment.position = (a + b) / 2.0
		segment.rotation = (b - a).angle()
		segment.mass = 0.42
		segment.gravity_scale = 0.35
		segment.linear_damp = 2.8
		segment.angular_damp = 3.0
		segment.collision_layer = 8
		segment.collision_mask = 0
		var shape := CollisionShape2D.new()
		var capsule := CapsuleShape2D.new()
		capsule.radius = 3.0
		capsule.height = a.distance_to(b)
		shape.shape = capsule
		shape.rotation = PI / 2.0
		segment.add_child(shape)
		add_child(segment)
		segments.append(segment)
		lengths.append(a.distance_to(b))
		_pin(previous_body, segment, a)
		previous_body = segment
	_pin(previous_body, end_anchor, end_offset)
	_refresh_points()


func _initial_point(fraction: float) -> Vector2:
	return end_offset * fraction + Vector2(0, sin(fraction * PI) * sag)


func _anchor(anchor_name: String, point: Vector2) -> StaticBody2D:
	var anchor := StaticBody2D.new()
	anchor.name = anchor_name
	anchor.position = point
	anchor.collision_layer = 0
	anchor.collision_mask = 0
	add_child(anchor)
	return anchor


func _pin(a: PhysicsBody2D, b: PhysicsBody2D, point: Vector2) -> void:
	var pin := PinJoint2D.new()
	pin.position = point
	add_child(pin)
	pin.node_a = a.get_path()
	pin.node_b = b.get_path()
	pin.disable_collision = true
	pin.softness = 0.015


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	_refresh_points()
	if is_instance_valid(rider):
		_advance_rider(delta)
	elif is_instance_valid(courier):
		_try_grab()
	queue_redraw()


func _refresh_points() -> void:
	cable_points.clear()
	cable_points.append(global_position)
	for i in segments.size():
		cable_points.append(segments[i].to_global(Vector2(lengths[i] / 2.0, 0)))
	# Anchored endpoints stay exact even if a solver link stretches briefly.
	if not cable_points.is_empty():
		cable_points[cable_points.size() - 1] = to_global(end_offset)


func _try_grab() -> void:
	var hook := courier.global_position + Vector2(0, -32)
	if courier.current_state not in [courier.State.FLYING, courier.State.FLAILING] or courier.cable_cooldown > 0.0:
		previous_hook = hook
		has_previous_hook = true
		return
	var closest_distance := INF
	var closest_travel := 0.0
	var distance_so_far := 0.0
	for i in cable_points.size() - 1:
		var a := cable_points[i]
		var b := cable_points[i + 1]
		var closest := Geometry2D.get_closest_point_to_segment(hook, a, b)
		var distance := hook.distance_to(closest)
		# Sweeping the hook avoids missing a thin cable during a fast launch.
		if has_previous_hook:
			var crossing: Variant = Geometry2D.segment_intersects_segment(previous_hook, hook, a, b)
			if crossing != null:
				closest = crossing
				distance = 0.0
		if distance < closest_distance:
			closest_distance = distance
			closest_travel = distance_so_far + a.distance_to(closest)
		distance_so_far += a.distance_to(b)
	if closest_distance < grab_radius and closest_travel < distance_so_far - 55.0:
		attach(courier, closest_travel)
	previous_hook = hook
	has_previous_hook = true


func attach(body: RigidBody2D, distance_along: float) -> void:
	if is_instance_valid(rider):
		return
	rider = body
	travel = distance_along
	slide_time = 0.0
	var sample := sample_cable(travel)
	var point: Vector2 = sample.point
	var tangent: Vector2 = sample.tangent
	slide_speed = clampf(absf(rider.linear_velocity.dot(tangent)), 240.0, 620.0)
	trolley = _anchor("SlidingGrip", to_local(point))
	suspension = DampedSpringJoint2D.new()
	suspension.position = to_local(point)
	# Local +Y is the spring axis. Place its second anchor at the torso.
	var to_body := rider.global_position - point
	suspension.rotation = to_body.angle() - PI / 2.0
	suspension.length = maxf(1.0, to_body.length())
	suspension.rest_length = 38.0
	suspension.stiffness = 190.0
	suspension.damping = 16.0
	add_child(suspension)
	suspension.node_a = trolley.get_path()
	suspension.node_b = rider.get_path()
	suspension.disable_collision = true
	rider.begin_slide()
	grabbed.emit()


func _advance_rider(delta: float) -> void:
	slide_time += delta
	var sample := sample_cable(travel)
	var tangent: Vector2 = sample.tangent
	# Gravity accelerates the grip down the wire; a minimum roll avoids stalling.
	slide_speed = clampf(slide_speed + (980.0 * tangent.y + 50.0) * delta, 200.0, 690.0)
	travel += slide_speed * delta
	sample = sample_cable(travel)
	trolley.global_position = sample.point
	active_segment = sample.index
	segments[active_segment].apply_central_force(Vector2(0, 65.0))
	if sample.at_end or slide_time > 6.0 or rider.global_position.distance_to(trolley.global_position) > 230.0:
		detach()


func sample_cable(distance_along: float) -> Dictionary:
	var remaining := maxf(distance_along, 0.0)
	for i in cable_points.size() - 1:
		var a := cable_points[i]
		var b := cable_points[i + 1]
		var length := a.distance_to(b)
		if remaining <= length or i == cable_points.size() - 2:
			return {"point": a.lerp(b, clampf(remaining / maxf(length, 0.001), 0.0, 1.0)),
				"tangent": (b - a).normalized(), "index": mini(i, segments.size() - 1),
				"at_end": i == cable_points.size() - 2 and remaining >= length - 10.0}
		remaining -= length
	return {"point": global_position, "tangent": Vector2.RIGHT, "index": 0, "at_end": true}


func detach() -> void:
	if is_instance_valid(suspension):
		suspension.node_a = NodePath()
		suspension.node_b = NodePath()
		suspension.queue_free()
	if is_instance_valid(trolley):
		trolley.queue_free()
	if is_instance_valid(rider) and rider.current_state != rider.State.DELIVERED:
		rider.end_slide()
	rider = null
	suspension = null
	trolley = null
	released.emit()


func _draw() -> void:
	var points := PackedVector2Array()
	if Engine.is_editor_hint():
		for i in 33:
			points.append(_initial_point(float(i) / 32.0))
	else:
		for point in cable_points:
			points.append(to_local(point))
	if points.size() < 2:
		return
	draw_polyline(points, Color("253c40"), 6.0, true)
	draw_polyline(points, Color("d2e6d5"), 1.5, true)
	for index in [0, points.size() - 1]:
		var point := points[index]
		draw_line(point + Vector2(0, -35), point + Vector2(0, 210), Color("344d4c"), 9.0)
		draw_line(point + Vector2(-22, -7), point + Vector2(22, -7), Color("344d4c"), 7.0)
		draw_circle(point, 8.0, Color("f4bd46"))
	if is_instance_valid(rider) and is_instance_valid(trolley):
		var grip := to_local(trolley.global_position)
		draw_line(grip, to_local(rider.global_position + Vector2(0, -18)), Color("f4bd46"), 3.0, true)
		draw_circle(grip, 9.0, Color("f4bd46"))
		draw_circle(grip, 4.0, Color("24383b"))
