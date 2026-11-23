class_name FloorManager
extends Node
## Orchestrates floor progression, shop/draft transitions, and run lifecycle.

@export var arena: Arena = null
@export var spawner: Spawner = null
@export var player: Player = null
@export var wave_shop_ui: WaveShopUI = null
@export var boss_draft_ui: BossDraftUI = null

var default_tower: TowerData = preload("res://src/data/towers/blightwood_spire.tres")
var sanctuary_scene: PackedScene = preload("res://src/arena/Sanctuary.tscn")
var all_floor_configs: Array[FloorConfig] = []
var all_items_pool: Array[ItemData] = []
var _current_sanctuary: Node2D = null
var _random_sanctuary_floor: int = -1
var _random_merchant_floor: int = -1
var _boss_draft_opened_for_floor: int = -1
var _shop_opened_for_floor: int = -1
var is_double_boss_event: bool = false
var double_boss_stage: int = 0


func _ready() -> void:
	_load_floor_configs()
	_load_items_pool()

	EventBus.wave_ended.connect(_on_wave_ended)
	EventBus.floor_cleared.connect(_on_floor_cleared)
	EventBus.boss_killed.connect(_on_boss_killed)
	EventBus.shop_closed.connect(_on_shop_closed)
	EventBus.draft_closed.connect(_on_draft_closed)
	EventBus.floor_transition_requested.connect(_on_floor_transition_requested)
	EventBus.player_died.connect(_on_player_died)

	call_deferred(&"start_default_run")


func _load_floor_configs() -> void:
	if not GameManager.floor_configs.is_empty():
		all_floor_configs = GameManager.floor_configs
	else:
		all_floor_configs = FloorConfig.generate_100_floors()
		GameManager.floor_configs = all_floor_configs


func _load_items_pool() -> void:
	all_items_pool.clear()
	var item_paths: Array[String] = [
		# Weapons
		"res://src/data/items/weapons/dagger.tres",
		"res://src/data/items/weapons/iron_sword.tres",
		"res://src/data/items/weapons/iron_spear.tres",
		"res://src/data/items/weapons/greatsword.tres",
		"res://src/data/items/weapons/short_bow.tres",
		"res://src/data/items/weapons/hunting_crossbow.tres",
		"res://src/data/items/weapons/flame_sword.tres",
		"res://src/data/items/weapons/crystal_staff.tres",
		"res://src/data/items/weapons/vampire_dagger.tres",
		"res://src/data/items/weapons/scythe_of_doom.tres",
		"res://src/data/items/weapons/golden_repeater.tres",
		"res://src/data/items/weapons/berserker_axe.tres",
		# Spells
		"res://src/data/items/spells/spell_fireball.tres",
		"res://src/data/items/spells/spell_molten_spear.tres",
		"res://src/data/items/spells/spell_tornado.tres",
		"res://src/data/items/spells/spell_earth_spike.tres",
		"res://src/data/items/spells/spell_water_geyser.tres",
		"res://src/data/items/spells/spell_void_portal.tres",
		"res://src/data/items/spells/spell_meteor_rock.tres",
		# Buffs
		"res://src/data/items/buffs/ruby_ring.tres",
		"res://src/data/items/buffs/leather_boots.tres",
		"res://src/data/items/buffs/crystal_pendant.tres",
		"res://src/data/items/buffs/iron_shield.tres",
		"res://src/data/items/buffs/health_potion.tres",
		"res://src/data/items/buffs/golden_magnet.tres",
		"res://src/data/items/buffs/lucky_clover.tres",
		"res://src/data/items/buffs/hermes_wings.tres",
		"res://src/data/items/buffs/blacksmith_talisman.tres",
		"res://src/data/items/buffs/vampire_chalice.tres",
		"res://src/data/items/buffs/frost_heart.tres",
		"res://src/data/items/buffs/spell_echo_prism.tres",
	]
	for p: String in item_paths:
		if ResourceLoader.exists(p):
			all_items_pool.append(load(p) as ItemData)


func start_default_run() -> void:
	if GameManager.current_tower == null:
		GameManager.start_new_run(default_tower, all_floor_configs)
	start_floor(GameManager.current_floor_index)


func start_floor(floor_num: int) -> void:
	var config: FloorConfig = null
	if floor_num >= 1 and floor_num <= all_floor_configs.size():
		config = all_floor_configs[floor_num - 1]
	else:
		return

	_clean_sanctuary()
	_clean_pickups()
	_clean_enemies()

	# Save checkpoint for the current floor
	SaveManager.save_run()

	# Setup arena tiles and dimensions
	if arena != null:
		arena.setup_floor(GameManager.current_tower, config)

	# Reset player to exact center of arena and clear movement
	if player != null:
		var center_pos: Vector2 = arena.get_center_position() if arena != null else Vector2(448, 288)
		player.global_position = center_pos
		player.velocity = Vector2.ZERO
		var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if cam != null:
			cam.reset_smoothing()

	is_double_boss_event = false
	double_boss_stage = 0
	if config.floor_type == FloorConfig.FloorType.MINIBOSS:
		# 40% tỉ lệ kích hoạt sự kiện Song Đấu Trùm (Double Miniboss)
		is_double_boss_event = (randf() <= 0.40)
		double_boss_stage = 1
		if is_double_boss_event:
			var hud_nodes: Array[Node] = get_tree().get_nodes_in_group(&"hud")
			if hud_nodes.size() > 0:
				var hud: HUD = hud_nodes[0] as HUD
				if hud != null and hud.timer_label != null:
					hud.timer_label.text = "SỰ KIỆN: SONG ĐẤU TRÙM (DOUBLE BOSS)!"

	var is_sanctuary: bool = (config.floor_type == FloorConfig.FloorType.NPC_SANCTUARY)

	# NPC Sanctuary / Merchant Floor: Safe haven without monsters
	if is_sanctuary:
		if spawner != null:
			spawner.stop_spawning()
		if arena != null and sanctuary_scene != null:
			var sanctuary_instance: Sanctuary = sanctuary_scene.instantiate() as Sanctuary
			sanctuary_instance.global_position = arena.get_center_position()
			arena.add_child(sanctuary_instance)
			_current_sanctuary = sanctuary_instance
			sanctuary_instance.portal_entered.connect(_on_sanctuary_portal_entered)
		EventBus.wave_started.emit(floor_num)
	else:
		# Start enemy spawner
		if spawner != null:
			spawner.start_floor(GameManager.current_tower, config)


