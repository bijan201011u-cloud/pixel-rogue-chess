extends Node
## Screenshot runner for visual QA (not part of the game).
## Run:  xvfb-run godot --path . res://tests/shot_runner.tscn

const OUT := "/home/z/my-project/scripts/shots/"


func _ready() -> void:
	_shoot_all()


func _shoot_all() -> void:
	var rm = get_node("/root/RunManager")
	var gm = get_node("/root/GameManager")
	rm.start_new_run()
	await _wait(8)

	# 1. main menu
	var menu = _mount("res://scenes/main_menu/main_menu.tscn")
	await _wait(10)
	await _shot("01_menu")
	menu._on_settings()
	await _wait(6)
	await _shot("02_settings")
	menu.queue_free()
	await _wait(4)

	# 2. map
	await _wait(4)
	var map = _mount("res://scenes/map/map.tscn")
	await _wait(10)
	await _shot("03_map_fresh")
	map._show_info("b1")
	await _wait(6)
	await _shot("04_map_node_info")
	map.queue_free()
	await _wait(4)

	# 3. battle with a few moves played
	gm.pending_battle = {"node_id": "b1", "label": "BATTLE 1", "is_boss": false,
			"depth": 2, "jitter": 0.5, "blunder": 0.0, "base_coins": 10}
	var battle = _mount("res://scenes/chess/chess_battle.tscn")
	await _wait(10)
	await _shot("05_battle_start")
	battle._on_square_tapped(52)  # select e2
	await _wait(6)
	await _shot("06_battle_selected")
	battle._on_square_tapped(36)  # e4
	var w := 0
	while battle.ai_thinking and w < 600:
		await _wait(1)
		w += 1
	await _wait(6)
	await _shot("07_battle_after_ai")
	battle.queue_free()
	await _wait(4)

	# 4. boss intro + corrupted board
	rm.add_upgrade("knight_fury")
	rm.add_upgrade("momentum")
	rm.win_streak = 2
	gm.pending_battle = {"node_id": "boss", "label": "BOSS", "is_boss": true,
			"depth": 3, "jitter": 0.0, "blunder": 0.0, "base_coins": 50}
	var boss = _mount("res://scenes/chess/chess_battle.tscn")
	await _wait(10)
	await _shot("08_boss_intro")
	boss._on_boss_begin()
	await _wait(6)
	await _shot("09_boss_board")
	boss.queue_free()
	await _wait(4)

	# 5. reward
	gm.pending_battle = {"node_id": "b1", "label": "BATTLE 1", "is_boss": false,
			"depth": 1, "jitter": 0.9, "blunder": 0.18, "base_coins": 10}
	rm.upgrades = ["knight_fury"]
	var reward = _mount("res://scenes/reward/reward.tscn")
	await _wait(10)
	await _shot("10_reward")
	reward.queue_free()
	await _wait(4)

	# 6. event
	gm.pending_event = load("res://scripts/roguelike/event_db.gd").EVENTS[0]
	var ev = _mount("res://scenes/event/event_screen.tscn")
	await _wait(10)
	await _shot("11_event")
	ev.queue_free()
	await _wait(4)

	get_tree().quit()


func _mount(path: String) -> Node:
	var packed = load(path)
	var inst = packed.instantiate()
	get_tree().root.add_child(inst)
	return inst


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + name + ".png")
	print("shot: ", name)
