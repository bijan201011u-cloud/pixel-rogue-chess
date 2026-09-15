extends Control
## Main menu (v2):
##   PLAY VS AI   -> difficulty picker (easy/normal/hard) -> roguelike run
##   2 PLAYERS    -> hotseat chess, two people on one phone
##   SETTINGS     -> language (EN/FA), AI difficulty, sound/music/vibration
## All text via I18n; choices persist through SaveManager.

var _settings_panel: Control = null
var _diff_buttons: Dictionary = {}
var _lang_buttons: Dictionary = {}
var _diff_modal: Control = null


func _ready() -> void:
        _build_bg()
        _build_main()
        _build_diff_modal()
        _build_settings()
        AudioManager.play_music("menu")


func _build_bg() -> void:
        UIKit.fullscreen_bg(self)
        UIKit.bg_image(self, "res://assets/ui/bg_menu.png", 0.30)


func _build_main() -> void:
        var vbox := VBoxContainer.new()
        vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        vbox.alignment = BoxContainer.ALIGNMENT_CENTER
        vbox.add_theme_constant_override("separation", 24)
        add_child(vbox)

        var boss_icon := UIKit.icon("res://assets/ui/boss_king.png", 220)
        var icon_center := CenterContainer.new()
        icon_center.add_child(boss_icon)
        vbox.add_child(icon_center)

        vbox.add_child(UIKit.title_label("PIXEL", 130))
        vbox.add_child(UIKit.title_label("ROGUE CHESS", 88))
        vbox.add_child(UIKit.vspace(10))
        vbox.add_child(UIKit.label(I18n.t("menu_tagline"), 34, UIKit.COL_DIM, HORIZONTAL_ALIGNMENT_CENTER))
        vbox.add_child(UIKit.vspace(26))

        var play_ai := UIKit.button(I18n.t("menu_play_ai"), 52, "success", Vector2(680, 128))
        play_ai.pressed.connect(_on_play_ai)
        var c1 := CenterContainer.new()
        c1.add_child(play_ai)
        vbox.add_child(c1)

        var play_pvp := UIKit.button(I18n.t("menu_play_pvp"), 46, "primary", Vector2(680, 112))
        play_pvp.pressed.connect(_on_play_pvp)
        var c2 := CenterContainer.new()
        c2.add_child(play_pvp)
        vbox.add_child(c2)

        var settings := UIKit.button(I18n.t("menu_settings"), 42, "secondary", Vector2(680, 100))
        settings.pressed.connect(_on_settings)
        var c3 := CenterContainer.new()
        c3.add_child(settings)
        vbox.add_child(c3)

        var hint := UIKit.label(I18n.t("menu_version"), 26, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_CENTER)
        hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
        hint.position.y = -70
        add_child(hint)


# ------------------------------------------------------------ mode pickers

func _on_play_ai() -> void:
        _diff_modal.visible = true


func _on_play_pvp() -> void:
        GameManager.start_pvp()


func _build_diff_modal() -> void:
        _diff_modal = Control.new()
        _diff_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        _diff_modal.visible = false
        add_child(_diff_modal)

        var vbox := UIKit.modal(_diff_modal)
        vbox.add_child(UIKit.title_label(I18n.t("menu_choose_diff"), 54))
        vbox.add_child(UIKit.vspace(8))
        var group := ButtonGroup.new()
        var row := HBoxContainer.new()
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", 16)
        vbox.add_child(row)
        for diff in ["easy", "normal", "hard"]:
                var b := UIKit.button(I18n.t("diff_" + diff), 34, "secondary", Vector2(280, 104))
                b.toggle_mode = true
                b.button_group = group
                b.pressed.connect(_on_difficulty_chosen.bind(diff))
                row.add_child(b)
                _diff_buttons[diff] = b
        vbox.add_child(UIKit.vspace(10))
        var cancel := UIKit.button(I18n.t("btn_back"), 36, "secondary", Vector2(360, 96))
        cancel.pressed.connect(func(): _diff_modal.visible = false)
        var c := CenterContainer.new()
        c.add_child(cancel)
        vbox.add_child(c)
        _refresh_difficulty_buttons()


func _on_difficulty_chosen(diff: String) -> void:
        SaveManager.difficulty = diff
        SaveManager.save_settings()
        _refresh_difficulty_buttons()
        _diff_modal.visible = false
        GameManager.start_ai_run()


func _refresh_difficulty_buttons() -> void:
        for diff in ["easy", "normal", "hard"]:
                var b: Button = _diff_buttons.get(diff)
                if b == null:
                        continue
                b.set_pressed_no_signal(diff == SaveManager.difficulty)
                b.text = I18n.t("diff_" + diff)
                var style := "success" if diff == SaveManager.difficulty else "secondary"
                var path := "res://assets/ui/btn_%s.png" % style
                b.add_theme_stylebox_override("normal", UIKit.style_texture(path, UIKit.BTN_MARGIN, 20))
                b.add_theme_stylebox_override("hover", UIKit.style_texture(path, UIKit.BTN_MARGIN, 20))


# ---------------------------------------------------------------- settings

