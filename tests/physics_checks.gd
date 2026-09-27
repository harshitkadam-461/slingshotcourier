extends SceneTree
## Integration tests run real Godot physics. No external testing framework.
## Use --fixed-fps 120 for a fast, deterministic run with 120 Hz physics.

var game: Node2D
var failures: Array[String] = []
var passed := 0
var delivery_events := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(4)
	game.sound.muted = true
	game.get_window().focus_exited.disconnect(game._on_focus_lost)
	await _test_launch()
	await _test_input_edges()
	await _test_landing()
	await _test_awning()
	await _test_billboard()
	await _test_wall()
	await _test_cable()
	await _test_delivery_restart()
	await _test_full_route()
	await _test_yard()
	print("\nRESULT: %d passed, %d failed" % [passed, failures.size()])
	for failure in failures:
		print("FAIL: " + failure)
	paused = false
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _test_launch() -> void:
	var p: RigidBody2D = game.courier
	var spawn := p.global_position
	await _frames(120)
	_check(p.global_position.distance_to(spawn) < 0.5, "static spawn stays on launch pad")
	_check(p.limbs.size() == 5 and p.pins.size() == 5, "five rigid limbs attached by five native pins")
	var independent := true
	for limb in p.limbs:
		independent = independent and limb.top_level and limb.get_parent() == p
	_check(independent, "child limbs have independent world transforms")
	p.begin_aim()
	p.update_aim(Vector2(2, 3))
	_check(not p.release_aim() and p.launch_count == 0, "tiny drag cancels without spending a launch")
	p.begin_aim()
	p.update_aim(Vector2(-500, 450))
	_check(absf(p.aim_drag.length() - p.max_drag) < 0.01, "drag distance clamps to max power")
	p.cancel_aim()
	_check(p.freeze and p.current_state == p.State.READY, "cancel restores static launch state")
	# Pass real input events through the game's slingshot handler.
	var at: Vector2 = p.get_global_transform_with_canvas().origin
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = at
	press.pressed = true
	game.slingshot._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = at + Vector2(-128, 96)
	game.slingshot._unhandled_input(motion)
	await _frames(2)
	_check(game.slingshot.rubber.get_point_count() == 3, "rubber band draws during an active pull")
	press.pressed = false
	game.slingshot._unhandled_input(press)
	await _frames(6)
	_check(p.linear_velocity.x > 700 and p.linear_velocity.y < -400, "release produces opposite-direction flight")
	_check(p.linear_velocity.length() <= p.max_launch_speed + 5, "initial launch speed is clamped")
	_check(game.total_launches == 1 and not p.begin_aim(), "one launch counted; aiming is blocked in midair")
	await _frames(60)
	_check(game.camera.zoom.x < 0.95, "camera widens at high speed")
	_check(_limb_span(p) < 95, "ragdoll stays connected during flight")


func _test_landing() -> void:
	game.restart()
	await _frames(3)
	var p: RigidBody2D = game.courier
	p.launch_velocity(Vector2(685, -800))
	var settled := false
	for i in 840:
		await physics_frame
		if p.current_state == p.State.READY:
			settled = true
			break
		if game.ended:
			break
	print("LANDING: pos=%s state=%s angle=%.3f span=%.2f" % [p.position, p.State.keys()[p.current_state], p.rotation, _limb_span(p)])
	_check(settled, "courier settles on a roof and can relaunch")
	if settled:
		await _frames(100)
		print("RIGHTING: pos=%s angle=%.3f state=%s" % [p.position, p.rotation, p.State.keys()[p.current_state]])
		_check(absf(wrapf(p.rotation, -PI, PI)) < 0.45, "torso self-rights after impact recovery")
		_check(p.begin_aim(), "a settled landing accepts another pull")
		p.cancel_aim()


