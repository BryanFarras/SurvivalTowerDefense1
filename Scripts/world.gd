# World.gd - WITH LEFT MOUSE DRAG PANNING ADDED
extends Node2D

@export var settlement_scene: PackedScene
@export var worker_scene: PackedScene

# ============================================
# DEBUG CONTROLS (Inspector Toggles)
# ============================================
@export_category("Debug Controls")
@export var debug_controls_enabled: bool = false
@export var enable_panning: bool = true
@export var enable_zoom: bool = true
@export var debug_mode: bool = true
@export var show_spawn_zones: bool = true
@export var left_mouse_drag_pan: bool = true  # NEW: Toggle for left mouse drag

# Camera panning variables
var is_panning_camera: bool = false
var pan_start_position: Vector2 = Vector2.ZERO
var camera_start_position: Vector2 = Vector2.ZERO

# NEW: Left mouse drag variables
var is_left_mouse_dragging: bool = false
var left_drag_start_position: Vector2 = Vector2.ZERO
var left_drag_camera_start: Vector2 = Vector2.ZERO

# Freeform panning variables
var freeform_pan_speed: float = 800.0
var freeform_pan_direction: Vector2 = Vector2.ZERO
var is_freeform_panning: bool = false

# Camera zoom
var camera_zoom_level: float = 1.0
var min_zoom: float = 0.3
var max_zoom: float = 3.0
var zoom_speed: float = 0.1

# Cursor edge panning
var edge_pan_enabled: bool = true
var edge_pan_margin: float = 50.0
var edge_pan_speed: float = 600.0

# Game variables
var settlements: Array = []
var selected_settlement: Node = null
var resources: int = 1000
@export var test_spawn_radius: float = 120.0

func _ready():
	print("=== WORLD INITIALIZED ===")
	print("Panning enabled: ", enable_panning)
	print("Left Mouse Drag: ", left_mouse_drag_pan)
	print("Zoom enabled: ", enable_zoom)
	print("Debug mode: ", debug_mode)
	
	# Setup camera
	$Camera2D.make_current()
	camera_start_position = $Camera2D.position
	
	# Get or create first settlement
	var first_settlement = get_node_or_null("Settlement")
	if first_settlement:
		setup_settlement(first_settlement)
	else:
		spawn_settlement(Vector2(400, 300))
	
	# Setup input
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func setup_settlement(settlement: Node):
	settlement.worker_scene = worker_scene
	
	if settlement.has_signal("settlement_selected"):
		settlement.settlement_selected.connect(_on_settlement_selected)
	
	if settlement.has_signal("worker_spawned"):
		settlement.worker_spawned.connect(_on_worker_spawned)
	
	settlements.append(settlement)
	
	# Test: Adjust spawn zone size if needed
	if debug_mode and settlement.has_node("SpawnZone"):
		var spawn_zone = settlement.get_node("SpawnZone")
		var shape = spawn_zone.get_node("CollisionShape2D").shape
		if shape is CircleShape2D:
			shape.radius = test_spawn_radius
			print("Set spawn radius to: ", shape.radius)

func spawn_settlement(position: Vector2) -> Node:
	if not settlement_scene:
		push_error("No settlement scene assigned!")
		return null
	
	var settlement = settlement_scene.instantiate()
	add_child(settlement)
	settlement.position = position
	settlement.name = "Settlement_" + str(settlements.size() + 1)
	
	setup_settlement(settlement)
	
	return settlement

func _on_settlement_selected(settlement: Node):
	print("World: Settlement selected")
	selected_settlement = settlement
	$Camera2D.position = settlement.position

func _on_worker_spawned(worker: Node):
	print("World: New worker spawned at ", worker.position)

# ============================================
# CAMERA INPUT HANDLING WITH TOGGLE
# ============================================

func is_over_interactable(position: Vector2) -> bool:
	for settlement in settlements:
		if settlement.position.distance_to(position) < 100:
			return true
	return false

func _unhandled_input(event):
	# Handle camera input if enabled
	if enable_panning:
		handle_camera_input(event)
	
	# Always handle game input
	handle_game_input(event)

