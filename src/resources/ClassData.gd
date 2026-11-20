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
