extends StaticBody2D
## A larger Area2D notices fast bodies just before they reach the solid panel.

signal shattered(point: Vector2)

@export var break_speed := 340.0
const BROKEN_TEXTURE = preload("res://assets/billboard_broken.svg")
var broken := false


func _ready() -> void:
	set_meta("impact_kind", "billboard")
	$ImpactArea.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if broken or not body is RigidBody2D:
		return
	var courier: RigidBody2D = body if body.is_in_group("courier") else body.get_parent() as RigidBody2D
	if not is_instance_valid(courier) or not courier.is_in_group("courier"):
		return
	if courier.linear_velocity.length() >= break_speed:
		shatter.call_deferred(courier)


func shatter(courier: RigidBody2D) -> void:
	if broken or not is_instance_valid(courier):
		return
	broken = true
	$CollisionShape2D.set_deferred("disabled", true)
	$ImpactArea.set_deferred("monitoring", false)
	$Sprite2D.texture = BROKEN_TEXTURE
	$Lettering.hide()
	_spawn_debris(courier.linear_velocity)
	courier.report_impact(self, courier.linear_velocity.length(), global_position)
	shattered.emit(global_position)


func _spawn_debris(incoming: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 14:
		var chip := RigidBody2D.new()
		chip.name = "BillboardDebris"
		chip.add_to_group("debris")
		chip.position = global_position + Vector2(rng.randf_range(-95, 95), rng.randf_range(-45, 45))
		chip.collision_layer = 16
		chip.collision_mask = 1
		chip.mass = 0.08
		chip.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		var size := Vector2(rng.randf_range(12, 32), rng.randf_range(8, 22))
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = size
		shape.shape = rectangle
		chip.add_child(shape)
		var visual := Polygon2D.new()
		visual.polygon = PackedVector2Array([-size / 2, Vector2(size.x / 2, -size.y / 3), size / 2, Vector2(-size.x / 2, size.y / 3)])
		visual.color = Color("ef6c94") if i % 3 else Color("fff2df")
		chip.add_child(visual)
		get_parent().add_child(chip)
		chip.linear_velocity = incoming * 0.30 + Vector2(rng.randf_range(-180, 260), rng.randf_range(-270, -30))
		chip.angular_velocity = rng.randf_range(-12, 12)
		var tween := chip.create_tween()
		tween.tween_interval(4.0)
		tween.tween_property(chip, "modulate:a", 0.0, 0.8)
		tween.tween_callback(chip.queue_free)
