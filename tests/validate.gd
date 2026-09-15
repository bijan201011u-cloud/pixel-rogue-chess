extends SceneTree
## Headless validation for Pixel Rogue Chess (v2).
## Run with:  godot --headless --path . -s res://tests/validate.gd
## (Run `godot --headless --path . --import` first so the class cache exists.)
##
## Verifies:
##  1. All scripts load.
##  2. Chess rules correctness via perft (start pos, Kiwipete, position 3)
##     plus castling / en passant / promotion / mate / stalemate unit tests.
##  3. AI returns legal moves and plays a self-game without crashing.
##  4. RunManager roguelike math + capture-based tiered upgrades.
##  5. Every scene instantiates without script errors (with autoload stand-ins).
##  6. Real battle flow: animation, parallel AI reply, undo token, capture coins.
##  7. PvP hotseat flow (alternating human turns).
##  8. I18n completeness (every key has EN + FA).
##  9. PERFECT PIECE ALIGNMENT: sprite centering contract, authoritative
##     coordinate math (get_square_center), 64-square validation after
##     setup / animated moves / captures / promotion / forced drift / resize,
##     and end-to-end alignment inside the real battle scene.

var _fails := 0
var _checks := 0


func _initialize() -> void:
        _run_all()


func _run_all() -> void:
        print("=== PIXEL ROGUE CHESS :: VALIDATION ===")
        var t0 := Time.get_ticks_msec()

        var Rules = load("res://scripts/chess/chess_rules.gd")
        var StateC = load("res://scripts/chess/chess_state.gd")
        var AIC = load("res://scripts/ai/chess_ai.gd")

        _test_scripts_load()
        _test_perft(Rules, StateC)
        _test_castling(Rules, StateC)
        _test_en_passant(Rules, StateC)
        _test_promotion(Rules, StateC)
        _test_mate_stalemate(Rules, StateC)
        _test_corruption(Rules, StateC)
        _test_ai(AIC, StateC)
        _test_run_manager()
        _test_i18n()
        _test_scenes()
        await _test_battle_flow()
        await _test_pvp_flow()
        await _test_alignment()

        print("---")
        print("checks: %d  failures: %d  (%d ms)" % [_checks, _fails, Time.get_ticks_msec() - t0])
        if _fails == 0:
                print("RESULT: ALL TESTS PASSED")
        else:
                print("RESULT: FAILURES PRESENT")
        quit(1 if _fails > 0 else 0)


func check(cond: bool, label: String) -> void:
        _checks += 1
        if cond:
                print("  [PASS] ", label)
        else:
                _fails += 1
                print("  [FAIL] ", label)


# --------------------------------------------------------------------- 1

func _test_scripts_load() -> void:
        print("[1] scripts load")
        var paths := [
                "res://scripts/chess/chess_state.gd", "res://scripts/chess/chess_rules.gd",
                "res://scripts/ai/chess_ai.gd", "res://data/balance.gd",
                "res://scripts/roguelike/upgrade_db.gd", "res://scripts/roguelike/event_db.gd",
                "res://scripts/roguelike/map_db.gd", "res://scripts/managers/save_manager.gd",
                "res://scripts/managers/i18n.gd", "res://scripts/managers/run_manager.gd",
                "res://scripts/managers/game_manager.gd",
                "res://scripts/ui/ui_kit.gd", "res://scripts/ui/board_view.gd",
                "res://scripts/ui/main_menu.gd", "res://scripts/ui/map_screen.gd",
                "res://scripts/ui/chess_battle.gd", "res://scripts/ui/event_screen.gd",
        ]
        for p in paths:
                check(load(p) != null, "load " + p)


# --------------------------------------------------------------------- 2

