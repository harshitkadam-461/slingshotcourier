extends RigidBody2D
## Root body, slingshot state, and a small force-driven ragdoll rig.
## No walking/jumping controller: all travel starts with an impulse or gravity.

signal launched(velocity: Vector2)
signal impacted(speed: float, point: Vector2, kind: String)
signal state_changed(state_name: String)

enum State { READY, AIMING, FLYING, FLAILING, STUNNED, SLIDING, DELIVERED }

@export var max_drag := 160.0
@export var max_launch_speed := 1180.0
@export var minimum_drag := 12.0
@export var hard_impact_speed := 360.0
@export var flail_duration := 0.95
@export var wall_stun_duration := 1.15
@export var enable_limbs := true

const LimbScript = preload("res://scripts/limb.gd")
const HEAD = preload("res://assets/head.svg")

var current_state: State = State.READY
var limbs: Array[RigidBody2D] = []
var pins: Array[PinJoint2D] = []
var recovery_left := 0.0
var impact_cooldown := 0.0
var cable_cooldown := 0.0
var grounded_time := 0.0
var previous_velocity := Vector2.ZERO
var aim_drag := Vector2.ZERO
var squash := Vector2.ONE
var is_parked := true
var launch_count := 0
var age := 0.0
var _aim_was_parked := true
var _ray_exclusions: Array[RID] = []

@onready var torso_sprite: Sprite2D = $TorsoSprite


func _ready() -> void:
	_ray_exclusions.append(get_rid())
	if enable_limbs:
		# pivot, centre, radius, length, mass, angle, color
		_add_limb("LeftArm", Vector2(-12, -9), Vector2(-21, 2), 6, 26, 0.14, 0.42, Color("cb514f"))
		_add_limb("RightArm", Vector2(12, -9), Vector2(19, 2), 6, 26, 0.14, -0.36, Color("ed7762"))
		_add_limb("LeftLeg", Vector2(-8, 17), Vector2(-11, 33), 7, 32, 0.20, 0.13, Color("263c43"))
		_add_limb("RightLeg", Vector2(8, 17), Vector2(12, 33), 7, 32, 0.20, -0.16, Color("355058"))
		_add_limb("Head", Vector2(0, -18), Vector2(0, -31), 13, 27, 0.25, 0.0, Color("f4bd46"))
	_set_frozen(true)


func _add_limb(limb_name: String, pivot: Vector2, center: Vector2, radius: float,
		length: float, limb_mass: float, angle: float, color: Color) -> void:
	var limb := RigidBody2D.new()
	limb.name = limb_name
	limb.set_script(LimbScript)
	limb.courier = self
	limb.rest_angle = angle
	# Crucial: a child physics body must NOT inherit its parent's moving transform.
	limb.top_level = true
	limb.position = to_global(center)
	limb.rotation = rotation + angle
	limb.mass = limb_mass
	limb.inertia = 45.0 if limb_name == "Head" else 30.0
	limb.collision_layer = 4
	limb.collision_mask = 1
	limb.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	limb.contact_monitor = true
	limb.max_contacts_reported = 4
	limb.angular_damp = 1.5
	limb.physics_material_override = physics_material_override
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = radius
	capsule.height = length
	shape.shape = capsule
	limb.add_child(shape)
	if limb_name == "Head":
		var sprite := Sprite2D.new()
		sprite.texture = HEAD
		limb.add_child(sprite)
	else:
		var outline := Line2D.new()
		outline.points = PackedVector2Array([Vector2(0, -length * 0.28), Vector2(0, length * 0.28)])
		outline.width = radius * 2.0 + 3.0
		outline.default_color = Color("23383d")
		outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
		outline.end_cap_mode = Line2D.LINE_CAP_ROUND
		limb.add_child(outline)
		var fill := outline.duplicate() as Line2D
		fill.width = radius * 2.0 - 2.0
		fill.default_color = color
		limb.add_child(fill)
		var tip := Polygon2D.new()
		tip.polygon = PackedVector2Array([Vector2(-radius, 5), Vector2(radius, 5), Vector2(radius + 3, 15), Vector2(-radius, 15)])
		tip.color = Color("f6c496") if "Arm" in limb_name else Color("172d32")
		limb.add_child(tip)
	limb.z_index = 1 if limb_name == "Head" or limb_name == "RightArm" else -1
	add_child(limb)
	limbs.append(limb)
	_ray_exclusions.append(limb.get_rid())
	var pin := PinJoint2D.new()
	pin.name = limb_name + "Pin"
	pin.top_level = true
	pin.position = to_global(pivot)
	add_child(pin)
	pin.node_a = get_path()
	pin.node_b = limb.get_path()
	pin.disable_collision = true
	pin.softness = 0.05
	# The neck keeps a modest limit even when the rest of the rig is flailing.
	if limb_name == "Head":
		pin.angular_limit_enabled = true
		pin.angular_limit_lower = -0.55
		pin.angular_limit_upper = 0.55
	pins.append(pin)


