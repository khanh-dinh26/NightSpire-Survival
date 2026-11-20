class_name GameManagerClass
extends Node
## Manages run state: current tower, floor progression, gold, inventory.

# ---- Run State ----
var current_tower: TowerData = null
var chosen_class: ClassData = null
var current_floor_index: int = 1  # 1..10
var gold: int = 0
var player_max_hp: int = 100
var player_current_hp: int = 100

# ---- Inventory ----
var equipped_weapons: Array[ItemData] = []
var passive_buffs: Array[ItemData] = []

# ---- Floor Configs (populated when tower is selected) ----
var floor_configs: Array[FloorConfig] = []

# ---- Reroll ----
var reroll_cost: int = 10
var reroll_cost_increment: int = 5


func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_died.connect(_on_player_died)


func start_new_run(tower: TowerData, floors: Array[FloorConfig], p_class: ClassData = null) -> void:
	current_tower = tower
	floor_configs = floors
	chosen_class = p_class
	current_floor_index = 1
	gold = 0
	equipped_weapons.clear()
	passive_buffs.clear()
	reroll_cost = 10

	if chosen_class != null:
		player_max_hp = chosen_class.max_hp
		player_current_hp = chosen_class.max_hp
		if chosen_class.starter_weapon != null:
			equipped_weapons.append(chosen_class.starter_weapon)
	else:
		player_max_hp = 100
		player_current_hp = 100
		var starter: ItemData = load("res://src/data/items/weapons/starter_dagger.tres")
		if starter != null:
			equipped_weapons.append(starter)


func get_current_floor_config() -> FloorConfig:
	if current_floor_index >= 1 and current_floor_index <= floor_configs.size():
		return floor_configs[current_floor_index - 1]
	return null


func advance_floor() -> void:
	if current_floor_index < 10:
		current_floor_index += 1
		EventBus.floor_transition_requested.emit(current_floor_index)


func add_gold(amount: int) -> void:
	if current_tower != null and current_tower.tower_modifier == TowerData.TowerModifier.REDUCED_HEAL_MORE_GOLD:
		amount = roundi(amount * 1.3)
	gold += amount
	EventBus.gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		EventBus.gold_changed.emit(gold)
		return true
	return false


func add_item(item: ItemData) -> void:
	match item.type:
		ItemData.ItemType.WEAPON:
			equipped_weapons.append(item)
			EventBus.weapons_changed.emit()
		ItemData.ItemType.PASSIVE_BUFF:
			passive_buffs.append(item)

	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		var p: Player = players[0] as Player
		if p != null:
			p.apply_item(item)


func remove_weapon(index: int) -> void:
	if index < 0 or index >= equipped_weapons.size():
		return
	var item: ItemData = equipped_weapons[index]
	equipped_weapons.remove_at(index)

	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		var p: Player = players[0] as Player
		if p != null and p.weapon_orbit != null:
			p.weapon_orbit.remove_weapon(index)

	EventBus.weapon_dropped.emit(item.item_id)
	EventBus.weapons_changed.emit()


func replace_weapon(index: int, new_item: ItemData) -> void:
	if index < 0 or index >= equipped_weapons.size():
		return
	remove_weapon(index)
	add_item(new_item)


func do_reroll() -> bool:
	if spend_gold(reroll_cost):
		reroll_cost += reroll_cost_increment
		return true
	return false


func _on_enemy_killed(_pos: Vector2, gold_value: int) -> void:
	add_gold(gold_value)


func _on_player_died() -> void:
	SaveManager.delete_save()