func handle_camera_input(event):
	# ===== MIDDLE MOUSE DRAG PAN =====
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				# Start middle mouse pan
				is_panning_camera = true
				pan_start_position = get_global_mouse_position()
				camera_start_position = $Camera2D.position
			else:
				# Stop panning
				is_panning_camera = false
		
		# ===== RIGHT MOUSE FREEFORM PAN =====
		elif event.button_index == MOUSE_BUTTON_RIGHT and not Input.is_key_pressed(KEY_SHIFT):
			if event.pressed:
				# Start freeform panning
				is_freeform_panning = true
			else:
				# Stop freeform panning
				is_freeform_panning = false
				freeform_pan_direction = Vector2.ZERO
		
		# ===== LEFT MOUSE DRAG PAN (NEW) =====
		elif event.button_index == MOUSE_BUTTON_LEFT and left_mouse_drag_pan:
			if event.pressed:
				var mouse_pos = get_global_mouse_position()
				# Only start left drag if NOT over an interactable
				if not is_over_interactable(mouse_pos):
					is_left_mouse_dragging = true
					left_drag_start_position = mouse_pos
					left_drag_camera_start = $Camera2D.position
					# Don't try to select settlements while dragging
					get_viewport().set_input_as_handled()
			else:
				# Stop left mouse dragging
				is_left_mouse_dragging = false
		
		# ===== MOUSE WHEEL ZOOM =====
		elif enable_zoom:
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				# Zoom in toward cursor
				zoom_toward_cursor(-zoom_speed)
			
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				# Zoom out from cursor
				zoom_toward_cursor(zoom_speed)
		
		# ===== MIDDLE CLICK RESET =====
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.double_click:
			reset_camera()
	
	# ===== MIDDLE MOUSE DRAG =====
	elif event is InputEventMouseMotion and is_panning_camera:
		var current_mouse_pos = get_global_mouse_position()
		var pan_delta = pan_start_position - current_mouse_pos
		$Camera2D.position = camera_start_position + pan_delta
	
	# ===== LEFT MOUSE DRAG (NEW) =====
	elif event is InputEventMouseMotion and is_left_mouse_dragging:
		var current_mouse_pos = get_global_mouse_position()
		var drag_delta = left_drag_start_position - current_mouse_pos
		$Camera2D.position = left_drag_camera_start + drag_delta
	
	# ===== RIGHT MOUSE FREEFORM DIRECTION =====
	elif event is InputEventMouseMotion and is_freeform_panning:
		update_freeform_pan_direction()

func zoom_toward_cursor(zoom_change: float):
	if not enable_zoom:
		return
	
	var old_zoom = camera_zoom_level
	camera_zoom_level = clamp(camera_zoom_level + zoom_change, min_zoom, max_zoom)
	
	if camera_zoom_level != old_zoom:
		var viewport = get_viewport()
		var mouse_pos = viewport.get_mouse_position()
		var camera_pos = $Camera2D.position
		
		var cursor_world_before = camera_pos + (mouse_pos - viewport.size * 0.5) / old_zoom
		
		$Camera2D.zoom = Vector2(camera_zoom_level, camera_zoom_level)
		
		var cursor_world_after = camera_pos + (mouse_pos - viewport.size * 0.5) / camera_zoom_level
		var zoom_offset = cursor_world_after - cursor_world_before
		
		$Camera2D.position -= zoom_offset

func update_freeform_pan_direction():
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	var viewport_center = viewport.size * 0.5
	
	var direction = (mouse_pos - viewport_center).normalized()
	var distance = mouse_pos.distance_to(viewport_center) / (viewport.size.x * 0.5)
	
	var speed_multiplier = clamp(distance, 0.1, 1.0)
	freeform_pan_direction = direction * speed_multiplier

