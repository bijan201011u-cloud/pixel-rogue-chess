class_name UIKit
## Static helpers to build the shared pixel-styled mobile UI (large touch
## targets, 9-slice textures from the asset sheet).

const COL_BG := Color("12121c")
const COL_PANEL := Color("1b1b2a")
const COL_TEXT := Color("ecece4")
const COL_GOLD := Color("e8c84a")
const COL_DIM := Color("9a9ab0")
const COL_GOOD := Color("7fd98a")
const COL_BAD := Color("e5646c")

const BTN_MARGIN := 10.0

static var _font_bold: FontFile = load("res://assets/fonts/Vazirmatn-Bold.ttf")
static var _font_regular: FontFile = load("res://assets/fonts/Vazirmatn-Regular.ttf")


static func font_regular() -> FontFile:
        return _font_regular


static func font_bold() -> FontFile:
        return _font_bold


static func style_texture(path: String, tex_margin: float, content_margin: float) -> StyleBoxTexture:
        var sb := StyleBoxTexture.new()
        sb.texture = load(path)
        sb.texture_margin_left = tex_margin
        sb.texture_margin_right = tex_margin
        sb.texture_margin_top = tex_margin
        sb.texture_margin_bottom = tex_margin
        sb.content_margin_left = content_margin
        sb.content_margin_right = content_margin
        sb.content_margin_top = content_margin * 0.7
        sb.content_margin_bottom = content_margin * 0.7
        return sb


static func button(text: String, font_size := 46, style := "primary",
                min_size := Vector2(0, 112)) -> Button:
        var b := Button.new()
        b.text = text
        b.custom_minimum_size = min_size
        b.focus_mode = Control.FOCUS_NONE
        b.add_theme_font_override("font", _font_bold)
        b.add_theme_font_size_override("font_size", font_size)
        b.add_theme_color_override("font_color", COL_TEXT)
        b.add_theme_color_override("font_hover_color", Color.WHITE)
        b.add_theme_color_override("font_pressed_color", COL_GOLD)
        b.add_theme_color_override("font_disabled_color", COL_DIM)
        var path := "res://assets/ui/btn_%s.png" % style
        var normal := style_texture(path, BTN_MARGIN, 20)
        var pressed := style_texture(path, BTN_MARGIN, 20)
        pressed.modulate_color = Color(0.7, 0.7, 0.75)
        b.add_theme_stylebox_override("normal", normal)
        b.add_theme_stylebox_override("hover", normal)
        b.add_theme_stylebox_override("pressed", pressed)
        b.add_theme_stylebox_override("disabled", pressed)
        return b


static func label(text: String, font_size := 36, color := COL_TEXT,
                align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
        var l := Label.new()
        l.text = text
        l.horizontal_alignment = align
        l.add_theme_font_size_override("font_size", font_size)
        l.add_theme_color_override("font_color", color)
        return l


static func title_label(text: String, font_size := 96, color := COL_GOLD) -> Label:
        var l := label(text, font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
        var ls := LabelSettings.new()
        ls.font = _font_bold
        ls.font_size = font_size
        ls.font_color = color
        ls.shadow_color = Color(0, 0, 0, 0.6)
        ls.shadow_offset = Vector2(4, 4)
        l.label_settings = ls
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        return l


## Autowrapped paragraph that never widens a modal panel beyond the screen.
static func para(text: String, font_size := 34, color := COL_TEXT) -> Label:
        var l := label(text, font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.custom_minimum_size = Vector2(820, 0)
        l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        return l


static func panel_style() -> StyleBoxTexture:
        return style_texture("res://assets/ui/panel.png", 8, 22)


static func panel_container() -> PanelContainer:
        var p := PanelContainer.new()
        p.add_theme_stylebox_override("panel", panel_style())
        return p


static func chip(text: String, color := COL_GOLD) -> PanelContainer:
        var p := PanelContainer.new()
        p.add_theme_stylebox_override("panel", panel_style())
        p.add_child(label(text, 26, color))
        return p


static func icon(path: String, size: float) -> TextureRect:
        var t := TextureRect.new()
        t.texture = load(path)
        t.custom_minimum_size = Vector2(size, size)
        t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        t.mouse_filter = Control.MOUSE_FILTER_IGNORE
        return t


static func vspace(h: float) -> Control:
        var c := Control.new()
        c.custom_minimum_size = Vector2(0, h)
        c.mouse_filter = Control.MOUSE_FILTER_IGNORE
        return c


static func hspace(w: float) -> Control:
        var c := Control.new()
        c.custom_minimum_size = Vector2(w, 0)
        c.mouse_filter = Control.MOUSE_FILTER_IGNORE
        return c


static func fullscreen_bg(parent: Control, color := COL_BG) -> void:
        var rect := ColorRect.new()
        rect.color = color
        rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        parent.add_child(rect)


## Dimmed cover image (used on menu / boss intro).
static func bg_image(parent: Control, path: String, alpha := 0.28) -> void:
        var t := TextureRect.new()
        t.texture = load(path)
        t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        t.modulate = Color(1, 1, 1, alpha)
        t.mouse_filter = Control.MOUSE_FILTER_IGNORE
        parent.add_child(t)


## Modal dim overlay + centered panel; returns the VBox to fill content into.
static func modal(parent: Control) -> VBoxContainer:
        var dim := ColorRect.new()
        dim.color = Color(0, 0, 0, 0.72)
        dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        dim.mouse_filter = Control.MOUSE_FILTER_STOP
        parent.add_child(dim)
        var center := CenterContainer.new()
        center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        center.mouse_filter = Control.MOUSE_FILTER_IGNORE
        dim.add_child(center)
        var panel := panel_container()
        panel.custom_minimum_size = Vector2(940, 0)
        center.add_child(panel)
        var margin := MarginContainer.new()
        margin.add_theme_constant_override("margin_left", 44)
        margin.add_theme_constant_override("margin_right", 44)
        margin.add_theme_constant_override("margin_top", 36)
        margin.add_theme_constant_override("margin_bottom", 36)
        panel.add_child(margin)
        var vbox := VBoxContainer.new()
        vbox.add_theme_constant_override("separation", 18)
        margin.add_child(vbox)
        return vbox
