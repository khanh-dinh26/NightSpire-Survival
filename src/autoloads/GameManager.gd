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
var is_dark_night: bool = false
var dark_night_cycle: int = 0
var hero_ultimate_charge: int = 0

# ---- Inventory ----
const MAX_WEAPONS: int = 10
var equipped_weapons: Array[ItemData] = []
var passive_buffs: Array[ItemData] = []
var learned_spells: Dictionary = {} # spell_id: String -> level: int

# ---- Floor Configs (populated when tower is selected) ----
var floor_configs: Array[FloorConfig] = []

# ---- Reroll ----
var reroll_cost: int = 10
var reroll_cost_increment: int = 5
var shops_without_reroll_count: int = 0
var has_used_reroll_ever: bool = false


func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_died.connect(_on_player_died)


func start_new_run(tower: TowerData, floors: Array[FloorConfig], p_class: ClassData = null) -> void:
	current_tower = tower
	floor_configs = floors
	chosen_class = p_class
	current_floor_index = 1
	gold = 0
	hero_ultimate_charge = 0
	is_dark_night = false
	dark_night_cycle = 0
	equipped_weapons.clear()
	passive_buffs.clear()
	learned_spells.clear()
	reroll_cost = 10
	shops_without_reroll_count = 0
	has_used_reroll_ever = false

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
	var total_floors: int = floor_configs.size() if not floor_configs.is_empty() else 10
	if current_floor_index < total_floors:
		current_floor_index += 1
		EventBus.floor_transition_requested.emit(current_floor_index)


func add_gold(amount: int) -> void:
	if current_tower != null and current_tower.player_gold_mult != 1.0:
		amount = roundi(float(amount) * current_tower.player_gold_mult)
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
			# Check if weapon already exists -> Upgrade damage and level!
			var existing_weapon: ItemData = null
			for w: ItemData in equipped_weapons:
				if w.item_id == item.item_id:
					existing_weapon = w
					break
			if existing_weapon != null:
				existing_weapon.level += 1
				existing_weapon.base_damage = roundi(existing_weapon.base_damage * 1.4)
				var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
				if players.size() > 0:
					var p: Player = players[0] as Player
					if p != null and p.weapon_orbit != null:
						p.weapon_orbit.upgrade_weapon(existing_weapon)
				EventBus.weapons_changed.emit()
				return
			else:
				equipped_weapons.append(item)
				EventBus.weapons_changed.emit()
		ItemData.ItemType.PASSIVE_BUFF:
			var existing_buff: ItemData = null
			for b: ItemData in passive_buffs:
				if b.item_id == item.item_id:
					existing_buff = b
					break
			if existing_buff != null:
				existing_buff.level += 1
			else:
				var buff_copy: ItemData = item.duplicate()
				buff_copy.level = 1
				passive_buffs.append(buff_copy)
		ItemData.ItemType.SPELL:
			var s_id: String = item.spell_id if not item.spell_id.is_empty() else item.item_id
			if learned_spells.has(s_id):
				learned_spells[s_id] += 1
			else:
				learned_spells[s_id] = 1

			# Emblem infusion into equipped weapons!
			var socketed: bool = false
			for w: ItemData in equipped_weapons:
				if w.embedded_spell == s_id:
					w.embedded_spell_level += 1
					socketed = true
					break
			if not socketed:
				for w: ItemData in equipped_weapons:
					if w.embedded_spell.is_empty():
						w.embedded_spell = s_id
						w.embedded_spell_level = 1
						socketed = true
						break
			if not socketed and not equipped_weapons.is_empty():
				equipped_weapons[0].embedded_spell = s_id
				equipped_weapons[0].embedded_spell_level = 1

			var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
			if players.size() > 0:
				var p: Player = players[0] as Player
				if p != null and p.weapon_orbit != null:
					p.weapon_orbit.sync_weapons(equipped_weapons)

			EventBus.spell_learned.emit(s_id, learned_spells[s_id])
			EventBus.weapons_changed.emit()

	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		var p: Player = players[0] as Player
		if p != null:
			p.apply_item(item)


func inlay_spell_into_weapon(slot_idx: int, spell_item: ItemData) -> void:
	if slot_idx < 0 or slot_idx >= equipped_weapons.size():
		return
	var s_id: String = spell_item.spell_id if not spell_item.spell_id.is_empty() else spell_item.item_id
	if learned_spells.has(s_id):
		learned_spells[s_id] += 1
	else:
		learned_spells[s_id] = 1

	var target_w: ItemData = equipped_weapons[slot_idx]
	if target_w.embedded_spell == s_id:
		target_w.embedded_spell_level += 1
	else:
		target_w.embedded_spell = s_id
		target_w.embedded_spell_level = 1

	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		var p: Player = players[0] as Player
		if p != null and p.weapon_orbit != null:
			p.weapon_orbit.sync_weapons(equipped_weapons)

	EventBus.spell_learned.emit(s_id, learned_spells[s_id])
	EventBus.weapons_changed.emit()


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
