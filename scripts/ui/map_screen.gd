extends Control
## Run map: predefined node graph (START -> battles/event -> BOSS).
## Completed nodes are dimmed with a check, available nodes glow gold,
## locked nodes are dark and disabled. Tap an available node to begin.

const NODE_TEX := {
        "start": "res://assets/pixel/node_battle.png",
        "battle": "res://assets/pixel/node_battle.png",
        "event": "res://assets/pixel/node_event.png",
        "boss": "res://assets/pixel/node_boss.png",
}

var _lines: Control
var _node_buttons: Dictionary = {}
var _info_panel: Control = null
var _info_node_id := ""


func _ready() -> void:
        UIKit.fullscreen_bg(self)
        _build_top_bar()
        _build_nodes()
        _refresh_states()
        resized.connect(_relayout)
        AudioManager.play_music("game")


func _relayout() -> void:
        for id in _node_buttons:
                var node: Dictionary = MapDB.NODES[id]
                var btn: TextureButton = _node_buttons[id]
                btn.position = _node_pos(node) - Vector2(85, 85)
                for c in btn.get_children():
                        if c is TextureRect and c != btn.get_child(0):
                                c.position = Vector2(-8, -8)
        _lines.queue_redraw()


func _build_top_bar() -> void:
        var bar := PanelContainer.new()
        bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
        bar.add_theme_stylebox_override("panel", UIKit.panel_style())
        var h := HBoxContainer.new()
        h.add_theme_constant_override("separation", 14)
        bar.add_child(h)

        var icon := UIKit.icon("res://assets/ui/icon_coins.png", 64)
        h.add_child(icon)
        var coin_label := UIKit.label(str(RunManager.coins), 40, UIKit.COL_GOLD)
        coin_label.name = "Coins"
        h.add_child(coin_label)
        h.add_child(UIKit.hspace(18))

        var mult_chip := UIKit.chip("x%.2f" % RunManager.multiplier(),
                        UIKit.COL_GOLD if RunManager.multiplier() > 1.0 else UIKit.COL_DIM)
        mult_chip.name = "Mult"
        h.add_child(mult_chip)
        h.add_child(UIKit.hspace(18))

        var up_row := HBoxContainer.new()
        up_row.add_theme_constant_override("separation", 6)
        up_row.name = "Upgrades"
        for id in RunManager.upgrades:
                var u: Dictionary = UpgradeDB.get_upgrade(id)
                if not u.is_empty():
                        up_row.add_child(UIKit.icon(String(u["icon"]), 52))
        if RunManager.upgrades.is_empty():
                up_row.add_child(UIKit.label(I18n.t("map_no_upgrades"), 26, UIKit.COL_DIM))
        h.add_child(up_row)

        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        h.add_child(spacer)

        var menu_btn := UIKit.button(I18n.t("map_menu"), 30, "secondary", Vector2(150, 78))
        menu_btn.pressed.connect(func(): GameManager.goto_main_menu())
        h.add_child(menu_btn)
        add_child(bar)


func _hud() -> Dictionary:
        var out := {}
        var bar := get_child(0) if get_child_count() > 0 else null
        if bar == null:
                return out
        for n in bar.find_children("*", "", true, false):
                out[n.name] = n
        return out


