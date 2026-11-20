class_name ItemData
extends Resource
## Data definition for a weapon or passive buff item.

enum ItemType { WEAPON, PASSIVE_BUFF, SPELL }
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
enum WeaponStyle { MELEE_ORBIT, RANGED_PROJECTILE }

@export var item_id: String = ""
@export var item_name: String = ""
@export var type: ItemType = ItemType.WEAPON
@export var rarity: Rarity = Rarity.COMMON
@export var price: int = 10
@export var level: int = 1

## Sprite region in items.png or icon
@export var sprite_region: Rect2 = Rect2(0, 0, 32, 32)
@export var custom_icon_path: String = ""

## Weapon stats (only if type == WEAPON)
@export var weapon_style: WeaponStyle = WeaponStyle.MELEE_ORBIT
@export var base_damage: int = 10
@export var attack_speed: float = 1.0  # attacks per second
@export var attack_range: float = 80.0  # detection range
@export var projectile_speed: float = 200.0  # only for RANGED_PROJECTILE
@export var knockback: float = 50.0

## Special Effect & Passive traits
## Options: "lifesteal", "radius_execute", "greed_gold", "berserk_low_hp"
@export var special_effect: String = ""
@export var special_effect_value: float = 0.0

## Embedded Spell Emblem (auto-fired from weapon)
## Options: "fireball", "molten_spear", "tornado", "earth_spike"
@export var embedded_spell: String = ""
@export var embedded_spell_level: int = 1

## Spell specific (if type == SPELL)
@export var spell_id: String = ""
@export var cooldown: float = 4.0

## Passive buff stats (only if type == PASSIVE_BUFF)
@export var stats_modifier: Dictionary = {}
# Example: {"max_hp": 20, "speed": 10, "damage_percent": 0.1, "defense": 5}

## Description for UI
@export_multiline var description: String = ""

## Rarity weights for item pool generation
static func rarity_weight(r: Rarity) -> float:
	match r:
		Rarity.COMMON: return 50.0
		Rarity.RARE: return 30.0
		Rarity.EPIC: return 15.0
		Rarity.LEGENDARY: return 5.0
	return 50.0


static func get_special_effect_name(effect_key: String) -> String:
	match effect_key:
		"berserk_low_hp":
			return "Cuồng Nộ Khi Máu Thấp"
		"greed_gold":
			return "Săn Tìm Vàng"
		"lifesteal":
			return "Hút Máu"
		"radius_execute":
			return "Trảm Sát Diện Rộng"
		_:
			return effect_key.capitalize()
