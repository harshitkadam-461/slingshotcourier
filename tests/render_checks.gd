extends SceneTree
## Run with a real renderer, not --headless. Captures are generated artifacts.

var game: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.get_window().focus_exited.disconnect(game._on_focus_lost)
	game.sound.muted = true
	await _frames(6)
	await _capture("01_dispatch")
	game.courier.begin_aim()
	game.courier.update_aim(Vector2(-100, 112))
	game.slingshot.dragging = true
	game.slingshot.drag_screen = Vector2(-100, 112)
	await _frames(3)
	await _capture("02_aim")
	game.slingshot._release()
	await _frames(70)
	await _capture("03_flight")
	game.courier.finish_delivery()
	game.camera.courier = null
	game.camera.global_position = Vector2(2490, 405)
	game.camera.zoom = Vector2(0.9, 0.9)
	await _frames(3)
	await _capture("04_billboard")
	game.level.get_node("Billboard").shatter(game.courier)
	await _frames(8)
	await _capture("05_debris")
	game.camera.global_position = Vector2(3420, 395)
	game.hud.show_modal("win", 1)
	await _frames(3)
	await _capture("06_receipt")
	game.hud.hide_modal()
	game.restart()
	root.size = Vector2i(960, 540)
	await _frames(6)
	await _capture("07_small_window")
	game.queue_free()
	await process_frame
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png("res://verification/" + name + ".png")
	print("CAPTURE %s: %dx%d, save=%s" % [name, image.get_width(), image.get_height(), error_string(error)])
