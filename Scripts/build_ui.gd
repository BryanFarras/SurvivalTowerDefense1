extends CanvasLayer

@export var build_manager: BuildManager
@onready var remove_button: Button = $Panel/RemoveButton

func _ready():
	remove_button.disabled = true
	build_manager.tower_selected.connect(_on_tower_selected)
	build_manager.tower_deselected.connect(_on_tower_deselected)
	$Panel/HBoxContainer/Button.pressed.connect(
		func(): build_manager.select_tower(0)
	)

	$Panel/HBoxContainer/Button2.pressed.connect(
		func(): build_manager.select_tower(1)
	)

func _on_tower_selected(tower):
	remove_button.disabled = false

func _on_tower_deselected():
	remove_button.disabled = true

func _on_remove_button_pressed() -> void:
	build_manager.remove_selected_tower()
