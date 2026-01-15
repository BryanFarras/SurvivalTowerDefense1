# Worker.gd - simplified version
extends CharacterBody2D

@export var move_speed: float = 80.0
@export var worker_color: Color = Color.WHITE

var worker_name: String = "Worker"
var worker_id: int = -1
var is_idle: bool = true
var home_settlement: Node = null
var target_position: Vector2 = Vector2.ZERO

@onready var sprite = $AnimatedSprite2D

func _ready():
	# Random appearance
	# worker_color = Color.from_hsv(randf(), 0.6, 0.9)
	# sprite.modulate = worker_color
	# 
	# # Set random scale
	# sprite.scale = Vector2.ONE * randf_range(0.9, 1.1)
	
	# Start idle
	return_home()

func set_home_settlement(settlement: Node):
	home_settlement = settlement
	return_home()

func return_home():
	is_idle = true
	if home_settlement and home_settlement.has_method("get_random_spawn_position"):
		target_position = home_settlement.global_position + home_settlement.get_random_spawn_position()
	else:
		# Wander randomly
		target_position = global_position + Vector2(
			randf_range(-100, 100),
			randf_range(-100, 100)
		)

func _process(delta):
	# Move toward target
	if global_position.distance_to(target_position) > 5:
		var direction = (target_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		
		# Flip sprite based on direction
		if abs(direction.x) > 0.1:
			sprite.flip_h = direction.x < 0
	else:
		velocity = Vector2.ZERO
		# Find new target if idle
		if is_idle:
			return_home()