func _test_input_edges() -> void:
	game.restart()
	await _frames(6)
	var at: Vector2 = game.courier.get_global_transform_with_canvas().origin
	var press := InputEventMouseButton.new()
	press.position = at
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	_check(game.slingshot.dragging, "native input dispatch starts a courier drag")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(1050, 40)
	root.push_input(motion, true)
	var release := press.duplicate() as InputEventMouseButton
	release.position = motion.position
	release.pressed = false
	root.push_input(release, true)
	_check(not game.slingshot.dragging and game.total_launches == 1, "release over the toolbar still ends the drag")
	game.restart()
	await _frames(6)
	at = game.courier.get_global_transform_with_canvas().origin
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.position = at
	touch.pressed = true
	root.push_input(touch, true)
	_check(game.slingshot.dragging and game.slingshot.active_touch == 2, "touch press captures one finger")
	var other := InputEventScreenTouch.new()
	other.index = 3
	other.position = at + Vector2(100, 100)
	other.pressed = true
	root.push_input(other, true)
	var other_release := other.duplicate() as InputEventScreenTouch
	other_release.pressed = false
	root.push_input(other_release, true)
	_check(game.slingshot.dragging and game.total_launches == 0, "a second finger cannot release the active pull")
	var swipe := InputEventScreenDrag.new()
	swipe.index = 2
	swipe.position = at + Vector2(-100, 110)
	root.push_input(swipe, true)
	var touch_release := touch.duplicate() as InputEventScreenTouch
	touch_release.pressed = false
	touch_release.position = swipe.position
	root.push_input(touch_release, true)
	_check(not game.slingshot.dragging and game.total_launches == 1, "touch release launches exactly once")
	game.restart()
	await _frames(6)
	game.courier.begin_aim()
	game.slingshot.dragging = true
	game._on_focus_lost()
	_check(paused and not game.slingshot.dragging and game.courier.current_state == game.courier.State.READY, "focus loss safely cancels a pull and pauses")
	game.toggle_pause()


func _test_awning() -> void:
	await _place(Vector2(873, 335))
	var p: RigidBody2D = game.courier
	p.launch_velocity(Vector2(0, 650))
	var bounced := false
	var flailed := false
	var fastest_up := 0.0
	for i in 120:
		await physics_frame
		bounced = bounced or p.linear_velocity.y < -300
		fastest_up = minf(fastest_up, p.linear_velocity.y)
		flailed = flailed or p.current_state == p.State.FLAILING
	print("AWNING: fastest_up=%.2f pos=%s" % [fastest_up, p.position])
	_check(bounced, "native high-bounce awning reverses downward velocity")
	_check(flailed, "hard impact temporarily releases the tuck pose")


func _test_billboard() -> void:
	game.restart()
	await _frames(3)
	await _place(Vector2(2170, 423))
	game.cable.courier = null
	game.courier.launch_velocity(Vector2(1060, -35))
	var billboard: StaticBody2D = game.level.get_node("Billboard")
	for i in 100:
		await physics_frame
		if billboard.broken:
			break
	await _frames(3)
	_check(billboard.broken and billboard.get_node("CollisionShape2D").disabled, "fast courier breaks billboard and removes solid panel")
	_check(billboard.get_node("Sprite2D").texture == billboard.BROKEN_TEXTURE, "broken billboard swaps its sprite")
	_check(get_nodes_in_group("debris").size() == 14 and game.billboards_broken == 1, "one collision emits one batch of physical debris")
	await _place(Vector2(230, 509))
	await _frames(620)
	_check(get_nodes_in_group("debris").is_empty(), "debris fades and is freed")


func _test_wall() -> void:
	await _place(Vector2(2800, 533))
	var p: RigidBody2D = game.courier
	p.launch_velocity(Vector2(900, -35))
	var stunned := false
	for i in 120:
		await physics_frame
		if p.current_state == p.State.STUNNED:
			stunned = true
			break
	_check(stunned and game.wall_crashes > 0, "brick-wall contact triggers crash stun")
	await _frames(250)
	print("WALL: pos=%s state=%s recovery=%.2f ended=%s" % [p.position, p.State.keys()[p.current_state], p.recovery_left, game.ended])
	_check(p.current_state != p.State.STUNNED and p.recovery_left <= 0, "crash stun expires and pose control resumes")
	_check(_limb_span(p) < 100, "ragdoll remains connected after wall collision")


func _test_cable() -> void:
	game.restart()
	await _frames(120)
	var cable: Node2D = game.cable
	var point: Vector2 = cable.sample_cable(180).point
	await _place(point + Vector2(0, 36))
	game.courier.launch_velocity(Vector2(520, 0))
	await _frames(8)
	_check(cable.segments.size() == 24, "power line has 24 native rigid-body links")
	_check(is_instance_valid(cable.rider), "flying courier automatically catches a nearby cable")
	var start: float = cable.travel
	await _frames(75)
	_check(cable.travel > start + 120, "grip progresses along simulated cable geometry")
	if is_instance_valid(cable.rider):
		_check(cable.rider.global_position.distance_to(cable.trolley.global_position) < 150, "spring suspension keeps courier near sliding grip")
	for i in 450:
		await physics_frame
		if not is_instance_valid(cable.rider):
			break
	_check(not is_instance_valid(cable.rider) and game.courier.current_state != game.courier.State.SLIDING, "cable endpoint releases courier")
	# Verify a manual drop removes the actual suspension joint too.
	point = cable.sample_cable(180).point
	await _place(point + Vector2(0, 36))
	game.courier.launch_velocity(Vector2(400, 0))
	await _frames(6)
	cable.detach()
	await _frames(2)
	_check(cable.suspension == null and game.courier.cable_cooldown > 0, "manual cable drop removes joint and prevents immediate regrab")


