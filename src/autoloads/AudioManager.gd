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
	"slash": [
		"res://assets/audio/sfx/10_Battle_SFX/22_Slash_04.wav",
		"res://assets/audio/sfx/12_Player_Movement_SFX/56_Attack_03.wav"
	],
	"enemy_death": "res://assets/audio/sfx/10_Battle_SFX/69_Enemy_death_01.wav",
	"hit": [
		"res://assets/audio/sfx/12_Player_Movement_SFX/61_Hit_03.wav",
		"res://assets/audio/sfx/10_Battle_SFX/15_Impact_flesh_02.wav",
		"res://assets/audio/sfx/10_Battle_SFX/77_flesh_02.wav"
	],
	"block": "res://assets/audio/sfx/10_Battle_SFX/39_Block_03.wav",
	"confirm": "res://assets/audio/sfx/10_UI_Menu_SFX/013_Confirm_03.wav",
	"buy": "res://assets/audio/sfx/10_UI_Menu_SFX/079_Buy_sell_01.wav",
	"gold": "res://assets/audio/sfx/10_UI_Menu_SFX/051_use_item_01.wav",
	"heal": "res://assets/audio/sfx/8_Buffs_Heals_SFX/02_Heal_02.wav",
	"pause": "res://assets/audio/sfx/10_UI_Menu_SFX/092_Pause_04.wav",
	"unpause": "res://assets/audio/sfx/10_UI_Menu_SFX/098_Unpause_04.wav",
	"spell_fire": "res://assets/audio/sfx/8_Atk_Magic_SFX/04_Fire_explosion_04_medium.wav",
	"spell_ice": "res://assets/audio/sfx/8_Atk_Magic_SFX/13_Ice_explosion_01.wav",
	"spell_wind": "res://assets/audio/sfx/8_Atk_Magic_SFX/25_Wind_01.wav",
	"spell_earth": "res://assets/audio/sfx/8_Atk_Magic_SFX/30_Earth_02.wav",
	"explosion": "res://assets/audio/sfx/8_Atk_Magic_SFX/04_Fire_explosion_04_medium.wav",
	"thunder": "res://assets/audio/sfx/8_Atk_Magic_SFX/18_Thunder_02.wav",
	"water": "res://assets/audio/sfx/8_Atk_Magic_SFX/22_Water_02.wav",
	"poison": "res://assets/audio/sfx/8_Atk_Magic_SFX/46_Poison_01.wav",
	"equip": "res://assets/audio/sfx/10_UI_Menu_SFX/070_Equip_10.wav",
	"unequip": "res://assets/audio/sfx/10_UI_Menu_SFX/071_Unequip_01.wav"
}

var _sfx_pitch_ranges: Dictionary = {
	"slash": Vector2(0.85, 1.20),
	"hit": Vector2(0.88, 1.15),
	"enemy_death": Vector2(0.82, 1.16),
	"block": Vector2(0.90, 1.15),
	"gold": Vector2(0.92, 1.28),
	"heal": Vector2(0.95, 1.12),
	"spell_fire": Vector2(0.82, 1.18),
	"spell_ice": Vector2(0.88, 1.22),
	"spell_wind": Vector2(0.85, 1.18),
	"spell_earth": Vector2(0.78, 1.10),
	"explosion": Vector2(0.80, 1.15),
	"thunder": Vector2(0.85, 1.15),
	"water": Vector2(0.88, 1.15),
	"poison": Vector2(0.90, 1.12),
	"buy": Vector2(0.95, 1.08),
	"equip": Vector2(0.96, 1.06),
	"unequip": Vector2(0.94, 1.04),
	"confirm": Vector2(0.98, 1.02),
	"pause": Vector2(1.0, 1.0),
	"unpause": Vector2(1.0, 1.0)
}

