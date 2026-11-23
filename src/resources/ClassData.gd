class_name ClassData
extends Resource
## Data definition for a playable Character Class.

@export var class_id: String = ""
@export var display_name: String = ""
@export var sprite_region: Rect2 = Rect2(0, 0, 32, 32)
@export var max_hp: int = 100
@export var speed: float = 120.0
@export var defense: int = 0
@export var starter_weapon: ItemData = null
@export_multiline var description: String = ""

# --- Character Skill (Hồi theo thời gian - Cooldown) ---
@export var skill_id: String = ""
@export var skill_name: String = ""
@export_multiline var skill_desc: String = ""
@export var skill_cooldown: float = 7.0

# --- Ultimate Art (Tích nộ khi gây đủ sát thương - Damage Charged) ---
@export var ultimate_id: String = ""
@export var ultimate_name: String = ""
@export_multiline var ultimate_desc: String = ""
@export var ultimate_required_damage: int = 650

