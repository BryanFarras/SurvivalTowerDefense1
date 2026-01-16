extends Node2D
class_name BuildManager

@export var tower_scenes: Array[PackedScene]
@export var tilemap: TileMapLayer
@export var occupy_tilemap: TileMapLayer

var selected_tower_index := -1
var preview_instance: Node2D = null
var build_mode := false
var current_cell: Vector2i
var selected_tower: Tower = null

signal tower_selected(tower)
signal tower_deselected()

func _unhandled_input(event):
	if !build_mode:
		return
	
	if event.is_action_pressed("ui_cancel"):
		cancel_build()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_cell_buildable(current_cell):
			place_tower(current_cell)
			cancel_build()

func _process(delta):
	if !build_mode or preview_instance == null:
		return

	var mouse_pos = get_global_mouse_position()
	current_cell = tilemap.local_to_map(mouse_pos)
	var cell_pos = tilemap.map_to_local(current_cell)

	preview_instance.global_position = cell_pos

	var valid = is_cell_buildable(current_cell)
	_set_preview_valid(valid)

func enter_build_mode():
	build_mode = true

func exit_build_mode():
	build_mode = false

func cancel_build():
	exit_build_mode()
	selected_tower_index = -1

	if preview_instance:
		preview_instance.queue_free()
		preview_instance = null

func select_tower(index: int):
	enter_build_mode()
	selected_tower_index = index
	_create_preview()

func _create_preview():
	if preview_instance:
		preview_instance.queue_free()

	var scene = tower_scenes[selected_tower_index]
	preview_instance = scene.instantiate()

	# Disable logic
	preview_instance.process_mode = Node.PROCESS_MODE_DISABLED

	add_child(preview_instance)

func place_tower(cell: Vector2i):
	if selected_tower_index == -1:
		return

	var scene = tower_scenes[selected_tower_index]
	var tower = scene.instantiate()

	if !ResourceManager.can_afford(tower.cost):
		tower.queue_free()
		cancel_build()
		return

	ResourceManager.spend(tower.cost)

	tower.placed_cell = cell
	tower.global_position = tilemap.map_to_local(cell)
	tower.selected.connect(select_existing_tower)
	get_tree().current_scene.add_child(tower)
	tower.set_selected(false)

	occupy_tilemap.set_cell(cell, 1, Vector2i(3,0))

func select_existing_tower(tower: Tower):
	cancel_build()
	if selected_tower == tower:
		selected_tower.set_selected(false)
		selected_tower = null
		return

	_clear_selection()
	selected_tower = tower
	selected_tower.set_selected(true)
	emit_signal("tower_selected", tower)

func _clear_selection():
	if selected_tower != null:
		selected_tower.set_selected(false)
	selected_tower = null

func remove_selected_tower():
	if selected_tower == null:
		return

	# Free occupied tile
	occupy_tilemap.set_cell(selected_tower.placed_cell, -1)
	
	# Optional refund
	var refund := int(selected_tower.cost * 0.5)
	ResourceManager.add(refund)

	selected_tower.queue_free()
	selected_tower = null
	emit_signal("tower_deselected")

func is_cell_buildable(cell: Vector2i) -> bool:
	var tile_data = tilemap.get_cell_tile_data(cell)
	
	if tile_data == null:
		return false

	if tile_data.get_custom_data("buildable") != true:
		return false

	# Check occupied layer
	return occupy_tilemap.get_cell_source_id(cell) == -1

func _set_preview_valid(valid: bool):
	var color = Color(0, 1, 0) if valid else Color(1, 0, 0)
	_apply_modulate(preview_instance, color)

func _apply_modulate(node: Node, color: Color):
	if node is CanvasItem:
		node.modulate = color

	for child in node.get_children():
		_apply_modulate(child, color)
