class_name Sanctuary
extends Node2D
## Floor 9 NPC Sanctuary: Safe haven before the Final Boss.
## Hosts Blacksmith (weapon upgrade), Alchemist (heal), Smuggler (gamble), and Summit Portal.

signal portal_entered()

@onready var portal_sprite: AnimatedSprite2D = $Portal/AnimatedSprite2D
@onready var campfire_sprite: Sprite2D = $Campfire/Sprite2D

# NPC Prompts
@onready var bs_btn: Button = $Blacksmith/PromptContainer/Button
@onready var alch_btn: Button = $Alchemist/PromptContainer/Button
@onready var smug_btn: Button = $Smuggler/PromptContainer/Button
@onready var portal_btn: Button = $Portal/PromptContainer/Button

# Effect Buff pool for Alchemist (NPC Bán Effect)
var _effect_index: int = 0
var _effect_names: Array[String] = [
	"Full Heal & +30 Max HP Buff",
	"Haste Buff (+25 Speed)",
	"Iron Armor Buff (+2 Defense)"
]
var _effect_costs: Array[int] = [25, 25, 30]

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

	# Keyboard shortcut [E]
	if Input.is_key_pressed(KEY_E):
		if player_in_bs:
			_interact_blacksmith()
		elif player_in_alch:
			_interact_alchemist()
		elif player_in_smug:
			_interact_smuggler()
		elif player_in_portal:
			_interact_portal()


func _connect_signals() -> void:
	$Blacksmith.body_entered.connect(func(b): if b is Player: player_in_bs = true; $Blacksmith/PromptContainer.visible = true)
	$Blacksmith.body_exited.connect(func(b): if b is Player: player_in_bs = false; $Blacksmith/PromptContainer.visible = false)
	bs_btn.pressed.connect(_interact_blacksmith)

	$Alchemist.body_entered.connect(func(b): if b is Player: player_in_alch = true; $Alchemist/PromptContainer.visible = true)
	$Alchemist.body_exited.connect(func(b): if b is Player: player_in_alch = false; $Alchemist/PromptContainer.visible = false)
	alch_btn.pressed.connect(_interact_alchemist)

	$Smuggler.body_entered.connect(func(b): if b is Player: player_in_smug = true; $Smuggler/PromptContainer.visible = true)
	$Smuggler.body_exited.connect(func(b): if b is Player: player_in_smug = false; $Smuggler/PromptContainer.visible = false)
	smug_btn.pressed.connect(_interact_smuggler)

	$Portal.body_entered.connect(func(b): if b is Player: player_in_portal = true; $Portal/PromptContainer.visible = true)
	$Portal.body_exited.connect(func(b): if b is Player: player_in_portal = false; $Portal/PromptContainer.visible = false)
	portal_btn.pressed.connect(_interact_portal)


func _interact_blacksmith() -> void:
	const COST: int = 30
	if GameManager.gold >= COST:
		GameManager.spend_gold(COST)
		for w: ItemData in GameManager.equipped_weapons:
			w.base_damage = ceili(w.base_damage * 1.25)
		EventBus.weapons_changed.emit()
		bs_btn.text = "Upgraded (+25% Damage)!"
		var tw: Tween = create_tween()
		tw.tween_interval(1.5)
		tw.tween_callback(func(): bs_btn.text = "[E] Blacksmith: Upgrade Weapon (30 Gold)")
	else:
		bs_btn.text = "Not enough Gold!"
		var tw: Tween = create_tween()
		tw.tween_interval(1.0)
		tw.tween_callback(func(): bs_btn.text = "[E] Blacksmith: Upgrade Weapon (30 Gold)")


func _interact_alchemist() -> void:
	var cost: int = _effect_costs[_effect_index]
	var eff_name: String = _effect_names[_effect_index]
	if GameManager.gold >= cost:
		GameManager.spend_gold(cost)
		var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
		var p: Player = players[0] as Player if players.size() > 0 else null

		match _effect_index:
			0: # Max HP + heal
				if p != null:
					p.max_hp += 30
					GameManager.player_max_hp = p.max_hp
					p.heal(p.max_hp)
			1: # Speed
				if p != null:
					p.speed += 25.0
			2: # Defense
				if p != null:
					p.defense += 2

		alch_btn.text = "Acquired: %s!" % eff_name
		_effect_index = (_effect_index + 1) % _effect_names.size()
		var tw: Tween = create_tween()
		tw.tween_interval(1.8)
		tw.tween_callback(func():
			alch_btn.text = "[E] Alchemist: %s (%d Gold)" % [_effect_names[_effect_index], _effect_costs[_effect_index]]
		)
	else:
		alch_btn.text = "Not enough Gold!"
		var tw: Tween = create_tween()
		tw.tween_interval(1.0)
		tw.tween_callback(func():
			alch_btn.text = "[E] Alchemist: %s (%d Gold)" % [_effect_names[_effect_index], _effect_costs[_effect_index]]
		)


func _interact_smuggler() -> void:
	const COST: int = 25
	if GameManager.gold >= COST:
		GameManager.spend_gold(COST)
		var rewards: Array[String] = [
			"res://src/data/items/weapons/flame_sword.tres",
			"res://src/data/items/weapons/crystal_staff.tres",
			"res://src/data/items/weapons/short_bow.tres",
			"res://src/data/items/buffs/ruby_ring.tres",
			"res://src/data/items/buffs/crystal_pendant.tres",
			"res://src/data/items/buffs/iron_shield.tres"
		]
		var pick_path: String = rewards[randi() % rewards.size()]
		var item: ItemData = load(pick_path) as ItemData
		if item != null:
			if item.type == ItemData.ItemType.WEAPON:
				if GameManager.equipped_weapons.size() < 6:
					GameManager.add_weapon(item)
				else:
					GameManager.remove_weapon_at(0)
					GameManager.add_weapon(item)
			else:
				GameManager.add_passive(item)

		smug_btn.text = "Acquired: %s!" % (item.item_name if item != null else "Item")
		var tw: Tween = create_tween()
		tw.tween_interval(1.8)
		tw.tween_callback(func(): smug_btn.text = "[E] Smuggler: Mua Rare Item (25 Gold)")
	else:
		smug_btn.text = "Not enough Gold!"
		var tw: Tween = create_tween()
		tw.tween_interval(1.0)
		tw.tween_callback(func(): smug_btn.text = "[E] Smuggler: Mua Rare Item (25 Gold)")


func _interact_portal() -> void:
	portal_entered.emit()
