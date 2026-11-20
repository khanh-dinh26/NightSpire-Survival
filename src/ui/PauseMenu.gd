class_name PauseMenu
extends CanvasLayer
## In-game Pause Menu: toggles with ESC, pauses game tree, options to resume or abandon run.

@onready var resume_btn: Button = $Panel/Margin/VBox/ResumeButton
@onready var sound_btn: Button = $Panel/Margin/VBox/SoundButton
@onready var menu_btn: Button = $Panel/Margin/VBox/MenuButton
@onready var quit_btn: Button = $Panel/Margin/VBox/QuitButton
@onready var sound_modal: SoundSettings = $SoundSettingsModal


func _ready() -> void:
	visible = false
	resume_btn.pressed.connect(resume_game)
	sound_btn.pressed.connect(func():
		AudioManager.play_sfx("confirm")
		sound_modal.open()
	)
	menu_btn.pressed.connect(_on_menu_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# If any shop or draft is currently active, don't interfere
		for shop: Node in get_tree().get_nodes_in_group(&"shop_ui"):
			if shop is CanvasItem and shop.visible:
				return
		if get_tree().get_first_node_in_group(&"draft_ui") != null:
			var draft: Node = get_tree().get_first_node_in_group(&"draft_ui")
			if draft is CanvasItem and draft.visible:
				return

		if sound_modal != null and sound_modal.visible:
			sound_modal.visible = false
			get_viewport().set_input_as_handled()
			return

		if visible:
			resume_game()
		else:
			pause_game()
		get_viewport().set_input_as_handled()


func pause_game() -> void:
	AudioManager.play_sfx("pause")
	get_tree().paused = true
	visible = true


func resume_game() -> void:
	AudioManager.play_sfx("unpause")
	get_tree().paused = false
	visible = false
	if sound_modal != null:
		sound_modal.visible = false


func _on_menu_pressed() -> void:
	get_tree().paused = false
	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://src/ui/TowerSelect.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
