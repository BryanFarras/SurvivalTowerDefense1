extends Area2D
class_name Projectile

@export var speed: float = 300.0
@export var damage: int = 10

var target: Node2D

func _ready():
	body_entered.connect(_on_body_entered)

func _process(delta):
	if target == null or !is_instance_valid(target):
		queue_free()
		return

	var direction = (target.global_position - global_position).normalized()
	global_position += direction * speed * delta
	rotation = direction.angle()

func _on_body_entered(body):
	if body == target:
		body.take_damage(damage)
	
	queue_free()