var _loaded_streams: Dictionary = {}
var _last_played_time: Dictionary = {}
var _last_played_pitch: Dictionary = {}
var _last_sample_index: Dictionary = {}
var is_game_over: bool = false
var _sfx_cooldowns: Dictionary = {
	"slash": 0.06,
	"hit": 0.05,
	"enemy_death": 0.06,
	"gold": 0.04,
	"buy": 0.06,
	"spell_fire": 0.08,
	"spell_ice": 0.08,
	"spell_wind": 0.08,
	"spell_earth": 0.08,
	"explosion": 0.08,
	"thunder": 0.08,
	"water": 0.08,
	"poison": 0.08,
	"confirm": 0.05
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Ensure audio buses exist
	_ensure_buses()

	# Setup BGM player
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = &"Music"
	add_child(_bgm_player)

	# Setup pool of SFX players (16 channels for clean overlap)
	for i in range(16):
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
	EventBus.player_died.connect(_on_player_died)
	EventBus.enemy_killed.connect(func(_pos, _gold): play_sfx("enemy_death"))
	EventBus.item_bought.connect(func(_id): play_sfx("buy"))
	EventBus.shop_opened.connect(func(_items): play_bgm("shop", true))
	EventBus.draft_opened.connect(func(_items): play_bgm("boss", true))
	EventBus.wave_started.connect(_on_wave_started)


func _on_player_died() -> void:
	is_game_over = true
	# Silence all combat sound effects immediately
	for p: AudioStreamPlayer in _sfx_players:
		p.stop()
	play_bgm("game_over", false)


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


func _get_stream_for_sfx(sfx_name: String) -> AudioStream:
	var entry: Variant = _sfx_library.get(sfx_name, null)
	if entry == null:
		return null
	var path: String = ""
	if entry is Array:
		var arr: Array = entry as Array
		if arr.is_empty():
			return null
		var idx: int = randi() % arr.size()
		if arr.size() > 1 and _last_sample_index.get(sfx_name, -1) == idx:
			idx = (idx + 1 + (randi() % (arr.size() - 1))) % arr.size()
		_last_sample_index[sfx_name] = idx
		path = arr[idx]
	elif entry is String:
		path = entry as String
	else:
		return null
	return _get_or_load_stream(path)


func _calculate_pitch(sfx_name: String, min_p: float = -1.0, max_p: float = -1.0) -> float:
	if min_p <= 0.0 or max_p <= 0.0:
		if _sfx_pitch_ranges.has(sfx_name):
			var r: Vector2 = _sfx_pitch_ranges[sfx_name]
			min_p = r.x
			max_p = r.y
		else:
			min_p = 0.88
			max_p = 1.15

	if is_equal_approx(min_p, max_p):
		return min_p

	var chosen_pitch: float = randf_range(min_p, max_p)
	# Avoid identical/near-identical pitch if played consecutively for vibrant variety
	if _last_played_pitch.has(sfx_name):
		var prev_pitch: float = _last_played_pitch[sfx_name]
		if absf(chosen_pitch - prev_pitch) < 0.05 and (max_p - min_p) >= 0.10:
			if chosen_pitch >= (min_p + max_p) * 0.5:
				chosen_pitch = clampf(chosen_pitch + 0.06, min_p, max_p)
			else:
				chosen_pitch = clampf(chosen_pitch - 0.06, min_p, max_p)
	_last_played_pitch[sfx_name] = chosen_pitch
	return chosen_pitch


func play_sfx(sfx_name: String, custom_pitch: float = 0.0, volume_offset_db: float = 0.0) -> void:
	if not _sfx_library.has(sfx_name):
		return

	# Silence combat sounds during game over
	if is_game_over and sfx_name != "confirm":
		return

	# Debounce / rate limit duplicate sounds to avoid harsh stuttering
	var now: float = Time.get_ticks_msec() / 1000.0
	var min_gap: float = _sfx_cooldowns.get(sfx_name, 0.04)
	if _last_played_time.has(sfx_name):
		if (now - _last_played_time[sfx_name]) < min_gap:
			return
	_last_played_time[sfx_name] = now

	var stream: AudioStream = _get_stream_for_sfx(sfx_name)
	if stream == null:
		return

	var pitch: float = custom_pitch if custom_pitch > 0.0 else _calculate_pitch(sfx_name)
	var vol_jitter: float = 0.0
	if not (sfx_name == "confirm" or sfx_name == "pause" or sfx_name == "unpause"):
		vol_jitter = randf_range(-1.2, 0.5)

	# Find free player channel
	for p: AudioStreamPlayer in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch
			p.volume_db = volume_offset_db + vol_jitter
			p.play()
			return

	# If all 16 are busy, find player with furthest playback to replace smoothly
	var best_p: AudioStreamPlayer = _sfx_players[0]
	var max_pos: float = 0.0
	for p: AudioStreamPlayer in _sfx_players:
		var pos: float = p.get_playback_position()
		if pos > max_pos:
			max_pos = pos
			best_p = p

	best_p.stream = stream
	best_p.pitch_scale = pitch
	best_p.volume_db = volume_offset_db + vol_jitter
	best_p.play()


func play_sfx_range(sfx_name: String, min_pitch: float, max_pitch: float, volume_offset_db: float = 0.0) -> void:
	var pitch: float = _calculate_pitch(sfx_name, min_pitch, max_pitch)
	play_sfx(sfx_name, pitch, volume_offset_db)


func _on_wave_started(_floor_idx: int) -> void:
	is_game_over = false
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
