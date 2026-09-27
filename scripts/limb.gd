extends RigidBody2D
## Each limb is a real rigid body. Only the small pose torque is artificial.

var courier: RigidBody2D
var rest_angle := 0.0
var previous_velocity := Vector2.ZERO


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not is_instance_valid(courier):
		return
	# A damped rotational spring tucks the limb; collisions still move it.
	if courier.pose_enabled():
		var target: float = courier.rotation + rest_angle
		var error := wrapf(target - rotation, -PI, PI)
		var relative_spin: float = angular_velocity - courier.angular_velocity
		var grounded: bool = courier.current_state == courier.State.READY
		var stiffness := 12500.0 if grounded else 1800.0
		var damping := 750.0 if grounded else 160.0
		state.apply_torque(clampf(error * stiffness - relative_spin * damping, -24000.0, 24000.0))
	state.angular_velocity = clampf(state.angular_velocity, -22.0, 22.0)
	for i in state.get_contact_count():
		var collider := state.get_contact_collider_object(i)
		var normal := state.get_contact_local_normal(i)
		var closing_speed := maxf(0.0, -previous_velocity.dot(normal))
		if closing_speed > courier.hard_impact_speed:
			courier.report_impact.call_deferred(collider, closing_speed, global_position)
	previous_velocity = state.linear_velocity
