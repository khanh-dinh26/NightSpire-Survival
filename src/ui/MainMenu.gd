class_name MainMenu
extends Control
## Main Title Menu: New Run, Continue Saved Expedition, or Quit.

@onready var new_run_btn: Button = $Margin/VBox/MenuPanel/Margin/VBox/NewRunButton
@onready var continue_btn: Button = $Margin/VBox/MenuPanel/Margin/VBox/ContinueButton
@onready var sound_btn: Button = $Margin/VBox/MenuPanel/Margin/VBox/SoundButton
@onready var exit_btn: Button = $Margin/VBox/MenuPanel/Margin/VBox/ExitButton
@onready var sound_modal: SoundSettings = $SoundSettingsModal

# Lively Background Nodes
@onready var floor_layer: TileMapLayer = get_node_or_null("Background/FloorLayer") as TileMapLayer
@onready var fire_left: Sprite2D = get_node_or_null("Background/Campfires/FireLeft") as Sprite2D
@onready var fire_right: Sprite2D = get_node_or_null("Background/Campfires/FireRight") as Sprite2D
@onready var rogue_left: Sprite2D = get_node_or_null("Background/Rogues/RogueLeft") as Sprite2D
@onready var rogue_right: Sprite2D = get_node_or_null("Background/Rogues/RogueRight") as Sprite2D

var _fire_timer: float = 0.0
var _fire_frame: int = 0
const FIRE_FRAME_TIME: float = 0.12
const FIRE_BASE_Y: int = 224


func _ready() -> void:
	AudioManager.play_bgm("title")
	_setup_background()

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


func _process(delta: float) -> void:
	_fire_timer += delta
	if _fire_timer >= FIRE_FRAME_TIME:
		_fire_timer -= FIRE_FRAME_TIME
		_fire_frame = (_fire_frame + 1) % 4
		var frame_rect: Rect2 = Rect2(_fire_frame * 32, FIRE_BASE_Y, 32, 32)
		if fire_left != null:
			fire_left.region_rect = frame_rect
		if fire_right != null:
			fire_right.region_rect = frame_rect


func _setup_background() -> void:
	# 1. Ensure TileSetAtlasSource has all tiles created and pave dungeon floor
	if floor_layer != null and floor_layer.tile_set != null:
		var source: TileSetAtlasSource = floor_layer.tile_set.get_source(0) as TileSetAtlasSource
		if source != null:
			for tx: int in range(17):
				for ty: int in range(26):
					if not source.has_tile(Vector2i(tx, ty)):
						source.create_tile(Vector2i(tx, ty))

		# Top wall stone row
		for x: int in range(20):
			var wall_coord: Vector2i = Vector2i(x % 2, 0)
			floor_layer.set_cell(Vector2i(x, 0), 0, wall_coord)

		# Dungeon stone masonry floor
		var floor_coords: Array[Vector2i] = [
			Vector2i(0, 1), Vector2i(1, 1),
			Vector2i(1, 7), Vector2i(2, 7)
		]
		for y: int in range(1, 12):
			for x: int in range(20):
				var tile_coord: Vector2i = floor_coords[(x * 3 + y * 7) % floor_coords.size()]
				floor_layer.set_cell(Vector2i(x, y), 0, tile_coord)

	# 2. Breathing / bobbing idle animation for rogues
	if rogue_left != null:
		var tw_left: Tween = create_tween().set_loops()
		tw_left.tween_property(rogue_left, ^"scale", Vector2(1.5, 1.62), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_left.tween_property(rogue_left, ^"scale", Vector2(1.5, 1.40), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if rogue_right != null:
		var tw_right: Tween = create_tween().set_loops()
		tw_right.tween_property(rogue_right, ^"scale", Vector2(1.5, 1.40), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_right.tween_property(rogue_right, ^"scale", Vector2(1.5, 1.62), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
