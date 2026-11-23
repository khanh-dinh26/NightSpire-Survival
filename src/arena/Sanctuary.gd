class_name Sanctuary
extends Node2D
## Floor 9 NPC Sanctuary: Safe haven before the Final Boss.
## Hosts Blacksmith (weapon upgrade), Alchemist (effects/buffs), Smuggler/Merchant (items), and Summit Portal.

signal portal_entered()

@onready var portal_sprite: AnimatedSprite2D = $Portal/AnimatedSprite2D
@onready var campfire_sprite: Sprite2D = $Campfire/Sprite2D
@onready var shop_ui: Node = $SanctuaryShopUI

# NPC Prompt Buttons
@onready var bs_btn: Button = $Blacksmith/PromptContainer/Button
@onready var alch_btn: Button = $Alchemist/PromptContainer/Button
@onready var smug_btn: Button = $Smuggler/PromptContainer/Button
@onready var portal_btn: Button = $Portal/PromptContainer/Button

# NPC Overlap state
var player_in_bs: bool = false
var player_in_alch: bool = false
var player_in_smug: bool = false
var player_in_portal: bool = false

var _animated_tiles_tex: Texture2D = preload("res://assets/sprites/animated-tiles.png")
var _rogues_tex: Texture2D = preload("res://assets/sprites/rogues.png")

var _fire_timer: float = 0.0
var _fire_frame: int = 0


func _ready() -> void:
	_setup_sprites()
	_connect_signals()


func _setup_sprites() -> void:
	# Campfire sprite setup (fire pit row 4 in animated-tiles.png)
	campfire_sprite.texture = _animated_tiles_tex
	campfire_sprite.region_enabled = true
	campfire_sprite.region_rect = Rect2(0, 96, 32, 32)

	# Blacksmith: Row 7, Col 5 (128, 192, 32, 32)
	var bs_sp: Sprite2D = $Blacksmith/Sprite2D
	bs_sp.texture = _rogues_tex
	bs_sp.region_enabled = true
	bs_sp.region_rect = Rect2(128, 192, 32, 32)

	# Alchemist: Priest Row 3, Col 2 (32, 64, 32, 32)
	var alch_sp: Sprite2D = $Alchemist/Sprite2D
	alch_sp.texture = _rogues_tex
	alch_sp.region_enabled = true
	alch_sp.region_rect = Rect2(32, 64, 32, 32)

	# Smuggler: Bandit Row 1, Col 5 (128, 0, 32, 32)
	var smug_sp: Sprite2D = $Smuggler/Sprite2D
	smug_sp.texture = _rogues_tex
	smug_sp.region_enabled = true
	smug_sp.region_rect = Rect2(128, 0, 32, 32)

	# Setup animated portal frames from assets/effects/magic_effects/Portal
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(&"portal_spin")
	frames.set_animation_speed(&"portal_spin", 8.0)
	frames.set_animation_loop(&"portal_spin", true)
	for i: int in range(1, 11):
		var p_path: String = "res://assets/effects/magic_effects/Portal/%03d.png" % i
		if ResourceLoader.exists(p_path):
			var tex: Texture2D = load(p_path) as Texture2D
			frames.add_frame(&"portal_spin", tex)
	portal_sprite.sprite_frames = frames
	portal_sprite.play(&"portal_spin")


func _process(delta: float) -> void:
	# Animate campfire flame
	_fire_timer += delta
	if _fire_timer >= 0.12:
		_fire_timer = 0.0
		_fire_frame = (_fire_frame + 1) % 4
		campfire_sprite.region_rect = Rect2(_fire_frame * 32, 96, 32, 32)


func _unhandled_input(event: InputEvent) -> void:
	if shop_ui != null and shop_ui.visible:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		if player_in_bs:
			_interact_blacksmith()
			get_viewport().set_input_as_handled()
		elif player_in_alch:
			_interact_alchemist()
			get_viewport().set_input_as_handled()
		elif player_in_smug:
			_interact_smuggler()
			get_viewport().set_input_as_handled()
		elif player_in_portal:
			_interact_portal()
			get_viewport().set_input_as_handled()


func _connect_signals() -> void:
	var bs_area: Area2D = $Blacksmith/Area2D
	bs_area.body_entered.connect(func(b):
		if b is Player:
			player_in_bs = true
			$Blacksmith/PromptContainer.visible = true
	)
	bs_area.body_exited.connect(func(b):
		if b is Player:
			player_in_bs = false
			$Blacksmith/PromptContainer.visible = false
	)
	bs_btn.pressed.connect(_interact_blacksmith)

	var alch_area: Area2D = $Alchemist/Area2D
	alch_area.body_entered.connect(func(b):
		if b is Player:
			player_in_alch = true
			$Alchemist/PromptContainer.visible = true
	)
	alch_area.body_exited.connect(func(b):
		if b is Player:
			player_in_alch = false
			$Alchemist/PromptContainer.visible = false
	)
	alch_btn.pressed.connect(_interact_alchemist)

	var smug_area: Area2D = $Smuggler/Area2D
	smug_area.body_entered.connect(func(b):
		if b is Player:
			player_in_smug = true
			$Smuggler/PromptContainer.visible = true
	)
	smug_area.body_exited.connect(func(b):
		if b is Player:
			player_in_smug = false
			$Smuggler/PromptContainer.visible = false
	)
	smug_btn.pressed.connect(_interact_smuggler)

	var portal_area: Area2D = $Portal/Area2D
	portal_area.body_entered.connect(func(b):
		if b is Player:
			player_in_portal = true
			$Portal/PromptContainer.visible = true
	)
	portal_area.body_exited.connect(func(b):
		if b is Player:
			player_in_portal = false
			$Portal/PromptContainer.visible = false
	)
	portal_btn.pressed.connect(_interact_portal)


func _interact_blacksmith() -> void:
	if shop_ui != null:
		shop_ui.open_blacksmith()


func _interact_alchemist() -> void:
	if shop_ui != null:
		shop_ui.open_alchemist()


func _interact_smuggler() -> void:
	if shop_ui != null:
		shop_ui.open_merchant()


func _interact_portal() -> void:
	portal_entered.emit()
