class_name MainMenu
extends Control
## Main Title Menu: New Run, Continue Saved Expedition, or Quit.

@onready var new_run_btn: Button = $Margin/VBox/MenuPanel/Margin/VBox/NewRunButton
@onready var continue_btn: Button = $Margin/VBox/MenuPanel/Margin/VBox/ContinueButton
@onready var sound_btn: Button = $Margin/VBox/MenuPanel/Margin/VBox/SoundButton
@onready var exit_btn: Button = $Margin/VBox/MenuPanel/Margin/VBox/ExitButton
@onready var sound_modal: SoundSettings = $SoundSettingsModal


func _ready() -> void:
	AudioManager.play_bgm("title")
	new_run_btn.pressed.connect(func():
		AudioManager.play_sfx("confirm")
		_on_new_run_pressed()
	)
	continue_btn.pressed.connect(func():
		AudioManager.play_sfx("confirm")
		_on_continue_pressed()
	)
	sound_btn.pressed.connect(func():
		AudioManager.play_sfx("confirm")
		sound_modal.open()
	)
	exit_btn.pressed.connect(func():
		AudioManager.play_sfx("confirm")
		get_tree().quit()
	)

	continue_btn.disabled = not SaveManager.has_save()
	if continue_btn.disabled:
		continue_btn.text = "Tiếp Tục (Chưa có Save)"
	else:
		continue_btn.text = "Tiếp Tục Chuyến Đi"


func _on_new_run_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/TowerSelect.tscn")


func _on_continue_pressed() -> void:
	if not SaveManager.has_save():
		return
	var save_data: Dictionary = SaveManager.load_run()
	if save_data.is_empty():
		return

	# Load tower
	var tower_id: String = save_data.get("tower_id", "blightwood")
	var tower_path: String = "res://src/data/towers/%s_spire.tres" % tower_id
	if not ResourceLoader.exists(tower_path):
		tower_path = "res://src/data/towers/blightwood_spire.tres"
	var tower: TowerData = load(tower_path) as TowerData

	# Load floors
	var floors: Array[FloorConfig] = []
	for i: int in range(1, 11):
		var path: String = "res://src/data/floors/floor_%02d.tres" % i
		if ResourceLoader.exists(path):
			floors.append(load(path) as FloorConfig)

	GameManager.current_tower = tower
	GameManager.floor_configs = floors
	GameManager.current_floor_index = int(save_data.get("next_floor", 1))
	GameManager.gold = int(save_data.get("gold", 0))
	GameManager.player_max_hp = int(save_data.get("max_hp", 100))
	GameManager.player_current_hp = int(save_data.get("current_hp", 100))

	# Restore equipped weapons
	GameManager.equipped_weapons.clear()
	var weapon_ids: Array = save_data.get("equipped_weapons", [])
	for wid: Variant in weapon_ids:
		var w_path: String = "res://src/data/items/weapons/%s.tres" % str(wid)
		if ResourceLoader.exists(w_path):
			GameManager.equipped_weapons.append(load(w_path) as ItemData)

	# Restore passives
	GameManager.passive_buffs.clear()
	var passive_ids: Array = save_data.get("passives", [])
	for pid: Variant in passive_ids:
		var p_path: String = "res://src/data/items/buffs/%s.tres" % str(pid)
		if ResourceLoader.exists(p_path):
			GameManager.passive_buffs.append(load(p_path) as ItemData)

	get_tree().change_scene_to_file("res://src/arena/Arena.tscn")
