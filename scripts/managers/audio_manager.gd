extends Node
## AUTOLOAD: AudioManager
## Music (looped tracks) + one-shot SFX, honoring SaveManager.music_enabled /
## sound_enabled. Works silently under the Dummy audio driver (headless).

const MUSIC := {
	"menu": "res://assets/audio/menu.mp3",
	"game": "res://assets/audio/game.mp3",
}
const SFX := {
	"move": "res://assets/audio/move.mp3",
	"upgrade": "res://assets/audio/upgrade.mp3",
	"win": "res://assets/audio/win.mp3",
	"lose": "res://assets/audio/lose.mp3",
}
const MUSIC_DB := -10.0
const SFX_DB := -2.0

var _music_player: AudioStreamPlayer = null
var _current_track := ""
var _sfx_players: Array = []
var _streams: Dictionary = {}


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path)
	return _streams[path]


## Starts a looped music track; no-ops when the same track already plays.
func play_music(track: String) -> void:
	if not MUSIC.has(track):
		return
	if _current_track == track and _music_player.playing:
		return
	_current_track = track
	var s := _stream(MUSIC[track])
	if s is AudioStreamMP3:
		s.loop = true
	_music_player.stream = s
	_music_player.volume_db = MUSIC_DB
	if SaveManager.music_enabled:
		_music_player.play()


func stop_music() -> void:
	_current_track = ""
	_music_player.stop()


## Live toggle from the settings screen.
func set_music_enabled(on: bool) -> void:
	if on:
		if _current_track != "" and not _music_player.playing:
			_music_player.play()
	else:
		_music_player.stop()


## Fire-and-forget one-shot SFX (steals a voice when all 4 are busy).
func play_sfx(sfx_name: String) -> void:
	if not SFX.has(sfx_name) or not SaveManager.sound_enabled:
		return
	var player: AudioStreamPlayer = _sfx_players[0]
	for p in _sfx_players:
		if not p.playing:
			player = p
			break
	player.stream = _stream(SFX[sfx_name])
	player.volume_db = SFX_DB
	player.play()
