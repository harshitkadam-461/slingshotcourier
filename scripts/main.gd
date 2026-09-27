extends Node2D
## Game flow owns the level, not the courier. This keeps physics scripts small.

@export var enable_ragdoll := true
const COURIER = preload("res://scenes/courier.tscn")
const ROUTE = preload("res://scenes/route.tscn")
const YARD = preload("res://scenes/test_yard.tscn")

var level: Node2D
var courier: RigidBody2D
var cable: Node2D
var test_mode := false
var elapsed := 0.0
var total_launches := 0
var billboards_broken := 0
var wall_crashes := 0
var checkpoint := 0
var ended := false
var peak_speed := 0.0

@onready var camera: Camera2D = $CourierCamera
@onready var slingshot: Node2D = $Slingshot
@onready var hud: CanvasLayer = $HUD
@onready var sound: Node = $Sound


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for child in get_children():
		if child != hud:
			child.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Skyline.camera = camera
	hud.restart_requested.connect(restart)
	hud.retry_requested.connect(retry_checkpoint)
	hud.pause_requested.connect(toggle_pause)
	hud.resume_requested.connect(toggle_pause)
	hud.level_selected.connect(func(index: int): build_level(index == 1))
	hud.sound_toggled.connect(func(muted: bool): sound.muted = muted)
	get_window().focus_exited.connect(_on_focus_lost)
	var args := OS.get_cmdline_user_args()
	if "--no-limbs" in args:
		enable_ragdoll = false
	build_level("--yard" in args)


func build_level(yard: bool) -> void:
	get_tree().paused = false
	slingshot.cancel()
	if is_instance_valid(cable):
		cable.detach()
	if is_instance_valid(courier):
		remove_child(courier)
		courier.queue_free()
	if is_instance_valid(level):
		remove_child(level)
		level.queue_free()
	for effect in get_tree().get_nodes_in_group("transient_effect"):
		effect.queue_free()
	level = (YARD if yard else ROUTE).instantiate()
	level.name = "Level"
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	test_mode = yard
	elapsed = 0.0
	total_launches = 0
	billboards_broken = 0
	wall_crashes = 0
	peak_speed = 0.0
	checkpoint = 0
	ended = false
	cable = level.get_node_or_null("PowerLine")
	level.get_node("DeliveryZone").delivered.connect(_on_delivery)
	var billboard := level.get_node_or_null("Billboard")
	if billboard:
		billboard.shattered.connect(_on_billboard)
	if cable:
		cable.grabbed.connect(func(): sound.play("cable"))
	_spawn_courier(level.spawn_point)
	hud.is_yard = yard
	hud.route_selector.select(1 if yard else 0)
	hud.hide_modal()


func _spawn_courier(point: Vector2) -> void:
	courier = COURIER.instantiate()
	courier.position = point
	courier.enable_limbs = enable_ragdoll
	courier.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(courier)
	courier.launched.connect(_on_launch)
	courier.impacted.connect(_on_impact)
	slingshot.courier = courier
	camera.courier = courier
	camera.snap_to_courier()
	if is_instance_valid(cable):
		cable.courier = courier
		cable.has_previous_hook = false


func _process(delta: float) -> void:
	if not is_instance_valid(courier) or ended or get_tree().paused:
		return
	if total_launches > 0:
		elapsed += delta
	peak_speed = maxf(peak_speed, courier.linear_velocity.length())
	# Checkpoints require an actual settled landing, not just flying past a roof.
	if courier.current_state == courier.State.READY and not courier.is_parked:
		for i in range(checkpoint + 1, level.checkpoints.size()):
			var candidate: Vector2 = level.checkpoints[i]
			if absf(courier.position.x - candidate.x) < 170.0 and absf(courier.position.y - candidate.y) < 70.0:
				checkpoint = i
	if courier.global_position.y > 1140 or courier.global_position.x < -560 or courier.global_position.x > 4380:
		fail_delivery()
	hud.update_run(courier, level.goal_x, elapsed, total_launches, checkpoint)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_R:
			restart()
		KEY_ESCAPE:
			if slingshot.dragging:
				slingshot.cancel()
			else:
				toggle_pause()
		KEY_SPACE:
			if not ended and not get_tree().paused and is_instance_valid(cable) and is_instance_valid(cable.rider):
				cable.detach()


func _on_launch(_velocity: Vector2) -> void:
	total_launches += 1
	sound.play("launch")


func _on_impact(speed: float, point: Vector2, kind: String) -> void:
	camera.shake(speed)
	sound.play("glass" if kind == "billboard" else "impact")
	match kind:
		"awning":
			level.get_node("Awning").react()
			_popup("EXPRESS SERVICE!", point, Color("fff4df"))
		"wall":
			wall_crashes += 1
			_popup("OOF.", point, Color("f4bd46"))
		"billboard":
			_popup("NOT COVERED.", point, Color("fff4df"))
	_spawn_impact_lines(point, kind == "wall")


func _on_billboard(_point: Vector2) -> void:
	billboards_broken += 1


func _popup(text: String, point: Vector2, color: Color) -> void:
	var label := Label.new()
	label.add_to_group("transient_effect")
	label.text = text
	label.position = point + Vector2(-85, -100)
	label.z_index = 40
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("263c41"))
	label.add_theme_constant_override("outline_size", 7)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 55, 0.85)
	tween.tween_property(label, "modulate:a", 0.0, 0.85).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


func _spawn_impact_lines(point: Vector2, stars: bool) -> void:
	var effect := Node2D.new()
	effect.add_to_group("transient_effect")
	effect.position = point
	effect.z_index = 20
	effect.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(effect)
	for i in 9:
		var angle := i * TAU / 9.0
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2.RIGHT.rotated(angle) * 27, Vector2.RIGHT.rotated(angle) * 54])
		line.width = 4.0
		line.default_color = Color("f4bd46") if stars else Color("fff4df")
		effect.add_child(line)
	var tween := effect.create_tween().set_parallel(true)
	tween.tween_property(effect, "scale", Vector2.ONE * 1.8, 0.24)
	tween.tween_property(effect, "modulate:a", 0.0, 0.24)
	tween.chain().tween_callback(effect.queue_free)


func _on_delivery(_body: RigidBody2D) -> void:
	if ended:
		return
	ended = true
	# Area2D signals run during a physics query flush. Freeze outside that flush.
	_complete_delivery.call_deferred()


func _complete_delivery() -> void:
	if is_instance_valid(cable):
		cable.detach()
	slingshot.cancel()
	courier.finish_delivery()
	sound.play("win")
	hud.update_run(courier, level.goal_x, elapsed, total_launches, checkpoint)
	hud.show_modal("win", billboards_broken)
	# Keep the audio tail and UI alive while the city simulation is paused.
	sound.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true


func fail_delivery() -> void:
	if ended:
		return
	ended = true
	slingshot.cancel()
	hud.update_run(courier, level.goal_x, elapsed, total_launches, checkpoint)
	hud.show_modal("fail")
	get_tree().paused = true


func retry_checkpoint() -> void:
	get_tree().paused = false
	ended = false
	slingshot.cancel()
	if is_instance_valid(cable):
		cable.detach()
	remove_child(courier)
	courier.queue_free()
	_spawn_courier(level.checkpoints[checkpoint])
	hud.hide_modal()


func restart() -> void:
	build_level(test_mode)


func toggle_pause() -> void:
	if ended:
		return
	slingshot.cancel()
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		hud.show_modal("pause")
	else:
		hud.hide_modal()


func _on_focus_lost() -> void:
	if not ended and not get_tree().paused:
		slingshot.cancel()
		toggle_pause()