func _clean_sanctuary() -> void:
	if _current_sanctuary != null and is_instance_valid(_current_sanctuary):
		_current_sanctuary.queue_free()
		_current_sanctuary = null


func _clean_pickups() -> void:
	for p: Node in get_tree().get_nodes_in_group(&"gold_pickups"):
		if is_instance_valid(p):
			p.queue_free()


func _clean_enemies() -> void:
	for e: Node in get_tree().get_nodes_in_group(&"enemies"):
		if is_instance_valid(e):
			e.queue_free()


func _on_sanctuary_portal_entered() -> void:
	SaveManager.save_run()
	_clean_sanctuary()
	_clean_pickups()
	GameManager.advance_floor()


func _on_wave_ended(floor_index: int) -> void:
	if spawner != null:
		spawner.stop_spawning()

	if _shop_opened_for_floor == floor_index:
		return
	_shop_opened_for_floor = floor_index

	var cfg: FloorConfig = GameManager.get_current_floor_config()
	if cfg != null and cfg.floor_type == FloorConfig.FloorType.COMBAT_WAVE:
		# Brief 1s delay before opening shop
		var tw: Tween = create_tween()
		tw.tween_interval(1.0)
		tw.tween_callback(func():
			var shop_items: Array[ItemData] = ItemPool.get_random_items(3, all_items_pool)
			if wave_shop_ui != null:
				wave_shop_ui.open_shop(shop_items)
			EventBus.shop_opened.emit(shop_items)
		)
	else:
		# Auto-advance for non-shop wave types
		var tw: Tween = create_tween()
		tw.tween_interval(2.0)
		tw.tween_callback(func(): GameManager.advance_floor())


func _on_boss_killed(_boss_id: String) -> void:
	var cfg: FloorConfig = GameManager.get_current_floor_config()
	if cfg != null and cfg.floor_type == FloorConfig.FloorType.MINIBOSS:
		# Double Miniboss event: đánh xong boss 1 thì đánh tiếp 1 con nữa, không mở draft ngay
		if is_double_boss_event and double_boss_stage == 1:
			double_boss_stage = 2
			AudioManager.play_sfx("confirm")
			var hud_nodes: Array[Node] = get_tree().get_nodes_in_group(&"hud")
			if hud_nodes.size() > 0:
				var hud: HUD = hud_nodes[0] as HUD
				if hud != null and hud.timer_label != null:
					hud.timer_label.text = "CẢNH BÁO: TRÙM THỨ 2 XUẤT HIỆN!"
			var tw_second: Tween = create_tween()
			tw_second.tween_interval(1.5)
			tw_second.tween_callback(func():
				if spawner != null:
					spawner.spawn_second_miniboss()
			)
			return
		else:
			EventBus.floor_cleared.emit(GameManager.current_floor_index)
	elif cfg != null and cfg.floor_type == FloorConfig.FloorType.FINAL_BOSS:
		EventBus.floor_cleared.emit(GameManager.current_floor_index)


func _on_floor_cleared(floor_index: int) -> void:
	if spawner != null:
		spawner.stop_spawning()

	if _boss_draft_opened_for_floor == floor_index:
		return
	_boss_draft_opened_for_floor = floor_index

	var cfg: FloorConfig = GameManager.get_current_floor_config()
	if cfg != null and cfg.floor_type == FloorConfig.FloorType.MINIBOSS:
		# Open boss draft (pick 2 of 5 for free) after 3s (giảm từ 10s xuống 3s để nhặt đồ nhanh)
		var tw: Tween = create_tween()
		tw.tween_interval(3.0)
		tw.tween_callback(func():
			var draft_items: Array[ItemData] = ItemPool.get_boss_draft_items(5, all_items_pool)
			if boss_draft_ui != null:
				boss_draft_ui.open_draft(draft_items)
			EventBus.draft_opened.emit(draft_items)
		)
	elif cfg != null and cfg.floor_type == FloorConfig.FloorType.FINAL_BOSS:
		# Tower Conquered! Show Endgame Victory Screen after 3s
		var tw: Tween = create_tween()
		tw.tween_interval(3.0)
		tw.tween_callback(func():
			EventBus.tower_conquered.emit()
		)
	else:
		var tw: Tween = create_tween()
		tw.tween_interval(2.0)
		tw.tween_callback(func(): GameManager.advance_floor())


func _on_shop_closed() -> void:
	# Permadeath save: save after shop is closed before next floor begins
	SaveManager.save_run()
	_clean_pickups()
	GameManager.advance_floor()


func _on_draft_closed() -> void:
	SaveManager.save_run()
	_clean_pickups()
	GameManager.advance_floor()


func _on_floor_transition_requested(next_floor_index: int) -> void:
	start_floor(next_floor_index)


func _on_player_died() -> void:
	_clean_sanctuary()
	if spawner != null:
		spawner.stop_spawning()
	for e: Node in get_tree().get_nodes_in_group(&"enemies"):
		if is_instance_valid(e) and e is Node2D:
			e.set_physics_process(false)
			e.set_process(false)