func _physics_process(delta: float) -> void:
	age += delta
	impact_cooldown = maxf(0.0, impact_cooldown - delta)
	cable_cooldown = maxf(0.0, cable_cooldown - delta)
	recovery_left = maxf(0.0, recovery_left - delta)
	if current_state in [State.DELIVERED, State.AIMING, State.SLIDING] or is_parked:
		return
	if recovery_left <= 0.0 and current_state in [State.FLAILING, State.STUNNED]:
		set_state(State.FLYING)
	if recovery_left <= 0.0 and linear_velocity.length() < 175.0 and _has_support():
		grounded_time += delta
		linear_damp = 2.4
		if grounded_time > 0.22:
			set_state(State.READY)
	else:
		grounded_time = 0.0
		linear_damp = 0.08
		if current_state == State.READY:
			set_state(State.FLYING)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if pose_enabled() and not freeze:
		# Self-right using torque, never by overwriting the simulated rotation.
		var lean := clampf(state.linear_velocity.x * 0.00020, -0.25, 0.25)
		if current_state == State.READY or current_state == State.SLIDING:
			lean = 0.0
		var error := wrapf(lean - rotation, -PI, PI)
		var grounded := current_state == State.READY or grounded_time > 0.0
		var stiffness := 125000.0 if grounded else 36000.0
		var damping := 19000.0 if grounded else 7200.0
		state.apply_torque(clampf(error * stiffness - state.angular_velocity * damping, -160000.0, 160000.0))
	state.angular_velocity = clampf(state.angular_velocity, -15.0, 15.0)
	for i in state.get_contact_count():
		var normal := state.get_contact_local_normal(i)
		var closing_speed := maxf(0.0, -previous_velocity.dot(normal))
		if closing_speed > hard_impact_speed:
			report_impact.call_deferred(state.get_contact_collider_object(i), closing_speed, global_position)
	previous_velocity = state.linear_velocity


func _process(delta: float) -> void:
	var speed_ratio := clampf(linear_velocity.length() / 1400.0, 0.0, 1.0)
	var target := Vector2(1.0 - speed_ratio * 0.10, 1.0 + speed_ratio * 0.16)
	if current_state == State.AIMING:
		var charge := aim_drag.length() / max_drag
		target = Vector2(1.0 + charge * 0.20, 1.0 - charge * 0.20)
	squash = squash.lerp(target, 1.0 - exp(-delta * 11.0))
	# Scale only the art. Scaling a physics body would also distort its joints.
	torso_sprite.scale = squash
	queue_redraw()


func _draw() -> void:
	if current_state == State.READY or current_state == State.AIMING:
		var pulse := sin(age * 4.0) * 2.0
		draw_arc(Vector2.ZERO, 58.0 + pulse, 0.0, TAU, 48, Color(1, 1, 0.95, 0.70), 2.0, true)
	if current_state == State.STUNNED:
		for i in 3:
			var angle := age * 5.0 + i * TAU / 3.0
			var center := Vector2(cos(angle) * 27.0, -58.0 + sin(angle) * 7.0).rotated(-rotation)
			draw_line(center - Vector2(5, 0), center + Vector2(5, 0), Color("f4bd46"), 3.0)
			draw_line(center - Vector2(0, 5), center + Vector2(0, 5), Color("f4bd46"), 3.0)


