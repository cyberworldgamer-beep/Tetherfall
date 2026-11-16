extends Node
## Central audio hub. Owns the looping music players and a small SFX voice
## pool, and follows volumes stored in GameConfig.

const MUSIC := {
	"menu": preload("res://assets/audio/music_menu.wav"),
	"game": preload("res://assets/audio/music_game.wav"),
}

const SFX := {
	"tether_fire": preload("res://assets/audio/sfx_tether_fire.wav"),
	"tether_attach": preload("res://assets/audio/sfx_tether_attach.wav"),
	"tether_release": preload("res://assets/audio/sfx_tether_release.wav"),
	"pickup": preload("res://assets/audio/sfx_pickup.wav"),
	"deposit": preload("res://assets/audio/sfx_deposit.wav"),
	"boost": preload("res://assets/audio/sfx_boost.wav"),
	"hit": preload("res://assets/audio/sfx_hit.wav"),
	"flare": preload("res://assets/audio/sfx_flare.wav"),
	"warning": preload("res://assets/audio/sfx_warning.wav"),
	"game_over": preload("res://assets/audio/sfx_game_over.wav"),
	"new_best": preload("res://assets/audio/sfx_new_best.wav"),
	"ui_click": preload("res://assets/audio/ui_click.wav"),
	"ui_hover": preload("res://assets/audio/ui_hover.wav"),
}

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _current_track: String = ""
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prepare_music_streams()
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.name = "SFX%d" % i
		add_child(p)
		_sfx_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_a.name = "MusicA"
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.name = "MusicB"
	add_child(_music_b)


func _prepare_music_streams() -> void:
	for key in MUSIC:
		var stream: AudioStream = MUSIC[key]
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(round(wav.get_length() * wav.mix_rate))
			wav.loop_end = maxi(wav.loop_end, 1)


func settings_changed() -> void:
	if _active_music != null and _active_music.playing:
		_active_music.volume_db = _music_db()


func _music_db() -> float:
	return linear_to_db(clampf(GameConfig.music_volume, 0.0001, 1.0))


func play_music(track: String, fade: float = 1.2) -> void:
	if not MUSIC.has(track):
		push_warning("Unknown music track: " + track)
		return
	if _current_track == track and _active_music != null and _active_music.playing:
		return
	var incoming := _music_b if _active_music == _music_a else _music_a
	incoming.stream = MUSIC[track]
	incoming.volume_db = -60.0
	incoming.play()
	var outgoing := _active_music
	_active_music = incoming
	_current_track = track
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.tween_property(incoming, "volume_db", _music_db(), fade)
	if outgoing != null:
		_music_tween.tween_property(outgoing, "volume_db", -60.0, fade)
		_music_tween.chain().tween_callback(outgoing.stop)


func stop_music(fade: float = 1.0) -> void:
	_current_track = ""
	if _active_music == null:
		return
	var old := _active_music
	_active_music = null
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.tween_property(old, "volume_db", -60.0, fade)
	_music_tween.tween_callback(old.stop)


func play_sfx(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not SFX.has(sound):
		push_warning("Unknown sound: " + sound)
		return
	if _sfx_players.is_empty():
		return
	var player := _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stream = SFX[sound]
	player.volume_db = linear_to_db(clampf(GameConfig.sfx_volume, 0.0001, 1.0)) + volume_db
	player.pitch_scale = clampf(pitch, 0.25, 4.0)
	player.play()


func play_ui(sound: String = "ui_click") -> void:
	play_sfx(sound, -5.0, 1.0 if sound == "ui_click" else randf_range(0.96, 1.04))