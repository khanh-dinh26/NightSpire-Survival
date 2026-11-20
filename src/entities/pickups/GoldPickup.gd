class_name GoldPickup
extends Area2D
## Gold coin pickup — magnetic pull toward player, adds gold on collect.

var gold_amount: int = 1

# ── Preloaded ─────────────────────────────────────────────────────────
var _items_tex: Texture2D = preload("res://assets/sprites/items.png")

# ── Config ────────────────────────────────────────────────────────────
const MAGNET_RANGE: float = 50.0
const MAGNET_LERP_WEIGHT: float = 5.0

# ── Node references ──────────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite2D

# ── State ─────────────────────────────────────────────────────────────
var _collected: bool = false
var _float_tween: Tween = null
var _base_y: float = 0.0


func _ready() -> void:
	# Configure sprite
	sprite.texture = _items_tex
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 768, 32, 32)

	_base_y = position.y

	# Spawn bounce tween
	scale = Vector2.ZERO
	var spawn_tw: Tween = create_tween()
	spawn_tw.set_ease(Tween.EASE_OUT)
	spawn_tw.set_trans(Tween.TRANS_BACK)
	spawn_tw.tween_property(self, ^"scale", Vector2(1.0, 1.0), 0.3)
	spawn_tw.tween_callback(_start_float_animation)

	# Connect body entered
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _collected:
		return

	var player: Player = _get_player()
	if player == null:
		return

	var dist: float = global_position.distance_to(player.global_position)
	if dist < MAGNET_RANGE:
		global_position = global_position.lerp(player.global_position, MAGNET_LERP_WEIGHT * delta)


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if body is Player:
		_collected = true

		# Kill float tween
		if _float_tween != null and _float_tween.is_valid():
			_float_tween.kill()

		# Add gold
		GameManager.add_gold(gold_amount)
		AudioManager.play_sfx("buy")

		# Collect tween
		var tw: Tween = create_tween()
		tw.tween_property(self, ^"scale", Vector2.ZERO, 0.15)
		tw.tween_callback(queue_free)


func _start_float_animation() -> void:
	_float_tween = create_tween()
	_float_tween.set_loops()
	_float_tween.tween_property(sprite, ^"position:y", -3.0, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_float_tween.tween_property(sprite, ^"position:y", 3.0, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_float_tween.tween_property(sprite, ^"position:y", 0.0, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _get_player() -> Player:
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		return players[0] as Player
	return null
