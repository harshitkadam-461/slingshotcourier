extends Camera2D
## Smooth look-ahead, speed zoom, and short impact shakes.

var courier: RigidBody2D
var shake_strength := 0.0
var clock := 0.0


func _ready() -> void:
	position_smoothing_enabled = false
	zoom = Vector2.ONE


func snap_to_courier() -> void:
	if is_instance_valid(courier):
		global_position = courier.global_position + Vector2(270, -120)
		zoom = Vector2.ONE
		reset_smoothing()


func _process(delta: float) -> void:
	if not is_instance_valid(courier):
		return
	clock += delta
	var speed := courier.linear_velocity.length()
	var aiming: bool = courier.current_state == courier.State.AIMING
	var target_zoom := lerpf(1.0, 0.70, clampf((speed - 240.0) / 1000.0, 0.0, 1.0))
	if aiming:
		target_zoom = zoom.x
	zoom = zoom.lerp(Vector2.ONE * target_zoom, 1.0 - exp(-delta * 3.0))
	var look := Vector2(clampf(courier.linear_velocity.x * 0.22 + 220.0, -180.0, 370.0), -120.0)
	var target := courier.global_position + look
	target.y = minf(target.y, 655.0)
	if not aiming:
		global_position = global_position.lerp(target, 1.0 - exp(-delta * 4.5))
	shake_strength = maxf(0.0, shake_strength - delta * 24.0)
	offset = Vector2(sin(clock * 89.0), cos(clock * 103.0)) * shake_strength


func shake(speed: float) -> void:
	shake_strength = maxf(shake_strength, clampf(speed / 85.0, 3.0, 15.0))
