extends Node2D

@export var worker_scene: PackedScene
@export var min_workers: int = 5  # Keep this for initial spawn

var current_workers: Array = []
var settlement_ref: Node = null

func setup_for_settlement(settlement: Node):
	"""Connect this spawner to a settlement"""
	settlement_ref = settlement
	
	# Spawn initial workers
	for i in range(min_workers):
		spawn_worker()
	
	print("Spawner connected to settlement")

func spawn_worker() -> Node:
	if not worker_scene or not settlement_ref:
		return null
	
	# Check if settlement has capacity
	if settlement_ref.has_method("can_add_worker"):
		if not settlement_ref.can_add_worker():
			print("Settlement at max capacity")
			return null
	
	var worker = worker_scene.instantiate()
	
	# Add to settlement's worker container
	var container = settlement_ref.get_node("WorkerContainer")
	container.add_child(worker)
	
	# Get spawn position from settlement's spawn zone
	worker.global_position = get_spawn_position_from_settlement()
	
	# Setup worker
	if worker.has_method("set_home_settlement"):
		worker.set_home_settlement(settlement_ref)
	
	current_workers.append(worker)
	
	print("Spawned worker at: ", worker.global_position)
	return worker

func get_spawn_position_from_settlement() -> Vector2:
	if not settlement_ref:
		return Vector2.ZERO
	
	# Method 1: Settlement provides position
	if settlement_ref.has_method("get_spawn_position"):
		return settlement_ref.get_spawn_position()
	
	# Method 2: Direct access to spawn zone
	var spawn_zone = settlement_ref.get_node("SpawnZone")
	if spawn_zone:
		var shape = spawn_zone.get_node("CollisionShape2D").shape
		if shape is CircleShape2D:
			var radius = shape.radius
			var angle = randf() * TAU
			var distance = randf_range(radius * 0.3, radius)
			var local_pos = Vector2(cos(angle), sin(angle)) * distance
			return settlement_ref.global_position + local_pos
	
	# Fallback
	return settlement_ref.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))

# Remove workers if needed
func remove_worker(worker: Node):
	if worker in current_workers:
		current_workers.erase(worker)
		worker.queue_free()

func clear_all_workers():
	for worker in current_workers:
		worker.queue_free()
	current_workers.clear()