func _build_nodes() -> void:
        _lines = Control.new()
        _lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        _lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _lines.draw.connect(_draw_lines)
        add_child(_lines)

        for id in MapDB.NODES:
                var node: Dictionary = MapDB.NODES[id]
                var btn := TextureButton.new()
                btn.texture_normal = load(NODE_TEX[String(node["type"])])
                btn.ignore_texture_size = true
                btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
                btn.custom_minimum_size = Vector2(170, 170)
                btn.size = Vector2(170, 170)
                btn.position = _node_pos(node) - Vector2(85, 85)
                btn.focus_mode = Control.FOCUS_NONE
                btn.pressed.connect(_on_node_tapped.bind(id))
                add_child(btn)
                _node_buttons[id] = btn

                var lbl := UIKit.label(I18n.node_label(node), 30, UIKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
                lbl.position = _node_pos(node) + Vector2(-170, 78)
                lbl.custom_minimum_size = Vector2(340, 40)
                add_child(lbl)


func _node_pos(node: Dictionary) -> Vector2:
        var vp := size
        if vp.x < 100:
                vp = Vector2(1080, 1920)
        var top := 330.0
        var row_h := (vp.y - top - 140.0) / float(MapDB.ROWS - 1)
        var x := vp.x * 0.5 + (float(node["col"]) - 1.0) * minf(340.0, vp.x * 0.32)
        var y := top + float(node["row"]) * row_h
        return Vector2(x, y)


func _draw_lines() -> void:
        if _lines == null:
                return
        for id in MapDB.NODES:
                var node: Dictionary = MapDB.NODES[id]
                var done: bool = RunManager.completed_nodes.has(id)
                for nxt in node["next"]:
                        var a := _node_pos(node)
                        var b := _node_pos(MapDB.NODES[nxt])
                        var col := Color(0.55, 0.5, 0.3, 0.9) if done else Color(0.28, 0.28, 0.38, 0.8)
                        _lines.draw_line(a + Vector2(0, 60), b - Vector2(0, 60), col, 8.0)


func _build_hud() -> void:
        pass


func _refresh_states() -> void:
        var available: Array = MapDB.available_nodes(RunManager.completed_nodes)
        for id in _node_buttons:
                var btn: TextureButton = _node_buttons[id]
                var done: bool = RunManager.completed_nodes.has(id)
                var can: bool = available.has(id)
                btn.disabled = not can
                btn.modulate = Color(0.45, 0.45, 0.55, 1.0) if done else (Color.WHITE if can else Color(0.3, 0.3, 0.38, 0.9))
                # gold glow frame for available nodes; check mark for completed
                for c in btn.get_children():
                        c.queue_free()
                if done:
                        var chk := UIKit.icon("res://assets/ui/icon_check.png", 72)
                        chk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
                        chk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                        btn.add_child(chk)
                elif can:
                        var ring := UIKit.icon("res://assets/pixel/hl_select.png", 186)
                        ring.position = Vector2(-8, -8)
                        btn.add_child(ring)
        _lines.queue_redraw()


func _on_node_tapped(id: String) -> void:
        if RunManager.completed_nodes.has(id):
                return
        if not MapDB.available_nodes(RunManager.completed_nodes).has(id):
                return
        _show_info(id)


func _show_info(id: String) -> void:
        _info_node_id = id
        if _info_panel != null:
                _info_panel.queue_free()
        _info_panel = Control.new()
        _info_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        add_child(_info_panel)
        var node: Dictionary = MapDB.NODES[id]
        var vbox := UIKit.modal(_info_panel)
        vbox.add_child(UIKit.title_label(I18n.node_label(node), 60))
        var row := HBoxContainer.new()
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_child(UIKit.icon(NODE_TEX[String(node["type"])], 130))
        vbox.add_child(row)
        var t := String(node["type"])
        var desc := I18n.node_desc(node)
        if t == "battle":
                var ai: Dictionary = Balance.ai_config(SaveManager.difficulty, int(node.get("tier", 0)))
                desc += "\n" + I18n.fmt("map_ai_power", [int(ai["depth"]), I18n.t("diff_" + String(SaveManager.difficulty))])
        vbox.add_child(UIKit.para(desc, 34))
        vbox.add_child(UIKit.vspace(10))
        var begin := UIKit.button(I18n.t("btn_boss") if t == "boss" else I18n.t("btn_begin"), 44, "danger" if t == "boss" else "success", Vector2(700, 112))
        begin.pressed.connect(_on_begin)
        var c := CenterContainer.new()
        c.add_child(begin)
        vbox.add_child(c)
        var close := UIKit.button(I18n.t("btn_close"), 34, "secondary", Vector2(320, 92))
        close.pressed.connect(_on_close_info)
        var c2 := CenterContainer.new()
        c2.add_child(close)
        vbox.add_child(c2)


func _on_begin() -> void:
        var id := _info_node_id
        _on_close_info()
        GameManager.enter_node(id)


func _on_close_info() -> void:
        if _info_panel != null:
                _info_panel.queue_free()
                _info_panel = null


func _process(_delta: float) -> void:
        # keep coin display in sync after events/upgrades
        var bar := get_child(0)
        var coins_lbl: Label = bar.find_child("Coins", true, false)
        if coins_lbl != null:
                coins_lbl.text = str(RunManager.coins)
