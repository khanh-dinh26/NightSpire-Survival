class_name WeaponOrbit
extends Node2D
## Manages up to 6 weapons orbiting the player in a balanced circle.

const MAX_WEAPONS: int = 6

var weapons: Array[WeaponBase] = []
var orbit_radius: float = 34.0
var rotation_speed: float = 3.8  # rad/s - spinning top whirl

var _orbit_angle: float = 0.0

@onready var _weapon_scene: PackedScene = preload("res://src/entities/weapons/WeaponBase.tscn")


func _process(delta: float) -> void:
	_orbit_angle += rotation_speed * delta
	_reposition_weapons()


func add_weapon(item: ItemData) -> void:
	if weapons.size() >= MAX_WEAPONS:
		return

	var weapon: WeaponBase = _weapon_scene.instantiate() as WeaponBase
	add_child(weapon)
	weapon.setup(item.duplicate())
	weapons.append(weapon)
	_reposition_weapons()


func upgrade_weapon(data: ItemData) -> void:
	for w: WeaponBase in weapons:
		if w.item_data != null and w.item_data.item_id == data.item_id:
			w.item_data.level = data.level
			w.item_data.base_damage = data.base_damage
			w.item_data.embedded_spell = data.embedded_spell
			w.item_data.embedded_spell_level = data.embedded_spell_level
			# Visual pop on upgrade
			var tw: Tween = create_tween()
			tw.tween_property(w, ^"scale", Vector2(1.5, 1.5), 0.08)
			tw.tween_property(w, ^"scale", Vector2(1.0, 1.0), 0.08)
			break


func sync_weapons(list: Array[ItemData]) -> void:
	for i: int in range(mini(weapons.size(), list.size())):
		if weapons[i] != null and is_instance_valid(weapons[i]):
			weapons[i].item_data = list[i]


func remove_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	var weapon: WeaponBase = weapons[index]
	weapons.remove_at(index)
	weapon.queue_free()
	_reposition_weapons()


func clear_weapons() -> void:
	for w: WeaponBase in weapons:
		w.queue_free()
	weapons.clear()


func _reposition_weapons() -> void:
	var total: int = weapons.size()
	if total == 0:
		return

	for i: int in range(total):
		var angle: float = _orbit_angle + (float(i) / float(total)) * TAU
		weapons[i].position = Vector2(cos(angle), sin(angle)) * orbit_radius
		weapons[i].rotation = angle + deg_to_rad(45.0)