func _build_settings() -> void:
        _settings_panel = Control.new()
        _settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        _settings_panel.visible = false
        add_child(_settings_panel)

        var vbox := UIKit.modal(_settings_panel)
        vbox.add_child(UIKit.title_label(I18n.t("settings_title"), 64))

        # language
        vbox.add_child(UIKit.label(I18n.t("settings_language"), 38, UIKit.COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
        var lang_row := HBoxContainer.new()
        lang_row.alignment = BoxContainer.ALIGNMENT_CENTER
        lang_row.add_theme_constant_override("separation", 16)
        vbox.add_child(lang_row)
        var lang_group := ButtonGroup.new()
        for opt in [["en", "ENGLISH"], ["fa", "فارسی"]]:
                var b := UIKit.button(opt[1], 34, "secondary", Vector2(400, 96))
                b.toggle_mode = true
                b.button_group = lang_group
                b.pressed.connect(_on_language.bind(opt[0]))
                lang_row.add_child(b)
                _lang_buttons[opt[0]] = b
        vbox.add_child(UIKit.vspace(12))

        # AI difficulty
        vbox.add_child(UIKit.label(I18n.t("settings_difficulty"), 38, UIKit.COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
        var row := HBoxContainer.new()
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", 16)
        vbox.add_child(row)
        var group := ButtonGroup.new()
        for diff in ["easy", "normal", "hard"]:
                var b := UIKit.button(I18n.t("diff_" + diff), 32, "secondary", Vector2(280, 96))
                b.toggle_mode = true
                b.button_group = group
                b.pressed.connect(_on_difficulty.bind(diff))
                row.add_child(b)
                _diff_buttons[diff + "_settings"] = b
        vbox.add_child(UIKit.vspace(12))

        for cfg in [["sound", "settings_sound"], ["music", "settings_music"],
                        ["vibration", "settings_vibration"],
                        ["debug_alignment", "settings_debug_align"]]:
                var cb := CheckButton.new()
                cb.text = I18n.t(cfg[1])
                cb.custom_minimum_size = Vector2(860, 96)
                cb.add_theme_font_size_override("font_size", 40)
                cb.button_pressed = SaveManager.get(cfg[0] + "_enabled")
                cb.focus_mode = Control.FOCUS_NONE
                cb.toggled.connect(_on_toggle.bind(cfg[0]))
                vbox.add_child(cb)

        vbox.add_child(UIKit.label(I18n.t("settings_note"), 26, UIKit.COL_DIM, HORIZONTAL_ALIGNMENT_CENTER))
        vbox.add_child(UIKit.vspace(12))
        var back := UIKit.button(I18n.t("btn_back"), 44, "primary", Vector2(400, 104))
        back.pressed.connect(_on_back)
        var c := CenterContainer.new()
        c.add_child(back)
        vbox.add_child(c)
        _refresh_settings_toggles()


func _refresh_settings_toggles() -> void:
        for diff in ["easy", "normal", "hard"]:
                var b: Button = _diff_buttons.get(diff + "_settings")
                if b == null:
                        continue
                b.set_pressed_no_signal(diff == SaveManager.difficulty)
                b.text = I18n.t("diff_" + diff)
                var style := "success" if diff == SaveManager.difficulty else "secondary"
                var path := "res://assets/ui/btn_%s.png" % style
                b.add_theme_stylebox_override("normal", UIKit.style_texture(path, UIKit.BTN_MARGIN, 20))
                b.add_theme_stylebox_override("hover", UIKit.style_texture(path, UIKit.BTN_MARGIN, 20))
        for code in _lang_buttons:
                var b: Button = _lang_buttons[code]
                b.set_pressed_no_signal(code == SaveManager.language)
                var style := "success" if code == SaveManager.language else "secondary"
                var path := "res://assets/ui/btn_%s.png" % style
                b.add_theme_stylebox_override("normal", UIKit.style_texture(path, UIKit.BTN_MARGIN, 20))
                b.add_theme_stylebox_override("hover", UIKit.style_texture(path, UIKit.BTN_MARGIN, 20))


func _on_settings() -> void:
        _settings_panel.visible = true


func _on_back() -> void:
        _settings_panel.visible = false


func _on_difficulty(diff: String) -> void:
        SaveManager.difficulty = diff
        SaveManager.save_settings()
        _refresh_settings_toggles()
        _refresh_difficulty_buttons()


func _on_language(code: String) -> void:
        SaveManager.language = code
        SaveManager.save_settings()
        I18n.set_language(code)
        _retranslate()
        _refresh_settings_toggles()
        _refresh_difficulty_buttons()


func _on_toggle(pressed: bool, key: String) -> void:
        SaveManager.set(key + "_enabled", pressed)
        SaveManager.save_settings()
        if key == "music":
                AudioManager.set_music_enabled(pressed)


## Live re-translation of every text on this screen.
func _retranslate() -> void:
        var settings_open := _settings_panel != null and _settings_panel.visible
        for c in get_children():
                c.queue_free()
        _diff_buttons.clear()
        _lang_buttons.clear()
        _build_bg()
        _build_main()
        _build_diff_modal()
        _build_settings()
        _settings_panel.visible = settings_open
