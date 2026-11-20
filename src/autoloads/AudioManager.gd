class_name AudioManagerClass
extends Node
## Central audio manager: handles dynamic BGM transitions and SFX triggering.

var _bgm_player: AudioStreamPlayer = null
var _sfx_players: Array[AudioStreamPlayer] = []
var _current_bgm_track: String = ""

# Track library
var _music_tracks: Dictionary = {
	"title": "res://assets/audio/music/Adventure's Spirit - Title Theme.wav",
	"blightwood": "res://assets/audio/music/A Great Journey - Overworld.wav",
	"catacomb": "res://assets/audio/music/A Hollow Darkness - Cave.wav",
	"cinderforge": "res://assets/audio/music/Gearing Up - Battle .wav",
	"boss": "res://assets/audio/music/The Beast's Lair - Boss Fight.wav",
	"shop": "res://assets/audio/music/The Merchant - Shop.wav",
	"sanctuary": "res://assets/audio/music/Red Leaf Town - rest area.wav",
	"game_over": "res://assets/audio/music/Lose vol. 1.wav",
	"victory": "res://assets/audio/music/Win vol. 1.wav"
}

var _sfx_library: Dictionary = {
	"slash": "res://assets/audio/sfx/10_Battle_SFX/22_Slash_04.wav",
	"enemy_death": "res://assets/audio/sfx/10_Battle_SFX/69_Enemy_death_01.wav",
	"hit": "res://assets/audio/sfx/12_Player_Movement_SFX/61_Hit_03.wav",
	"block": "res://assets/audio/sfx/10_Battle_SFX/39_Block_03.wav",
	"confirm": "res://assets/audio/sfx/10_UI_Menu_SFX/013_Confirm_03.wav",
	"buy": "res://assets/audio/sfx/10_UI_Menu_SFX/079_Buy_sell_01.wav",
	"heal": "res://assets/audio/sfx/8_Buffs_Heals_SFX/02_Heal_02.wav",
	"pause": "res://assets/audio/sfx/10_UI_Menu_SFX/092_Pause_04.wav",
	"unpause": "res://assets/audio/sfx/10_UI_Menu_SFX/098_Unpause_04.wav"
}

var _loaded_streams: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Ensure audio buses exist
	_ensure_buses()

	# Setup BGM player
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = &"Music"
	add_child(_bgm_player)

	# Setup pool of SFX players
	for i in range(8):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_players.append(p)

	_connect_event_bus()


func _ensure_buses() -> void:
	if AudioServer.get_bus_index(&"Music") == -1:
		AudioServer.add_bus()
		var idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, &"Music")
		AudioServer.set_bus_send(idx, &"Master")
	if AudioServer.get_bus_index(&"SFX") == -1:
		AudioServer.add_bus()
		var idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, &"SFX")
		AudioServer.set_bus_send(idx, &"Master")


func set_bus_volume(bus_name: String, linear_val: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var db_val: float = linear_to_db(clampf(linear_val, 0.0001, 1.0))
		AudioServer.set_bus_volume_db(idx, db_val)


func get_bus_volume(bus_name: String) -> float:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return db_to_linear(AudioServer.get_bus_volume_db(idx))
	return 1.0


func set_bus_mute(bus_name: String, muted: bool) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_mute(idx, muted)


func is_bus_muted(bus_name: String) -> bool:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return AudioServer.is_bus_mute(idx)
	return false


func _connect_event_bus() -> void:
	EventBus.player_hit.connect(func(_dmg): play_sfx("hit"))
	EventBus.player_died.connect(func(): play_bgm("game_over", false))
	EventBus.enemy_killed.connect(func(_pos, _gold): play_sfx("enemy_death"))
	EventBus.item_bought.connect(func(_id): play_sfx("buy"))
	EventBus.shop_opened.connect(func(_items): play_bgm("shop", true))
	EventBus.draft_opened.connect(func(_items): play_bgm("boss", true))
	EventBus.wave_started.connect(_on_wave_started)


func play_bgm(track_name: String, _loop: bool = true) -> void:
	if _current_bgm_track == track_name and _bgm_player.playing:
		return

	if not _music_tracks.has(track_name):
		return

	var path: String = _music_tracks[track_name]
	var stream: AudioStream = _get_or_load_stream(path)
	if stream == null:
		return

	_current_bgm_track = track_name
	_bgm_player.stream = stream
	_bgm_player.play()


func stop_bgm() -> void:
	_current_bgm_track = ""
	_bgm_player.stop()


func play_sfx(sfx_name: String) -> void:
	if not _sfx_library.has(sfx_name):
		return

	var path: String = _sfx_library[sfx_name]
	var stream: AudioStream = _get_or_load_stream(path)
	if stream == null:
		return

	for p: AudioStreamPlayer in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.play()
			return

	# Fallback to first player
	_sfx_players[0].stream = stream
	_sfx_players[0].play()


func _on_wave_started(_floor_idx: int) -> void:
	var cfg: FloorConfig = GameManager.get_current_floor_config()
	if cfg == null:
		return

	match cfg.floor_type:
		FloorConfig.FloorType.MINIBOSS, FloorConfig.FloorType.FINAL_BOSS:
			play_bgm("boss", true)
		FloorConfig.FloorType.NPC_SANCTUARY:
			play_bgm("sanctuary", true)
		_:
			var tower_id: String = GameManager.current_tower.tower_id if GameManager.current_tower else "blightwood"
			play_bgm(tower_id, true)


func _get_or_load_stream(path: String) -> AudioStream:
	if _loaded_streams.has(path):
		return _loaded_streams[path] as AudioStream
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path) as AudioStream
		_loaded_streams[path] = stream
		return stream
	return null