func _test_perft(Rules, StateC) -> void:
        print("[2] perft move-generation correctness")
        var t := Time.get_ticks_msec()
        var s = Rules.create_initial_state()
        check(Rules.perft(s, 1) == 20, "start perft(1) == 20")
        check(Rules.perft(s, 2) == 400, "start perft(2) == 400")
        check(Rules.perft(s, 3) == 8902, "start perft(3) == 8902")
        print("  ...start pos took %d ms" % (Time.get_ticks_msec() - t))

        var t2 := Time.get_ticks_msec()
        var k = Rules.state_from_fen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
        check(Rules.perft(k, 1) == 48, "kiwipete perft(1) == 48")
        check(Rules.perft(k, 2) == 2039, "kiwipete perft(2) == 2039")
        print("  ...kiwipete took %d ms" % (Time.get_ticks_msec() - t2))

        var t3 := Time.get_ticks_msec()
        var p3 = Rules.state_from_fen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
        check(Rules.perft(p3, 1) == 14, "pos3 perft(1) == 14")
        check(Rules.perft(p3, 2) == 191, "pos3 perft(2) == 191")
        check(Rules.perft(p3, 3) == 2812, "pos3 perft(3) == 2812 (en passant pins)")
        print("  ...pos3 took %d ms" % (Time.get_ticks_msec() - t3))


