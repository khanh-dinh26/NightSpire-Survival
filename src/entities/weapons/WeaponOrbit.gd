class_name WeaponOrbit
extends Node2D
## Manages weapon nodes orbiting the player in a circle.

const MAX_WEAPONS: int = 5

var weapons: Array[WeaponBase] = []
var orbit_radius: float = 30.0
var rotation_speed: float = 1.4  # rad/s

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
	weapon.setup(item)
	weapons.append(weapon)
	_reposition_weapons()


func remove_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	var weapon: WeaponBase = weapons[index]
	weapons.remove_at(index)
	weapon.queue_free()
	_reposition_weapons()


func _reposition_weapons() -> void:
	var count: int = weapons.size()
	if count == 0:
		return
	for i: int in range(count):
		var angle: float = _orbit_angle + (float(i) / float(count)) * TAU
		weapons[i].position = Vector2(cos(angle), sin(angle)) * orbit_radius
