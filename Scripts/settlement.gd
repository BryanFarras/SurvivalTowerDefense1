# Settlement.gd - Optimized version
extends Node2D

class_name Settlement

@export var worker_scene: PackedScene
@export var start_with_workers: int = 2
@export var max_workers: int = 5
@export var upgrade_cost: int = 100

var workers: Array = []
var current_upgrade_level: int = 0
var is_selected: bool = false

signal settlement_selected(settlement)
signal worker_spawned(worker)
signal settlement_upgraded(level)

func _ready():
	# Auto-setup spawn zone if not configured
	setup_spawn_zone()
	
	# Spawn initial workers
	spawn_initial_workers()
	
	update_ui()

func setup_spawn_zone():
	# Ensure SpawnZone has a shape
	var spawn_zone = $SpawnZone
	var collision_shape = spawn_zone.get_node("CollisionShape2D")
	
	if collision_shape.shape == null:
		var circle = CircleShape2D.new()
		circle.radius = 120.0  # Default radius
		collision_shape.shape = circle
		print("Created default spawn zone with radius: ", circle.radius)

func spawn_initial_workers():
	for i in range(min(start_with_workers, max_workers)):
		await get_tree().create_timer(i * 0.3).timeout
		spawn_worker()

func spawn_worker() -> Node:
	if not can_add_worker() or not worker_scene:
		return null
	
	var worker = worker_scene.instantiate()
	$WorkerContainer.add_child(worker)
	
	# Position within spawn zone
	worker.global_position = get_spawn_position_in_zone()
	
	# Initialize worker
	if worker.has_method("initialize"):
		worker.initialize(self, workers.size())
	
	workers.append(worker)
	worker_spawned.emit(worker)
	update_ui()
	
	return worker

func get_spawn_position_in_zone() -> Vector2:
	var spawn_zone = $SpawnZone
	var shape = spawn_zone.get_node("CollisionShape2D").shape
	
	if shape is CircleShape2D:
		var radius = shape.radius
		# Random point in circle (avoid center)
		var angle = randf() * TAU
		var distance = randf_range(radius * 0.3, radius)
		return global_position + Vector2(cos(angle), sin(angle)) * distance
	
	return global_position

func can_add_worker() -> bool:
	return workers.size() < max_workers

func get_worker_count() -> int:
	return workers.size()

func get_idle_worker():
	for worker in workers:
		if worker.has_method("is_idle") and worker.is_idle:
			return worker
	return null

func upgrade():
	if current_upgrade_level >= 3:  # Max 3 upgrades
		return false
	
	current_upgrade_level += 1
	max_workers += 5  # Each upgrade adds 5 more workers
	
	# Visual feedback
	$Sprite2D.modulate = Color.GOLD
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 1.0)
	
	print("Settlement upgraded! New capacity: ", max_workers)
	settlement_upgraded.emit(current_upgrade_level)
	update_ui()
	
	return true

func update_ui():
	if has_node("WorkerCount"):
		$WorkerCount.text = str(workers.size()) + "/" + str(max_workers)

# Selection
func select():
	is_selected = true
	# Visual feedback
	$Sprite2D.material = ShaderMaterial.new()  # Add outline shader here
	settlement_selected.emit(self)

func deselect():
	is_selected = false
	$Sprite2D.material = null

func _on_static_body_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			select()
		elif event.button_index == MOUSE_BUTTON_RIGHT and can_add_worker():
			spawn_worker()
