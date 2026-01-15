extends CanvasLayer

@onready var label := $Label

func _ready():
	ResourceManager.resource_changed.connect(_on_resource_changed)
	_on_resource_changed(ResourceManager.resource)

func _on_resource_changed(amount):
	label.text = "Gold: %d" % amount
