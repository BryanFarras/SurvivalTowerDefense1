extends Node2D
class_name Tower

@export_group("stats")
@export var cost := 20
@export var damage := 10
@export var range := 120.0
@export var attack_speed := 1.0
@export var rotation_speed := 6.0
@export_group("references")
@export var projectile_scene: PackedScene

var enemies_in_range: Array = []
var current_target: Node = null
var can_be_selected := false
var placed_cell: Vector2i

@onready var range_area: Area2D = $Range
@onready var fire_timer: Timer = $FireTimer
@onready var turret: Node2D = $Turret
@onready var muzzle: Marker2D = $Turret/Muzzle
@onready var collision_shape_2d: CollisionShape2D = $Range/CollisionShape2D
@onready var range_preview: Sprite2D = $Range/RangePreview

signal selected(tower: Tower)
signal deselected()

func _on_click_area_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if !can_be_selected:
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("selected", self)

func _ready():
	fire_timer.wait_time = attack_speed
	fire_timer.timeout.connect(_on_fire_timer_timeout)

	range_area.body_entered.connect(_on_body_entered)
	range_area.body_exited.connect(_on_body_exited)

	var shape = collision_shape_2d.shape
	shape.radius = range
	
	var range_scale = range / 300.0
	range_preview.scale = Vector2(range_scale, range_scale)
	
	await get_tree().process_frame
	can_be_selected = true

func _process(delta):
	if current_target == null or !is_instance_valid(current_target):
		return

	turret.look_at(current_target.global_position)

func _select_new_target():
	if enemies_in_range.size() > 0:
		current_target = enemies_in_range[0]
		fire_timer.start()

func _fire_projectile(target):
	var projectile = projectile_scene.instantiate()
	projectile.global_position = muzzle.global_position
	projectile.target = target
	projectile.damage = damage
	get_tree().current_scene.add_child(projectile)

func set_selected(is_selected: bool):
	range_preview.visible = is_selected

func _on_body_entered(body):
	if body.is_in_group("enemy"):
		enemies_in_range.append(body)
		if current_target == null:
			current_target = body
			fire_timer.start()

func _on_body_exited(body):
	if body.is_in_group("enemy"):
		enemies_in_range.erase(body)
		if body == current_target:
			current_target = null
			fire_timer.stop()
			_select_new_target()

func _on_fire_timer_timeout():
	if current_target == null or !is_instance_valid(current_target):
		_select_new_target()
		return

	_fire_projectile(current_target)