func _test_delivery_restart() -> void:
	await _place(Vector2(3320, 490))
	var goal: Area2D = game.level.get_node("DeliveryZone")
	goal.delivered.connect(func(_body: RigidBody2D): delivery_events += 1)
	game.courier.launch_velocity(Vector2(650, -140))
	await _frames(100)
	_check(game.ended and paused and goal.completed, "torso enters delivery Area2D and ends the level")
	_check(game.hud.modal_kind == "win" and game.courier.freeze, "win receipt appears and courier is frozen")
	_check(delivery_events == 1, "delivery fires once despite multiple body parts")
	game.restart()
	await _frames(6)
	_check(not paused and not game.ended and game.total_launches == 0 and game.checkpoint == 0, "restart resets pause, completion, launches, and checkpoint")
	_check(not game.level.get_node("Billboard").broken and game.cable.rider == null, "restart restores billboard and cable")
	game.checkpoint = 1
	await _place(Vector2(1500, 1180))
	await _frames(3)
	_check(game.hud.modal_kind == "fail", "falling below the skyline shows retry UI")
	game.retry_checkpoint()
	await _frames(3)
	_check(game.courier.position.distance_to(game.level.checkpoints[1]) < 1 and not paused, "checkpoint retry respawns at the saved rooftop")
	game.toggle_pause()
	_check(paused and game.hud.modal_kind == "pause", "pause shows native resume controls")
	game.toggle_pause()
	_check(not paused and not game.hud.modal.visible, "resume restores gameplay")


func _test_yard() -> void:
	game.enable_ragdoll = false
	game.build_level(true)
	await _frames(6)
	_check(game.test_mode and game.courier.limbs.is_empty() and game.cable == null, "isolated test yard runs without limbs or cable")
	game.courier.begin_aim()
	game.courier.update_aim(Vector2(-100, 100))
	game.courier.release_aim()
	await _frames(12)
	_check(game.courier.position.x > 260 and game.courier.position.y < 480, "torso-only test yard launches with native impulse")


func _test_full_route() -> void:
	game.restart()
	await _frames(6)
	game.courier.launch_velocity(Vector2(685, -800))
	await _await_landing()
	print("ROUTE stop 1: %s" % game.courier.position)
	if not game.ended:
		game.courier.launch_velocity(Vector2(600, -700))
		await _await_landing()
		print("ROUTE stop 2: %s, billboard=%d" % [game.courier.position, game.billboards_broken])
	for i in 6:
		if game.ended:
			break
		var p: RigidBody2D = game.courier
		var target := Vector2(3530, 480)
		var duration := 1.75 if p.position.x < 2800 else 1.15
		var velocity := (target - p.position - Vector2(0, 490 * duration * duration)) / (duration * 0.94)
		if p.position.x > 2840 and p.position.x < 3020:
			# A courier touching the tall chimney must first clear it vertically.
			velocity = Vector2(65, -1040)
		p.launch_velocity(velocity)
		await _await_landing()
		print("ROUTE stop %d: %s state=%s" % [i + 3, p.position, p.State.keys()[p.current_state]])
	_check(game.level.get_node("DeliveryZone").completed, "complete rooftop route from dispatch without teleporting")
	_check(game.billboards_broken == 1, "complete route traverses and breaks the billboard")


func _await_landing() -> void:
	for i in 1500:
		await physics_frame
		if game.ended or game.courier.current_state == game.courier.State.READY:
			break
	await process_frame


func _place(point: Vector2) -> void:
	# Make scene mutations during idle, never during the physics-frame signal.
	await process_frame
	paused = false
	game.ended = false
	game.slingshot.cancel()
	if is_instance_valid(game.cable):
		game.cable.detach()
	game.remove_child(game.courier)
	game.courier.queue_free()
	game._spawn_courier(point)
	game.hud.hide_modal()
	await _frames(3)


func _limb_span(p: RigidBody2D) -> float:
	var span := 0.0
	for limb in p.limbs:
		span = maxf(span, p.global_position.distance_to(limb.global_position))
	return span


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + message)
	else:
		failures.append(message)
		print("FAIL: " + message)
