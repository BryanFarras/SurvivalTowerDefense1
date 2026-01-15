extends CharacterBody2D

# ini cuma kode placeholder buat gw gerak di gamenya doang
# jangan pake kode ini buat enemy

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@export var health = 100
@onready var build_manager: Node2D = $"../BuildManager"

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		build_manager.enter_build_mode()

	var direction_vertical := Input.get_axis("ui_up", "ui_down")
	var direction_horizontal := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction_horizontal * SPEED
	velocity.y = direction_vertical * SPEED


	move_and_slide()

func take_damage(amount):
	health -= amount
	print(health)
	if health <= 0:
		queue_free()
