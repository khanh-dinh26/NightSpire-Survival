class_name EnemyData
extends Resource
## Data definition for an enemy type.

enum EnemyType { NORMAL, MINIBOSS, FINAL_BOSS }

@export var enemy_id: String = ""
@export var enemy_name: String = ""
@export var enemy_type: EnemyType = EnemyType.NORMAL

## Stats
@export var max_hp: int = 30
@export var damage: int = 10
@export var speed: float = 60.0
@export var contact_knockback: float = 100.0

## Gold reward
@export var gold_drop_min: int = 1
@export var gold_drop_max: int = 3

## Sprite region in monsters.png or animals.png
@export var sprite_sheet: String = "monsters"  # "monsters" or "animals"
@export var sprite_region: Rect2 = Rect2(0, 0, 32, 32)

## Boss-specific
@export var attack_pattern: String = ""  # "charge", "summon", "aoe", "projectile"
@export var projectile_speed: float = 120.0
@export var attack_cooldown: float = 2.0