func handle_game_input(event):
	# Place new settlement with Shift + Right Click
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT and Input.is_key_pressed(KEY_SHIFT):
			spawn_settlement(get_global_mouse_position())
		
		# Select settlement with Left Click (only if not dragging)
		elif event.button_index == MOUSE_BUTTON_LEFT and not is_left_mouse_dragging:
			# Small delay to check if this is the start of a drag
			await get_tree().create_timer(0.05).timeout
			if not is_left_mouse_dragging:
				try_select_settlement(get_global_mouse_position())
	
	# Global keyboard controls
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				for settlement in settlements:
					if settlement.has_method("spawn_worker"):
						settlement.spawn_worker()
			
			KEY_S:
				var pos = Vector2(
					randf_range(100, 700),
					randf_range(100, 500)
				)
				spawn_settlement(pos)
			
			KEY_U:
				if selected_settlement and selected_settlement.has_method("upgrade"):
					if resources >= 100:
						resources -= 100
						selected_settlement.upgrade()
			
			KEY_C:
				if selected_settlement:
					$Camera2D.position = selected_settlement.position
			
			KEY_R:
				reset_camera()
			
			KEY_F:
				for settlement in settlements:
					while settlement.has_method("can_add_worker") and settlement.can_add_worker():
						if settlement.has_method("spawn_worker"):
							settlement.spawn_worker()
			
			KEY_D:
				debug_mode = !debug_mode
				print("Debug mode: ", debug_mode)
			
			KEY_P:
				# Toggle panning while game is running
				enable_panning = !enable_panning
				print("Panning: ", "ENABLED" if enable_panning else "DISABLED")
			
			KEY_Z:
				# Toggle zoom while game is running
				enable_zoom = !enable_zoom
				print("Zoom: ", "ENABLED" if enable_zoom else "DISABLED")
			
			KEY_L:
				# NEW: Toggle left mouse drag panning
				left_mouse_drag_pan = !left_mouse_drag_pan
				print("Left Mouse Drag: ", "ENABLED" if left_mouse_drag_pan else "DISABLED")
			
			KEY_EQUAL or KEY_PLUS:
				zoom_toward_cursor(-zoom_speed)
			
			KEY_MINUS:
				zoom_toward_cursor(zoom_speed)

func reset_camera():
	$Camera2D.position = Vector2.ZERO
	camera_zoom_level = 1.0
	$Camera2D.zoom = Vector2.ONE
	print("Camera reset")

func try_select_settlement(position: Vector2):
	for settlement in settlements:
		if settlement.position.distance_to(position) < 100:
			if settlement.has_method("select"):
				settlement.select()
			break

# ============================================
# PROCESS UPDATES
# ============================================

func _process(delta):
	# Handle freeform panning if enabled
	if enable_panning and is_freeform_panning and freeform_pan_direction.length() > 0:
		var pan_speed = freeform_pan_speed * delta
		$Camera2D.position += freeform_pan_direction * pan_speed
	
	# Handle edge panning if enabled
	if enable_panning and edge_pan_enabled and not is_panning_camera and not is_freeform_panning and not is_left_mouse_dragging:
		edge_pan_camera(delta)
	
	# Debug drawing
	if debug_mode:
		queue_redraw()

func edge_pan_camera(delta):
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	var viewport_size = viewport.size
	
	var edge_left = 1.0 - clamp(mouse_pos.x / edge_pan_margin, 0.0, 1.0)
	var edge_right = clamp((mouse_pos.x - (viewport_size.x - edge_pan_margin)) / edge_pan_margin, 0.0, 1.0)
	var edge_top = 1.0 - clamp(mouse_pos.y / edge_pan_margin, 0.0, 1.0)
	var edge_bottom = clamp((mouse_pos.y - (viewport_size.y - edge_pan_margin)) / edge_pan_margin, 0.0, 1.0)
	
	var pan_vector = Vector2(
		edge_right - edge_left,
		edge_bottom - edge_top
	)
	
	if pan_vector.length() > 0:
		var speed = edge_pan_speed * delta * (1.0 / camera_zoom_level)
		$Camera2D.position += pan_vector.normalized() * speed

# ============================================
# DEBUG DRAWING
# ============================================