func _has_support() -> bool:
	for offset in [-16.0, 0.0, 16.0]:
		var start := global_position + Vector2(offset, 0)
		var query := PhysicsRayQueryParameters2D.create(start, start + Vector2(0, 62), 1, _ray_exclusions)
		var result := get_world_2d().direct_space_state.intersect_ray(query)
		if not result.is_empty() and result.normal.y < -0.35:
			return true
	return false


func pose_enabled() -> bool:
	return recovery_left <= 0.0 and current_state != State.DELIVERED


func can_aim() -> bool:
	return current_state == State.READY and recovery_left <= 0.0


func begin_aim() -> bool:
	if not can_aim():
		return false
	_aim_was_parked = is_parked
	_set_frozen(true)
	aim_drag = Vector2.ZERO
	set_state(State.AIMING)
	return true


func update_aim(drag: Vector2) -> void:
	aim_drag = drag.limit_length(max_drag)


func cancel_aim() -> void:
	if current_state != State.AIMING:
		return
	aim_drag = Vector2.ZERO
	_set_frozen(_aim_was_parked)
	set_state(State.READY)


func release_aim() -> bool:
	if current_state != State.AIMING:
		return false
	if aim_drag.length() < minimum_drag:
		cancel_aim()
		return false
	# Opposite to the pull. Both input distance and final impulse are clamped.
	var velocity := -aim_drag / max_drag * max_launch_speed
	launch_velocity(velocity)
	return true


func launch_velocity(velocity: Vector2) -> void:
	velocity = velocity.limit_length(max_launch_speed)
	is_parked = false
	_set_frozen(false)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	apply_central_impulse((velocity * mass).limit_length(max_launch_speed * mass))
	# Matching limb impulses prevent a huge joint shock at the launch frame.
	for limb in limbs:
		limb.linear_velocity = Vector2.ZERO
		limb.angular_velocity = 0.0
		limb.apply_central_impulse(velocity * limb.mass)
	recovery_left = 0.0
	grounded_time = 0.0
	aim_drag = Vector2.ZERO
	launch_count += 1
	squash = Vector2(0.74, 1.30)
	set_state(State.FLYING)
	launched.emit(velocity)


func report_impact(collider: Object, speed: float, point: Vector2) -> void:
	if not is_instance_valid(collider) or impact_cooldown > 0.0:
		return
	if current_state in [State.AIMING, State.DELIVERED, State.SLIDING] or is_parked:
		return
	var kind: String = collider.get_meta("impact_kind", "roof")
	recovery_left = wall_stun_duration if kind == "wall" else flail_duration
	# Several limbs may strike the same wall. Do not restart the stun per limb.
	impact_cooldown = recovery_left
	set_state(State.STUNNED if kind == "wall" else State.FLAILING)
	squash = Vector2(1.40, 0.65)
	if kind == "wall":
		apply_torque_impulse(signf(previous_velocity.x + 0.01) * 1800.0)
	impacted.emit(speed, point, kind)


func begin_slide() -> void:
	is_parked = false
	recovery_left = 0.0
	set_state(State.SLIDING)


func end_slide() -> void:
	cable_cooldown = 0.65
	set_state(State.FLYING)


func finish_delivery() -> void:
	set_state(State.DELIVERED)
	_set_frozen(true)


func set_state(next: State) -> void:
	if next == current_state:
		return
	current_state = next
	state_changed.emit(State.keys()[next])


func _set_frozen(value: bool) -> void:
	freeze = value
	if value:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
	else:
		sleeping = false
	for limb in limbs:
		limb.freeze = value
		if value:
			limb.linear_velocity = Vector2.ZERO
			limb.angular_velocity = 0.0
		else:
			limb.sleeping = false
