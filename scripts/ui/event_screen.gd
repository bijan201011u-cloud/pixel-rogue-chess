extends Control
## Random event screen: story text + two choices with consequences.

var _event: Dictionary = {}
var _resolved := false
var overlay: Control = null


func _ready() -> void:
        UIKit.fullscreen_bg(self)
        AudioManager.play_music("game")
        _event = GameManager.pending_event
        if _event.is_empty():
                _event = EventDB.pick_event(RunManager.events_seen)
        if not RunManager.events_seen.has(String(_event["id"])):
                RunManager.events_seen.append(String(_event["id"]))
        _build()


func _build() -> void:
        var vbox := UIKit.modal(self)
        vbox.add_child(UIKit.title_label(I18n.t("ev_title"), 54, UIKit.COL_DIM))

        var icon_row := HBoxContainer.new()
        icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
        icon_row.add_child(UIKit.icon(String(_event.get("icon", "res://assets/ui/ev_question.png")), 170))
        vbox.add_child(icon_row)

        vbox.add_child(UIKit.title_label(I18n.t(String(_event["title_key"])), 52))
        vbox.add_child(UIKit.para(I18n.t(String(_event["text_key"])), 34))
        vbox.add_child(UIKit.vspace(8))

        var row := HBoxContainer.new()
        row.name = "Choices"
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", 24)
        vbox.add_child(row)

        var idx := 0
        for choice in _event["choices"]:
                var b := UIKit.button(I18n.t(String(choice["label_key"])), 40,
                                "success" if idx == 0 else "secondary", Vector2(380, 108))
                b.pressed.connect(_on_choice.bind(choice))
                row.add_child(b)
                idx += 1


func _on_choice(choice: Dictionary) -> void:
        if _resolved:
                return
        _resolved = true
        var result_text := I18n.t(String(choice["result_key"]))
        match String(choice["effect"]):
                "coins_traveler":
                        var c := RunManager.gain_multiplied(Balance.EVENT_TRAVELER_COINS)
                        result_text += "\n\n" + I18n.fmt("cap_coins", [c])
                "coins_risk":
                        var c2 := RunManager.gain_multiplied(Balance.EVENT_RISK_COINS)
                        result_text += "\n\n" + I18n.fmt("cap_coins", [c2])
                "knight_inspire":
                        RunManager.knight_inspire_battles += 1
                        result_text += "\n\n" + I18n.t("ev_knight_r_eff")
                _:
                        pass

        # rebuild panel with result + continue
        if overlay != null:
                overlay.queue_free()
        overlay = Control.new()
        overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        add_child(overlay)
        var vbox := UIKit.modal(overlay)
        var icon_row := HBoxContainer.new()
        icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
        icon_row.add_child(UIKit.icon("res://assets/ui/icon_check.png" if String(choice["effect"]) != "none" else "res://assets/ui/icon_x.png", 120))
        vbox.add_child(icon_row)
        vbox.add_child(UIKit.title_label(I18n.t(String(_event["title_key"])), 48))
        vbox.add_child(UIKit.para(result_text, 34))
        vbox.add_child(UIKit.vspace(8))
        var cont := UIKit.button(I18n.t("btn_continue"), 44, "primary", Vector2(520, 112))
        cont.pressed.connect(func(): GameManager.goto_map())
        var c := CenterContainer.new()
        c.add_child(cont)
        vbox.add_child(c)