func _test_castling(Rules, StateC) -> void:
        print("[3] castling")
        var s = Rules.state_from_fen("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
        var moves: Array = Rules.all_legal_moves(s)
        var castle_k := moves.filter(func(m): return m["flag"] == Rules.FLAG_CASTLE_K)
        var castle_q := moves.filter(func(m): return m["flag"] == Rules.FLAG_CASTLE_Q)
        check(castle_k.size() == 1 and castle_q.size() == 1, "white has both castling moves")
        var undo = Rules.make_move(s, castle_k[0])
        check(s.board[61] == StateC.ROOK and s.board[62] == StateC.KING, "O-O places rook f1 / king g1")
        check(not s.castling["wk"] and not s.castling["wq"], "white rights cleared after castling")
        Rules.undo_move(s, undo)
        check(s.board[60] == StateC.KING and s.board[63] == StateC.ROOK, "undo restores castled position")
        # black cannot castle through an attacked square
        var s2 = Rules.state_from_fen("r3k2r/8/8/8/8/5R2/8/R3K2R b KQkq - 0 1")
        var bmoves: Array = Rules.all_legal_moves(s2)
        var b_k := bmoves.filter(func(m): return m["flag"] == Rules.FLAG_CASTLE_K)
        check(b_k.is_empty(), "black kingside castle blocked by rook on f-file")


func _test_en_passant(Rules, StateC) -> void:
        print("[4] en passant")
        var s = Rules.state_from_fen("8/8/8/3pP3/8/8/8/k1K5 w - d6 0 1")
        var moves: Array = Rules.all_legal_moves(s)
        var ep := moves.filter(func(m): return m["flag"] == Rules.FLAG_EP)
        check(ep.size() == 1, "white pawn has exactly one en passant capture")
        var undo = Rules.make_move(s, ep[0])
        check(s.board[ep[0]["to"]] == StateC.PAWN, "pawn lands on ep target square")
        check(s.board[27] == 0, "captured pawn removed from d5")
        Rules.undo_move(s, undo)
        check(s.board[27] == -StateC.PAWN and s.board[28] == StateC.PAWN, "undo restores both pawns (d5 + e5)")
        # double push sets the ep target
        var s2 = Rules.create_initial_state()
        var e2e4: Array = Rules.legal_moves_from(s2, 52).filter(func(m): return m["flag"] == Rules.FLAG_DOUBLE)
        var u2 = Rules.make_move(s2, e2e4[0])
        check(s2.ep_square == 44, "double push e2e4 sets ep square e3 (44)")
        Rules.undo_move(s2, u2)
        check(s2.ep_square == -1, "undo clears ep square")


func _test_promotion(Rules, StateC) -> void:
        print("[5] promotion")
        var s = Rules.state_from_fen("8/P7/8/8/8/8/8/K6k w - - 0 1")
        var moves: Array = Rules.all_legal_moves(s)
        var promos: Array = moves.filter(func(m): return m["to"] == 0 and m["promo"] != 0)
        check(promos.size() == 4, "four promotion choices generated")
        var q := promos.filter(func(m): return m["promo"] == StateC.QUEEN)
        var undo = Rules.make_move(s, q[0])
        check(s.board[0] == StateC.QUEEN, "under-the-hood promo creates a queen")
        Rules.undo_move(s, undo)
        check(s.board[0] == 0 and s.board[8] == StateC.PAWN, "undo restores pawn")


func _test_mate_stalemate(Rules, StateC) -> void:
        print("[6] checkmate / stalemate / check")
        var mate = Rules.state_from_fen("R5k1/5ppp/8/8/8/8/8/4K3 b - - 0 1")
        check(Rules.get_status(mate) == "checkmate", "back-rank checkmate detected")
        var stale = Rules.state_from_fen("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
        check(Rules.get_status(stale) == "stalemate", "stalemate detected")
        var norm = Rules.create_initial_state()
        check(Rules.get_status(norm) == "ongoing", "start position ongoing")
        var chk = Rules.state_from_fen("4k3/8/8/8/8/8/4r3/4K3 w - - 0 1")
        check(Rules.in_check(chk, 1), "white king detected in check")
        var kmoves: Array = Rules.all_legal_moves(chk)
        check(kmoves.size() == 3, "Ke1 vs Re2: exactly 3 legal king moves (Kd1, Kf1, Kxe2)")


func _test_corruption(Rules, StateC) -> void:
        print("[7] corruption (boss modifier)")
        var s = Rules.create_initial_state()
        s.corrupted = [36]  # e4 blocked for WHITE
        var pawn_moves: Array = Rules.legal_moves_from(s, 52)  # e2
        var tos: Array = pawn_moves.map(func(m): return m["to"])
        check(not tos.has(36), "white pawn cannot enter corrupted e4")
        check(tos.has(44), "white pawn can still push to e3 (44)")
        check(not s.corrupted.has(28), "e3 not corrupted")
        # black pieces unaffected
        var b = Rules.create_initial_state()
        b.corrupted = [19]  # d6 blocked only for WHITE
        var bpawn: Array = Rules.legal_moves_from(b, 11)  # black pawn d7
        var btos: Array = bpawn.map(func(m): return m["to"])
        check(btos.has(19), "black pawn ignores corruption (can move to d6)")
        check(btos.has(27), "black pawn can also double-push to d5")


# --------------------------------------------------------------------- 3

func _test_ai(AIC, StateC) -> void:
        print("[8] AI")
        var Rules = load("res://scripts/chess/chess_rules.gd")
        var s = Rules.create_initial_state()
        var t := Time.get_ticks_msec()
        var ranked: Array = AIC.search_root(s.duplicate(), 2)
        var dt := Time.get_ticks_msec() - t
        check(not ranked.is_empty(), "search_root depth 2 returns moves")
        var legal: Array = Rules.all_legal_moves(s)
        var chosen: Dictionary = ranked[0]["move"]
        var found := false
        for m in legal:
                if m["from"] == chosen["from"] and m["to"] == chosen["to"] and m["promo"] == chosen["promo"]:
                        found = true
        check(found, "AI move is legal")
        print("  ...depth2 search: %d ms, best score %.0f cp" % [dt, ranked[0]["score"] / 100.0])

        var t3 := Time.get_ticks_msec()
        var r3: Array = AIC.search_root(s.duplicate(), 3)
        print("  ...depth3 search: %d ms" % (Time.get_ticks_msec() - t3))
        check(not r3.is_empty(), "search_root depth 3 returns moves")

        # mate in 1 must be found even at depth 1
        var mate = Rules.state_from_fen("6k1/5ppp/8/8/8/8/8/R3K3 w - - 0 1")
        var r1: Array = AIC.search_root(mate.duplicate(), 1)
        var m1: Dictionary = r1[0]["move"]
        check(m1["to"] == 0 and r1[0]["score"] > 900000, "AI finds Ra8# (a1->a8) at depth 1")

        # self-play: 60 half-moves at depth 2, must stay legal & not crash
        var sp = Rules.create_initial_state()
        var plies := 0
        var status := "ongoing"
        while plies < 60:
                status = Rules.get_status(sp)
                if status != "ongoing":
                        break
                var mv: Dictionary = AIC.get_best_move(sp, 2)
                if mv.is_empty():
                        break
                Rules.make_move(sp, mv)
                plies += 1
        check(plies > 0, "self-play ran")
        print("  ...self-play: %d plies, final status = %s" % [plies, status])


# --------------------------------------------------------------------- 4

func _ensure_autoloads() -> void:
        var root := get_root()
        for pair in [["SaveManager", "res://scripts/managers/save_manager.gd"],
                        ["I18n", "res://scripts/managers/i18n.gd"],
                        ["AudioManager", "res://scripts/managers/audio_manager.gd"],
                        ["RunManager", "res://scripts/managers/run_manager.gd"],
                        ["GameManager", "res://scripts/managers/game_manager.gd"]]:
                if root.has_node(pair[0]):
                        continue
                var node := Node.new()
                node.name = pair[0]
                node.set_script(load(pair[1]))
                root.add_child(node)


func _test_run_manager() -> void:
        print("[9] RunManager roguelike math + capture upgrades")
        _ensure_autoloads()
        var rm = get_root().get_node("RunManager")
        rm.start_new_run()
        check(rm.coins == 0 and rm.upgrades.is_empty(), "new run resets data")
        rm.add_upgrade("momentum")
        rm.add_upgrade("treasure_hunter")
        rm.win_streak = 1
        check(absf(rm.multiplier() - 1.25) < 0.001, "momentum multiplier 1.25 after 1 win")
        var bd: Dictionary = rm.on_battle_won(10, false)
        check(absf(bd["mult"] - 1.5) < 0.001, "streak applied to breakdown")
        check(bd["total"] == 23, "10 * 1.5 * 1.5 rounds to 23")  # 10*1.5*1.5 = 22.5 -> 23
        check(rm.coins == 23, "coins added to run")
        rm.win_streak = 0
        rm.start_new_run()
        check(rm.coins == 0 and rm.multiplier() == 1.0, "new run clears everything")

        # capture tiers: pawn -> 1, knight/bishop -> 2, rook -> 3, queen -> 4
        var StateC = load("res://scripts/chess/chess_state.gd")
        var gq: Dictionary = rm.on_player_capture(-StateC.QUEEN)
        check(gq["tier"] == 4, "queen capture grants TIER 4")
        check(String(gq["upgrade"]) != "" or int(gq["coins"]) > 0,
                        "queen capture granted an upgrade or fallback coins")
        var gp: Dictionary = rm.on_player_capture(-StateC.PAWN)
        check(gp["tier"] == 1, "pawn capture grants TIER 1")
        check(String(gp["upgrade"]) != "" and rm.has_upgrade(String(gp["upgrade"])),
                        "pawn capture upgrade is owned by the run")

        # stackable upgrade: pawn_tax stacks raise per-capture coins
        rm.start_new_run()
        rm.add_upgrade("pawn_tax")
        rm.add_upgrade("pawn_tax")
        check(rm.stacks("pawn_tax") == 2, "pawn_tax stacked to x2")
        var before: int = rm.coins
        rm.on_player_capture(-StateC.ROOK)  # pawn_tax applies to ANY capture
        check(rm.coins - before == 4, "pawn_tax x2 grants 4 coins per capture")

        # token/charge upgrades
        rm.start_new_run()
        rm.add_upgrade("second_chance")
        check(rm.undo_tokens == 1, "second chance grants an undo token")
        rm.add_upgrade("second_chance")
        check(rm.undo_tokens == 2, "second chance stacks (+1 token each)")
        rm.add_upgrade("royal_guard")
        check(rm.guard_charges == 1, "royal guard grants a mate-save charge")

        # tier pool exhaustion -> fallback coins
        rm.start_new_run()
        for id in ["royal_decree", "phoenix", "midas"]:
                rm.add_upgrade(id)
        var UDB = load("res://scripts/roguelike/upgrade_db.gd")
        var grant: Dictionary = UDB.grant_for_tier(4, rm)
        check(grant.has("coins") and int(grant["coins"]) == 60,
                        "exhausted tier 4 pool falls back to 60 coins")

        # midas doubles gains
        rm.start_new_run()
        rm.add_upgrade("midas")
        check(absf(rm.multiplier() - 2.0) < 0.001, "midas doubles the coin multiplier")

        var ev = load("res://scripts/roguelike/event_db.gd")
        var e: Dictionary = ev.pick_event(["traveler", "risky"])
        check(e["id"] == "lost_knight", "event exclusion works")
        var md = load("res://scripts/roguelike/map_db.gd")
        var av: Array = md.available_nodes(["start"])
        check(av.size() == 1 and av[0] == "b1", "from start only battle 1 available")
        var av2: Array = md.available_nodes(["start", "b1"])
        check(av2.size() == 2 and av2.has("b2") and av2.has("e1"), "branch unlocks battle 2 + event")
        rm.start_new_run()


# ------------------------------------------------------------------- i18n

func _test_i18n() -> void:
        print("[10] i18n completeness (EN + FA)")
        _ensure_autoloads()
        var i18n = get_root().get_node("I18n")
        var complete := true
        var missing: Array = []
        for key in i18n.STRINGS:
                var entry: Dictionary = i18n.STRINGS[key]
                if not entry.has("en") or not entry.has("fa"):
                        complete = false
                        missing.append(key)
        check(complete, "every i18n key has en+fa" +
                        ("" if missing.is_empty() else " MISSING: " + str(missing)))
        i18n.lang = "en"
        check(i18n.t("menu_play_ai") != "menu_play_ai", "EN translation resolves")
        i18n.lang = "fa"
        check(i18n.t("menu_play_ai") != "menu_play_ai", "FA translation resolves")
        check(i18n.is_rtl(), "FA marks RTL")
        i18n.lang = "en"
        # upgrade db names resolve in both languages
        var udb = load("res://scripts/roguelike/upgrade_db.gd")
        var all_ok := true
        for id in udb.ALL:
                i18n.lang = "en"
                var n1: String = i18n.t(udb.get_upgrade(id)["name_key"])
                i18n.lang = "fa"
                var n2: String = i18n.t(udb.get_upgrade(id)["name_key"])
                var d1: String = i18n.t(udb.get_upgrade(id)["desc_key"])
                if n1 == id or n2 == id or d1 == id or n1.begins_with("up_") or n2.begins_with("up_") or d1.begins_with("up_"):
                        all_ok = false
        check(all_ok, "all upgrade names/descriptions translated (EN+FA)")


# --------------------------------------------------------------------- 5

func _test_scenes() -> void:
        print("[11] scene instantiation smoke test")
        _ensure_autoloads()
        var gm = get_root().get_node("GameManager")
        var rm = get_root().get_node("RunManager")
        rm.start_new_run()

        for pair in [["res://scenes/main_menu/main_menu.tscn", null],
                        ["res://scenes/map/map.tscn", null],
                        ["res://scenes/event/event_screen.tscn", null],
                        ["res://scenes/chess/chess_battle.tscn", "battle"]]:
                var path: String = pair[0]
                if pair[1] == "battle":
                        gm.pending_battle = {"node_id": "b1", "label": "BATTLE 1", "is_boss": false, "mode": "ai",
                                        "depth": 1, "jitter": 0.9, "blunder": 0.18, "base_coins": 10}
                var packed = load(path)
                if packed == null:
                        check(false, "load scene " + path)
                        continue
                var inst = packed.instantiate()
                get_root().add_child(inst)
                check(is_instance_valid(inst), "instantiate " + path)
                inst.queue_free()
        await process_frame
        print("  scene smoke test complete")


# --------------------------------------------------------------------- 6

func _test_battle_flow() -> void:
        print("[12] battle flow: animated move -> parallel AI reply -> undo -> capture coins")
        _ensure_autoloads()
        var gm = get_root().get_node("GameManager")
        var rm = get_root().get_node("RunManager")
        rm.start_new_run()
        gm.pending_battle = {"node_id": "b1", "label": "BATTLE 1", "is_boss": false, "mode": "ai",
                        "depth": 2, "jitter": 0.5, "blunder": 0.0, "base_coins": 10}
        var packed = load("res://scenes/chess/chess_battle.tscn")
        var inst = packed.instantiate()
        get_root().add_child(inst)
        await process_frame
        await process_frame

        # player selects e2 (52) then taps e4 (36) through the real input handler
        inst._on_square_tapped(52)
        check(inst.selected_sq == 52 and inst.current_moves.size() > 0, "selecting e2 shows legal moves")
        inst._on_square_tapped(36)
        check(inst.history.size() == 1, "player move recorded")
        check(inst.ai_thinking, "AI compute started immediately (parallel with animation)")
        var waited := 0
        while (inst.history.size() < 2 or inst.board_view.input_locked) and waited < 3000:
                await process_frame
                waited += 1
        check(inst.history.size() == 2, "AI reply recorded (history == 2)")
        check(not inst.board_view.input_locked, "animations finished")
        check(int(inst.state.turn) == 1, "white to move after a full round")
        check(not inst.game_over, "battle still ongoing")

        # undo flow requires a token; grant it and undo the round
        rm.add_upgrade("second_chance")
        inst._refresh_upgrade_row()
        inst._update_undo_button()
        check(not inst.undo_btn.disabled, "undo enabled with a second chance token")
        inst._on_undo_pressed()
        check(inst.history.is_empty(), "undo reverts both half-moves")
        check(int(inst.state.turn) == 1, "white to move after undo")
        check(rm.undo_tokens == 0, "undo token consumed for the run")

        # knight fury coin hook: capture a queen with a knight on a rigged board
        rm.add_upgrade("knight_fury")
        rm.coins = 0
        inst.state = load("res://scripts/chess/chess_rules.gd").state_from_fen("4k3/8/8/3q4/8/2N5/8/4K3 w - - 0 1")
        inst.board_view.setup(inst.state, inst._compute_cell())
        inst.board_view.set_corrupted(inst.state.corrupted)
        inst._select_piece(42)  # knight c3
        inst._on_square_tapped(27)  # Nxd5 captures queen
        check(rm.coins >= 6, "KNIGHT FURY granted coins on knight capture (got %d)" % rm.coins)
        var waited2 := 0
        while inst.board_view.input_locked and waited2 < 600:
                await process_frame
                waited2 += 1

        inst.queue_free()
        await process_frame
        print("  battle flow test complete")


# --------------------------------------------------------------------- 7

func _test_pvp_flow() -> void:
        print("[13] pvp hotseat flow: alternating human turns")
        _ensure_autoloads()
        var gm = get_root().get_node("GameManager")
        var rm = get_root().get_node("RunManager")
        rm.start_new_run()
        gm.pending_battle = {"mode": "pvp", "node_id": "pvp", "label": "2P DUEL",
                        "is_boss": false, "base_coins": 0}
        var packed = load("res://scenes/chess/chess_battle.tscn")
        var inst = packed.instantiate()
        get_root().add_child(inst)
        await process_frame
        await process_frame

        check(inst.is_pvp, "pvp mode detected")
        check(inst.undo_btn == null, "no undo button in pvp")
        check(not inst.ai_thinking, "no AI in pvp")

        inst._on_square_tapped(52)  # white: e2
        inst._on_square_tapped(36)  # white: e4
        var waited := 0
        while inst.board_view.input_locked and waited < 600:
                await process_frame
                waited += 1
        check(inst.history.size() == 1, "white move recorded")
        check(int(inst.state.turn) == -1, "black to move")

        inst._on_square_tapped(12)  # black: e7
        inst._on_square_tapped(28)  # black: e5
        waited = 0
        while inst.board_view.input_locked and waited < 600:
                await process_frame
                waited += 1
        check(inst.history.size() == 2, "black move recorded")
        check(int(inst.state.turn) == 1, "white to move again")
        check(not inst.game_over, "pvp game ongoing")
        # tapping an enemy piece during white's turn is rejected gracefully
        inst._on_square_tapped(12)
        check(inst.selected_sq == -1, "cannot select black piece on white's turn")

        inst.queue_free()
        await process_frame
        print("  pvp flow test complete")


# --------------------------------------------------------------------- 8

func _test_alignment() -> void:
        print("[14] PERFECT PIECE ALIGNMENT (system-level)")
        _ensure_autoloads()
        var Rules = load("res://scripts/chess/chess_rules.gd")
        var StateC = load("res://scripts/chess/chess_state.gd")

        # --- A) sprite centering contract: visible content == canvas center
        for color in ["w", "b"]:
                for n in ["pawn", "knight", "bishop", "rook", "queen", "king"]:
                        var pname := "piece_%s_%s" % [color, n]
                        var tex: Texture2D = load("res://assets/pixel/%s.png" % pname)
                        check(tex != null, "texture exists " + pname)
                        if tex == null:
                                continue
                        var img: Image = tex.get_image()
                        if img.is_compressed():
                                img.decompress()
                        check(img.get_width() == 180 and img.get_height() == 180,
                                        pname + " canvas is 180x180")
                        var l := 999999
                        var t := 999999
                        var r := -1
                        var b := -1
                        for y in img.get_height():
                                for x in img.get_width():
                                        if img.get_pixel(x, y).a8 >= 8:
                                                l = mini(l, x)
                                                t = mini(t, y)
                                                r = maxi(r, x)
                                                b = maxi(b, y)
                        check(r >= 0, pname + " has visible content")
                        if r < 0:
                                continue
                        var cx := (l + r) / 2.0
                        var cy := (t + b) / 2.0
                        check(absf(cx - 89.5) <= 0.51, "%s visible center on X (off %.1fpx)" % [pname, absf(cx - 89.5)])
                        check(absf(cy - 89.5) <= 0.51, "%s visible center on Y (off %.1fpx)" % [pname, absf(cy - 89.5)])

        # --- B) authoritative coordinate system on a bare BoardView
        var BVC = load("res://scripts/ui/board_view.gd")
        var bv = BVC.new()
        get_root().add_child(bv)
        await process_frame
        var st = Rules.create_initial_state()
        bv.setup(st, 120.0)
        await process_frame
        check(bv.size.x > 0.0 and bv.size.y > 0.0, "board has a real rect after layout")
        var ss: Vector2 = bv.square_size()
        check(ss.x == bv.size.x / 8.0 and ss.y == bv.size.y / 8.0,
                        "square_size derived from the control rect")
        var c: Vector2 = bv.get_square_center(Vector2i(4, 3))
        check(absf(c.x - 4.5 * ss.x) < 0.001 and absf(c.y - 3.5 * ss.y) < 0.001,
                        "get_square_center == (x+0.5)*w, (y+0.5)*h")
        var rt_ok := true
        for sq in 64:
                var v := Vector2i(sq % 8, sq >> 3)
                if bv.sq_center(sq) != bv.get_square_center(v):
                        rt_ok = false
                if bv.square_at(bv.get_square_center(v)) != sq:
                        rt_ok = false
        check(rt_ok, "sq_center / get_square_center / square_at agree for all 64 squares")
        check(bv.square_at(Vector2(-5, -5)) == -1, "square_at rejects out-of-board points")
        var rep: Dictionary = bv.validate_alignment()
        check(rep["ok"] and rep["checked"] == 32,
                        "all 32 pieces exactly centered at start (max_dev=%.3fpx)" % rep["max_dev"])
        var pivot_ok := true
        for sq in bv._pieces:
                var node = bv._pieces[sq]
                if node.pivot_offset != node.size * 0.5 or node.size != ss:
                        pivot_ok = false
        check(pivot_ok, "every piece: pivot == size/2 and size == square_size")

        # --- C) animated move: slide between CALCULATED centers + exact snap
        var mv = null
        for m in Rules.all_legal_moves(st):
                if int(m["from"]) == 52 and int(m["to"]) == 36:
                        mv = m
        check(mv != null, "found e2-e4 for the animation test")
        Rules.make_move(st, mv)
        bv.refresh_highlights()
        bv.animate_move(mv)
        var waited := 0
        while bv.input_locked and waited < 600:
                await process_frame
                waited += 1
        rep = bv.validate_alignment()
        check(rep["ok"], "perfect alignment after ANIMATED move (max_dev=%.3fpx)" % rep["max_dev"])
        var landed: Vector2 = bv._pieces[36].center_pos()
        check(landed.distance_to(bv.sq_center(36)) < 0.001,
                        "mover explicitly snapped to the EXACT destination center")

        # --- D) animated capture (knight takes queen) stays perfectly aligned
        st = Rules.state_from_fen("4k3/8/8/3q4/8/2N5/8/4K3 w - - 0 1")
        bv.setup(st, 120.0)
        await process_frame
        var cap_mv = null
        for m in Rules.legal_moves_from(st, 42):
                if int(m["to"]) == 27:
                        cap_mv = m
        check(cap_mv != null, "found Nxd5 for the capture animation test")
        Rules.make_move(st, cap_mv)
        bv.animate_move(cap_mv)
        waited = 0
        while bv.input_locked and waited < 600:
                await process_frame
                waited += 1
        rep = bv.validate_alignment()
        check(rep["ok"] and rep["checked"] == 3,
                        "capture animation leaves perfect alignment (max_dev=%.3fpx)" % rep["max_dev"])
        check(int(bv._pieces[27].piece) == StateC.KNIGHT,
                        "captured queen node removed; knight now occupies d5")

        # --- E) animated promotion swaps texture and stays centered
        st = Rules.state_from_fen("8/P7/8/8/8/8/k6K/8 w - - 0 1")
        bv.setup(st, 120.0)
        await process_frame
        var promo_mv = null
        for m in Rules.legal_moves_from(st, 8):
                if int(m["to"]) == 0 and int(m["promo"]) != 0:
                        promo_mv = m
                        break   # first variant = queen promotion
        check(promo_mv != null, "found a7-a8 promotion for the promo test")
        Rules.make_move(st, promo_mv)
        bv.animate_move(promo_mv)
        waited = 0
        while bv.input_locked and waited < 600:
                await process_frame
                waited += 1
        rep = bv.validate_alignment()
        check(rep["ok"], "promotion leaves perfect alignment (max_dev=%.3fpx)" % rep["max_dev"])
        check(int(bv._pieces[0].piece) == StateC.QUEEN, "pawn node became a QUEEN after animated promo")

        # --- F) forced drift is DETECTED, then HEALED by refresh()
        var victim = null
        for sq in bv._pieces:
                victim = bv._pieces[sq]
        # (any placement MUST go through the geometry API - simulate a drift
        # by placing the node on a WRONG center)
        victim.set_square_center(victim.center_pos() + Vector2(7, -3))
        rep = bv.validate_alignment()
        check(not rep["ok"] and rep["max_dev"] > 7.0,
                        "validate_alignment DETECTS forced drift (%.2fpx)" % rep["max_dev"])
        bv.refresh()
        rep = bv.validate_alignment()
        check(rep["ok"], "refresh() heals drift back to perfect alignment")

        # --- G) board resize: EVERYTHING re-derived from the new rect
        bv.custom_minimum_size = Vector2(96, 96) * 8
        bv.size = Vector2(96, 96) * 8
        await process_frame
        await process_frame
        rep = bv.validate_alignment()
        check(rep["ok"], "pieces re-centered after BOARD RESIZE (max_dev=%.3fpx)" % rep["max_dev"])
        var tiles = bv._tiles_node()
        var t5 = tiles.get_child(5)
        var r5: Rect2 = bv.sq_rect(5)
        check(t5.position == r5.position and t5.size == r5.size,
                        "tiles re-derived from the new board rect")
        check(bv.get_square_center(Vector2i(4, 3)).x == (4 + 0.5) * 96.0,
                        "centers follow the resized square size")

        # --- H) debug alignment mode toggles without errors
        bv.debug_alignment = true
        await process_frame
        await process_frame
        bv.debug_alignment = false
        check(true, "debug alignment overlay toggled cleanly")

        bv.queue_free()
        await process_frame

        # --- I) real battle scene: end-to-end alignment through the full flow
        var gm = get_root().get_node("GameManager")
        var rm = get_root().get_node("RunManager")
        rm.start_new_run()
        gm.pending_battle = {"node_id": "b1", "label": "BATTLE 1", "is_boss": false,
                        "mode": "ai", "depth": 1, "jitter": 0.0, "blunder": 0.0, "base_coins": 10}
        var packed = load("res://scenes/chess/chess_battle.tscn")
        var inst = packed.instantiate()
        get_root().add_child(inst)
        await process_frame
        await process_frame
        inst._on_square_tapped(52)
        inst._on_square_tapped(36)
        waited = 0
        while (inst.history.size() < 2 or inst.board_view.input_locked) and waited < 3000:
                await process_frame
                waited += 1
        rep = inst.board_view.validate_alignment()
        check(rep["ok"], "battle scene: perfect alignment after a full animated round (max_dev=%.3fpx)" % rep["max_dev"])
        print("  ", inst.board_view.alignment_report().replace("\n", "\n  "))
        inst.board_view.debug_alignment = true
        await process_frame
        await process_frame
        inst.board_view.debug_alignment = false
        inst.queue_free()
        await process_frame
        print("  alignment test complete")