func _draw():
	if debug_mode:
		var viewport = get_viewport()
		var viewport_size = viewport.size
		var mouse_pos = viewport.get_mouse_position()
		var cursor_world_pos = get_global_mouse_position()
		
		# Draw spawn zones if enabled
		if show_spawn_zones:
			for settlement in settlements:
				if settlement.has_node("SpawnZone"):
					var spawn_zone = settlement.get_node("SpawnZone")
					var shape = spawn_zone.get_node("CollisionShape2D").shape
					if shape is CircleShape2D:
						draw_circle(settlement.position - position, shape.radius, Color(0, 1, 0, 0.1))
		
		# Draw edge pan margins
		if edge_pan_enabled and enable_panning:
			draw_rect(Rect2(0, 0, edge_pan_margin, viewport_size.y), Color(1, 0, 0, 0.1))
			draw_rect(Rect2(viewport_size.x - edge_pan_margin, 0, edge_pan_margin, viewport_size.y), Color(1, 0, 0, 0.1))
			draw_rect(Rect2(0, 0, viewport_size.x, edge_pan_margin), Color(1, 0, 0, 0.1))
			draw_rect(Rect2(0, viewport_size.y - edge_pan_margin, viewport_size.x, edge_pan_margin), Color(1, 0, 0, 0.1))
		
		# Draw cursor
		draw_circle(cursor_world_pos - position, 5, Color.YELLOW)
		
		# Draw pan direction indicator
		if enable_panning and is_freeform_panning and freeform_pan_direction.length() > 0:
			var direction_end = cursor_world_pos + freeform_pan_direction * 50
			draw_line(cursor_world_pos - position, direction_end - position, Color.CYAN, 2)
		
		# Draw left drag indicator
		if is_left_mouse_dragging:
			draw_circle(cursor_world_pos - position, 8, Color(1, 0.5, 0, 0.5))  # Orange circle
			draw_line(left_drag_start_position - position, cursor_world_pos - position, Color.ORANGE, 3)
		
		# Draw debug info panel
		show_debug_info()

func show_debug_info():
	if debug_controls_enabled == true:
		draw_debug_info()

func draw_debug_info():
	var info = "=== DEBUG INFO ===\n"
	info += "Camera: " + str($Camera2D.position.round()) + "\n"
	info += "Zoom: " + str(camera_zoom_level) + "x\n"
	info += "Cursor: " + str(get_global_mouse_position().round()) + "\n"
	info += "Settlements: " + str(settlements.size()) + "\n"
	
	# Status indicators
	info += "\n=== STATUS ===\n"
	info += "Panning: " + ("✅ ON" if enable_panning else "❌ OFF") + "\n"
	info += "Left Drag: " + ("✅ ON" if left_mouse_drag_pan else "❌ OFF") + "\n"
	info += "Zoom: " + ("✅ ON" if enable_zoom else "❌ OFF") + "\n"
	info += "Debug: " + ("✅ ON" if debug_mode else "❌ OFF") + "\n"
	info += "Edge Pan: " + ("✅ ON" if edge_pan_enabled else "❌ OFF") + "\n"
	
	# Active states
	if is_left_mouse_dragging:
		info += "Left Drag: 🖱️ ACTIVE\n"
	if is_freeform_panning:
		info += "Freeform Panning: 🎯 ACTIVE\n"
	if is_panning_camera:
		info += "Middle Drag: 🖱️ ACTIVE\n"
	
	# Hotkeys reminder
	info += "\n=== HOTKEYS ===\n"
	info += "P: Toggle All Panning\n"
	info += "L: Toggle Left Drag\n"
	info += "Z: Toggle Zoom\n"
	info += "D: Toggle Debug\n"
	info += "R: Reset Camera\n"
	info += "F: Fill Settlements\n"
	
	# Draw the info text
	var lines = info.split("\n")
	var line_height = 20
	var start_pos = Vector2(10, 30)
	
	for i in range(lines.size()):
		var line = lines[i]
		var color = Color.WHITE
		
		# Color coding
		if "✅" in line:
			color = Color.GREEN
		elif "❌" in line:
			color = Color.RED
		elif "ACTIVE" in line:
			color = Color.YELLOW
		elif "===" in line:
			color = Color.CYAN
		elif "HOTKEYS" in line:
			color = Color.LIGHT_BLUE
		elif "Left Drag" in line and "ACTIVE" in line:
			color = Color.ORANGE
		
		draw_string(ThemeDB.fallback_font, 
			Vector2(start_pos.x, start_pos.y + i * line_height), 
			line, 
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)