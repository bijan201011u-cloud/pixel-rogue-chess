extends SceneTree
## Visual QA: renders key screens to PNG via Xvfb + OpenGL3.
## Run: xvfb-run -s "-screen 0 1080x1920x24" godot --path . -s res://tests/screenshots.gd

const OUT := "/tmp/qa_shots"

func _initialize() -> void:
        _run()

func _run() -> void:
        DirAccess.make_dir_recursive_absolute(OUT)
        var root := get_root()
        for pair in [["SaveManager", "res://scripts/managers/save_manager.gd"],
                        ["I18n", "res://scripts/managers/i18n.gd"],
                        ["AudioManager", "res://scripts/managers/audio_manager.gd"],
                        ["RunManager", "res://scripts/managers/run_manager.gd"],
                        ["GameManager", "res://scripts/managers/game_manager.gd"]]:
                if not root.has_node(pair[0]):
                        var n := Node.new()
                        n.name = pair[0]
                        n.set_script(load(pair[1]))
                        root.add_child(n)
        var i18n = root.get_node("I18n")
        var gm = root.get_node("GameManager")
        var rm = root.get_node("RunManager")

        # force a known language state (persisted cfg may say otherwise)
        var sm = root.get_node("SaveManager")
        sm.language = "en"
        i18n.lang = "en"

        await process_frame
        await process_frame

        # 1. main menu EN
        var menu = (load("res://scenes/main_menu/main_menu.tscn") as PackedScene).instantiate()
        root.add_child(menu)
        await _shot("1_menu_en")
        # 2. settings EN
        menu._on_settings()
        await _shot("2_settings_en")
        # 3. switch language -> FA (full retranslate)
        menu._on_language("fa")
        await _shot("3_settings_fa")
        menu._on_back()
        await _shot("4_menu_fa")
        # 4. difficulty modal FA
        menu._on_play_ai()
        await _shot("5_diff_fa")
        menu.queue_free()
        await process_frame

        # 5. map FA
        i18n.lang = "fa"
        rm.start_new_run()
        var map = (load("res://scenes/map/map.tscn") as PackedScene).instantiate()
        root.add_child(map)
        await _shot("6_map_fa")
        map.queue_free()
        i18n.lang = "en"
        await process_frame

        # 6. battle with pieces on normalized sprites + mid-animation
        rm.start_new_run()
        gm.pending_battle = {"node_id": "b1", "label": "BATTLE 1", "is_boss": false, "mode": "ai",
                        "depth": 1, "jitter": 0.9, "blunder": 0.18, "base_coins": 10}
        var battle = (load("res://scenes/chess/chess_battle.tscn") as PackedScene).instantiate()
        root.add_child(battle)
        await _shot("7_battle_start")

        # grant upgrades to show the active panel + make a capture for the toast
        rm.add_upgrade("knight_fury")
        rm.add_upgrade("pawn_tax")
        battle._refresh_upgrade_row()
        var StateC = load("res://scripts/chess/chess_state.gd")
        battle.state = load("res://scripts/chess/chess_rules.gd").state_from_fen(
                        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        battle.state.board[35] = -StateC.QUEEN  # black queen appears on d4
        battle.state.board[45] = StateC.KNIGHT  # white knight on f3 can take it
        battle.board_view.setup(battle.state, battle._compute_cell())
        battle._select_piece(45)
        await _shot("8_battle_selected")
        battle._on_square_tapped(35)  # Nxd4 -> capture + toast + animation + AI reply
        await create_timer(0.10).timeout
        await _shot("9_battle_anim_mid")
        await create_timer(0.5).timeout
        await _shot("10_battle_toast")
        var waited := 0
        while (battle.history.size() < 2 or battle.board_view.input_locked) and waited < 600:
                await create_timer(0.05).timeout
                waited += 1
        await _shot("11_battle_after_ai")

        # 6b. DEBUG ALIGNMENT MODE: center markers on every square
        battle.board_view.debug_alignment = true
        await _shot("11b_battle_debug_align")
        battle.board_view.debug_alignment = false

        # 7. pvp battle
        battle.queue_free()
        await process_frame
        gm.pending_battle = {"mode": "pvp", "node_id": "pvp", "label": "2P DUEL", "is_boss": false, "base_coins": 0}
        var pvp = (load("res://scenes/chess/chess_battle.tscn") as PackedScene).instantiate()
        root.add_child(pvp)
        await _shot("12_pvp")

        print("SCREENSHOTS DONE")
        quit(0)

func ChessRules_global():
        return load("res://scripts/chess/chess_rules.gd")

func _shot(name: String) -> void:
        await process_frame
        await process_frame
        var img := get_root().get_viewport().get_texture().get_image()
        img.save_png("%s/%s.png" % [OUT, name])
        print("shot: ", name)
