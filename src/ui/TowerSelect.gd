class_name TowerSelect
extends Control
## 2-Step Expedition Selection screen (640x360 resolution):
## Step 1: Choose Spire (Blightwood / Catacomb / Cinderforge)
## Step 2: Choose Hero Class via direct interactive Hero Card buttons

# Step Containers
@onready var tower_step: VBoxContainer = $Margin/VBox/TowerStep
@onready var class_step: VBoxContainer = $Margin/VBox/ClassStep

# Step 1: Tower Selection references
@onready var tower_card_0: Button = $Margin/VBox/TowerStep/TowerCards/Tower0
@onready var tower_card_1: Button = $Margin/VBox/TowerStep/TowerCards/Tower1
@onready var tower_card_2: Button = $Margin/VBox/TowerStep/TowerCards/Tower2
@onready var tower_back_btn: Button = $Margin/VBox/TowerStep/NavFooter/BackToMenuButton
@onready var to_class_btn: Button = $Margin/VBox/TowerStep/NavFooter/ToClassButton

# Step 2: Class Selection references
@onready var chosen_tower_badge: Label = $Margin/VBox/ClassStep/Header/TowerBadge
@onready var class_card_0: Button = $Margin/VBox/ClassStep/ClassCards/Class0
@onready var class_card_1: Button = $Margin/VBox/ClassStep/ClassCards/Class1
@onready var class_card_2: Button = $Margin/VBox/ClassStep/ClassCards/Class2
@onready var class_back_btn: Button = $Margin/VBox/ClassStep/NavFooter/BackToTowerButton
@onready var embark_button: Button = $Margin/VBox/ClassStep/NavFooter/EmbarkButton

var towers: Array[TowerData] = []
var classes: Array[ClassData] = []

var selected_tower_index: int = 0
var selected_class_index: int = 0

var _rogues_tex: Texture2D = preload("res://assets/sprites/rogues.png")


func _ready() -> void:
	_load_data()
	_connect_buttons()
	_setup_class_sprites()
	_show_step_1_tower()
	_update_tower_ui()
	_update_class_ui()


func _load_data() -> void:
	towers = [
		load("res://src/data/towers/blightwood_spire.tres") as TowerData,
		load("res://src/data/towers/catacomb_spire.tres") as TowerData,
		load("res://src/data/towers/cinderforge_spire.tres") as TowerData,
	]
	classes = [
		load("res://src/data/classes/knight.tres") as ClassData,
		load("res://src/data/classes/ranger.tres") as ClassData,
		load("res://src/data/classes/wizard.tres") as ClassData,
	]


func _connect_buttons() -> void:
	# Step 1
	tower_card_0.pressed.connect(func(): _select_tower(0))
	tower_card_1.pressed.connect(func(): _select_tower(1))
	tower_card_2.pressed.connect(func(): _select_tower(2))
	tower_back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://src/ui/MainMenu.tscn"))
	to_class_btn.pressed.connect(_show_step_2_class)

	# Step 2
	class_card_0.pressed.connect(func(): _select_class(0))
	class_card_1.pressed.connect(func(): _select_class(1))
	class_card_2.pressed.connect(func(): _select_class(2))
	class_back_btn.pressed.connect(_show_step_1_tower)
	embark_button.pressed.connect(_on_embark_pressed)


func _setup_class_sprites() -> void:
	var sprite_paths: Array[NodePath] = [
		NodePath("Margin/VBox/ClassStep/ClassCards/Class0/Margin/VBox/SpriteCenter/HeroSprite"),
		NodePath("Margin/VBox/ClassStep/ClassCards/Class1/Margin/VBox/SpriteCenter/HeroSprite"),
		NodePath("Margin/VBox/ClassStep/ClassCards/Class2/Margin/VBox/SpriteCenter/HeroSprite"),
	]
	for i: int in range(mini(classes.size(), sprite_paths.size())):
		var spr: TextureRect = get_node_or_null(sprite_paths[i]) as TextureRect
		if spr != null and classes[i] != null:
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = _rogues_tex
			atlas.region = classes[i].sprite_region
			spr.texture = atlas


func _show_step_1_tower() -> void:
	tower_step.visible = true
	class_step.visible = false
	_update_tower_ui()


func _show_step_2_class() -> void:
	tower_step.visible = false
	class_step.visible = true
	var t: TowerData = towers[selected_tower_index]
	chosen_tower_badge.text = "THÁP ĐÃ CHỌN: %s" % t.tower_name.to_upper()
	_update_class_ui()


func _select_tower(idx: int) -> void:
	selected_tower_index = idx
	_update_tower_ui()


func _select_class(idx: int) -> void:
	selected_class_index = idx
	_update_class_ui()


func _update_tower_ui() -> void:
	var tower_cards: Array[Button] = [tower_card_0, tower_card_1, tower_card_2]
	for i: int in range(tower_cards.size()):
		if i == selected_tower_index:
			tower_cards[i].modulate = Color(1.3, 1.25, 0.6, 1.0)
		else:
			tower_cards[i].modulate = Color(0.7, 0.7, 0.7, 0.9)


func _update_class_ui() -> void:
	var class_cards: Array[Button] = [class_card_0, class_card_1, class_card_2]
	for i: int in range(class_cards.size()):
		if i == selected_class_index:
			class_cards[i].modulate = Color(1.3, 1.25, 0.6, 1.0)
		else:
			class_cards[i].modulate = Color(0.7, 0.7, 0.7, 0.9)


func _on_embark_pressed() -> void:
	var tower: TowerData = towers[selected_tower_index]
	var character_class: ClassData = classes[selected_class_index]

	# Generate 100 floors dynamically (Floor 100 is Final Boss, Floor 99 Sanctuary, Bosses every 3-5 floors)
	var floors: Array[FloorConfig] = FloorConfig.generate_100_floors()

	GameManager.start_new_run(tower, floors, character_class)
	SaveManager.save_run()
	get_tree().change_scene_to_file("res://src/arena/Arena.tscn")
