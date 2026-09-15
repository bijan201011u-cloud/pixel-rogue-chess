extends Node
## AUTOLOAD: SaveManager
## Persists permanent settings locally (user://settings.cfg).
## Run progress is intentionally NOT saved in the MVP.

const SAVE_PATH := "user://settings.cfg"

var difficulty: String = "normal"
var language: String = "en"
var sound_enabled: bool = true
var music_enabled: bool = true
var vibration_enabled: bool = true
var debug_alignment_enabled: bool = false   # dev tool: draw square-center markers


func _ready() -> void:
        load_settings()


func load_settings() -> void:
        var cf := ConfigFile.new()
        if cf.load(SAVE_PATH) != OK:
                return
        difficulty = cf.get_value("settings", "difficulty", "normal")
        if not Balance.DIFFICULTIES.has(difficulty):
                difficulty = "normal"
        language = String(cf.get_value("settings", "language", "en"))
        if not language in ["en", "fa"]:
                language = "en"
        sound_enabled = cf.get_value("settings", "sound", true)
        music_enabled = cf.get_value("settings", "music", true)
        vibration_enabled = cf.get_value("settings", "vibration", true)
        debug_alignment_enabled = cf.get_value("settings", "debug_alignment", false)


func save_settings() -> void:
        var cf := ConfigFile.new()
        cf.set_value("settings", "difficulty", difficulty)
        cf.set_value("settings", "language", language)
        cf.set_value("settings", "sound", sound_enabled)
        cf.set_value("settings", "music", music_enabled)
        cf.set_value("settings", "vibration", vibration_enabled)
        cf.set_value("settings", "debug_alignment", debug_alignment_enabled)
        cf.save(SAVE_PATH)
