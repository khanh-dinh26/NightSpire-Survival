class_name SoundSettings
extends Control
## Sound & Music Settings modal dialog.
## Controls Master/SFX and Music volume sliders and mute toggles.

signal closed

@onready var fullscreen_btn: Button = %FullscreenBtn

@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_val_label: Label = %SFXValLabel
@onready var sfx_mute_btn: Button = %SFXMuteBtn

@onready var music_slider: HSlider = %MusicSlider
@onready var music_val_label: Label = %MusicValLabel
@onready var music_mute_btn: Button = %MusicMuteBtn

@onready var close_btn: Button = %CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sync_ui_from_audio()
	_sync_display_mode_ui()

	if fullscreen_btn != null:
		fullscreen_btn.pressed.connect(_on_fullscreen_toggled)

	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	sfx_mute_btn.pressed.connect(_on_sfx_mute_toggled)

	music_slider.value_changed.connect(_on_music_slider_changed)
	music_mute_btn.pressed.connect(_on_music_mute_toggled)

	close_btn.pressed.connect(_on_close_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_on_fullscreen_toggled()
		get_viewport().set_input_as_handled()
		return
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func open() -> void:
	_sync_ui_from_audio()
	_sync_display_mode_ui()
	visible = true


func _sync_display_mode_ui() -> void:
	if fullscreen_btn == null:
		return
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var is_fs: bool = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	if is_fs:
		fullscreen_btn.text = "Toàn Màn Hình (Fullscreen)"
		fullscreen_btn.modulate = Color(0.4, 0.9, 1.0, 1.0)
	else:
		fullscreen_btn.text = "Cửa Sổ (Windowed)"
		fullscreen_btn.modulate = Color(1.0, 0.9, 0.4, 1.0)


func _on_fullscreen_toggled() -> void:
	AudioManager.play_sfx("confirm")
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var is_fs: bool = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	if is_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_sync_display_mode_ui()


func _on_close_pressed() -> void:
	AudioManager.play_sfx("confirm")
	visible = false
	closed.emit()


func _sync_ui_from_audio() -> void:
	# SFX
	var sfx_vol: float = AudioManager.get_bus_volume("SFX")
	var sfx_muted: bool = AudioManager.is_bus_muted("SFX")
	sfx_slider.set_value_no_signal(sfx_vol * 100.0)
	sfx_val_label.text = "%d%%" % int(round(sfx_vol * 100.0))
	sfx_mute_btn.text = "Tắt" if sfx_muted else "Bật"
	sfx_mute_btn.modulate = Color(1.0, 0.4, 0.4, 1.0) if sfx_muted else Color(0.4, 1.0, 0.5, 1.0)

	# Music
	var mus_vol: float = AudioManager.get_bus_volume("Music")
	var mus_muted: bool = AudioManager.is_bus_muted("Music")
	music_slider.set_value_no_signal(mus_vol * 100.0)
	music_val_label.text = "%d%%" % int(round(mus_vol * 100.0))
	music_mute_btn.text = "Tắt" if mus_muted else "Bật"
	music_mute_btn.modulate = Color(1.0, 0.4, 0.4, 1.0) if mus_muted else Color(0.4, 1.0, 0.5, 1.0)


func _on_sfx_slider_changed(val: float) -> void:
	var linear: float = val / 100.0
	AudioManager.set_bus_volume("SFX", linear)
	sfx_val_label.text = "%d%%" % int(round(val))
	# Unmute automatically if user moves slider up from 0
	if AudioManager.is_bus_muted("SFX") and linear > 0.01:
		AudioManager.set_bus_mute("SFX", false)
		sfx_mute_btn.text = "Bật"
		sfx_mute_btn.modulate = Color(0.4, 1.0, 0.5, 1.0)


func _on_sfx_mute_toggled() -> void:
	var now_muted: bool = not AudioManager.is_bus_muted("SFX")
	AudioManager.set_bus_mute("SFX", now_muted)
	sfx_mute_btn.text = "Tắt" if now_muted else "Bật"
	sfx_mute_btn.modulate = Color(1.0, 0.4, 0.4, 1.0) if now_muted else Color(0.4, 1.0, 0.5, 1.0)
	if not now_muted:
		AudioManager.play_sfx("confirm")


func _on_music_slider_changed(val: float) -> void:
	var linear: float = val / 100.0
	AudioManager.set_bus_volume("Music", linear)
	music_val_label.text = "%d%%" % int(round(val))
	# Unmute automatically if user moves slider up from 0
	if AudioManager.is_bus_muted("Music") and linear > 0.01:
		AudioManager.set_bus_mute("Music", false)
		music_mute_btn.text = "Bật"
		music_mute_btn.modulate = Color(0.4, 1.0, 0.5, 1.0)


func _on_music_mute_toggled() -> void:
	var now_muted: bool = not AudioManager.is_bus_muted("Music")
	AudioManager.set_bus_mute("Music", now_muted)
	music_mute_btn.text = "Tắt" if now_muted else "Bật"
	music_mute_btn.modulate = Color(1.0, 0.4, 0.4, 1.0) if now_muted else Color(0.4, 1.0, 0.5, 1.0)
