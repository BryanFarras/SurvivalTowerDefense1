extends Node

@export var starting_resource := 100

var resource: int = 0

signal resource_changed(current_amount: int)

func _ready():
	resource = starting_resource
	emit_signal("resource_changed", resource)

func add(amount: int):
	resource += amount
	emit_signal("resource_changed", resource)

func spend(amount: int) -> bool:
	if !can_afford(amount):
		return false

	resource -= amount
	emit_signal("resource_changed", resource)
	return true

func can_afford(amount: int) -> bool:
	return resource >= amount