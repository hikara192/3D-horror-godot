extends CharacterBody3D

const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const CROUCH_SPEED = 2.5
const JUMP_VELOCITY = 4.0

const ACCELERATION = 6.0
const FRICTION = 10.0

var is_crouching = false
@onready var collision_shape = $PlayerCollisionShape 
var default_height: float = 2.0
var crouch_height: float = 1.0

const BOB_FREQ = 2.4
const BOB_AMP = 0.06
var bob_time = 0.0
var default_cam_height: float = 0.0

const LEAN_ANGLE = 2.5
const LEAN_SPEED = 5.0
var current_lean: float = 0.0

# Массив инвентаря на 5 слотов
var inventory: Array[String] = ["", "", "", "", ""] 
var active_slot_index: int = 0 

var flashlight_battery: float = 100.0 
const BATTERY_DRAIN_SPEED = 1.0 
var flicker_timer: float = 0.0
var default_flashlight_energy: float = 1.0 

@onready var interaction_ray = $Camera3D/InteractionRay
@onready var hotbar_container = $InventoryUI/Hotbar 
@onready var flashlight = $Camera3D/Flashlight 
@onready var battery_label = $InventoryUI/BatteryLabel

var current_speed = WALK_SPEED

@export_group('camera')
@export var mouse_sensibility: float = 0.002
@export_range(-90.0, 0.0, 0.1, "radians_as_degrees") var min_vertical_angle: float = -PI/2
@export_range(0.0, 90.0, 0.1, "radians_as_degrees") var max_vertical_angle: float = PI/4
@onready var camera = $Camera3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	default_cam_height = camera.position.y
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		default_height = collision_shape.shape.height
		
	if flashlight:
		default_flashlight_energy = flashlight.light_energy
		
	# === ЗАГРУЗКА ИЗ ГЛОБАЛЬНОЙ ПАМЯТИ ===
	# Если в GlobalData уже сохранен инвентарь (например, после перехода), загружаем его
	if GlobalData.saved_inventory.size() == 5:
		inventory = GlobalData.saved_inventory.duplicate()
		print("[Игрок] Инвентарь успешно восстановлен: ", inventory)
	else:
		# Если это самый первый запуск игры, синхронизируем пустой инвентарь игрока с глобальным
		GlobalData.saved_inventory = inventory.duplicate()
	
	update_inventory_ui()
	if interaction_ray:
		interaction_ray.add_exception(self)
	
	highlight_active_slot()
	check_active_item()
	
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensibility) 
		camera.rotation.x -= event.relative.y * mouse_sensibility
		camera.rotation.x = clamp(camera.rotation.x, min_vertical_angle, max_vertical_angle)
		
	if event.is_action_pressed("toggle_mouse_capture"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		execute_interaction()
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		use_active_item()
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1: change_active_slot(0)
		elif event.keycode == KEY_2: change_active_slot(1)
		elif event.keycode == KEY_3: change_active_slot(2)
		elif event.keycode == KEY_4: change_active_slot(3)
		elif event.keycode == KEY_5: change_active_slot(4)

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var new_slot = active_slot_index - 1
			if new_slot < 0: new_slot = 4
			change_active_slot(new_slot)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var new_slot = (active_slot_index + 1) % 5
			change_active_slot(new_slot)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_key_pressed(KEY_CTRL):
		is_crouching = true
	else:
		is_crouching = false
		
	var target_height = crouch_height if is_crouching else default_height
	var target_cam_y = (default_cam_height - 0.7) if is_crouching else default_cam_height
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		collision_shape.shape.height = move_toward(collision_shape.shape.height, target_height, delta * 10.0)
		
	var base_cam_y = move_toward(camera.position.y, target_cam_y, delta * 10.0)

	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY

	if is_crouching:
		current_speed = CROUCH_SPEED
	elif Input.is_key_pressed(KEY_SHIFT) and is_on_floor():
		current_speed = SPRINT_SPEED
	else:
		current_speed = WALK_SPEED

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, ACCELERATION * current_speed * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, ACCELERATION * current_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * current_speed * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * current_speed * delta)

	move_and_slide()

	if is_on_floor() and direction.length() > 0.1:
		bob_time += delta * velocity.length() * float(is_on_floor())
		var bob_y = sin(bob_time * BOB_FREQ) * BOB_AMP
		var bob_x = cos(bob_time * BOB_FREQ / 2) * BOB_AMP * 0.5
		camera.position.y = base_cam_y + bob_y
		camera.position.x = bob_x
	else:
		bob_time = 0.0
		camera.position.y = move_toward(camera.position.y, base_cam_y, delta * 2.0)
		camera.position.x = move_toward(camera.position.x, 0.0, delta * 2.0)

	var target_lean_angle = -input_dir.x * deg_to_rad(LEAN_ANGLE)
	current_lean = lerp(current_lean, target_lean_angle, LEAN_SPEED * delta)
	camera.rotation.z = current_lean

	process_flashlight_battery(delta)


func process_flashlight_battery(delta: float) -> void:
	if flashlight and flashlight.visible:
		flashlight_battery = max(0.0, flashlight_battery - BATTERY_DRAIN_SPEED * delta)
		
		if battery_label:
			battery_label.visible = true
			battery_label.text = "Заряд: " + str(floor(flashlight_battery)) + "%"
		
		if flashlight_battery <= 0:
			flashlight.light_energy = 0.0 
		elif flashlight_battery < 30.0:
			flicker_timer += delta
			if flicker_timer > randf_range(0.05, 0.3): 
				flicker_timer = 0.0
				if randf() > 0.4:
					flashlight.light_energy = default_flashlight_energy * 0.1
				else:
					flashlight.light_energy = default_flashlight_energy * 0.7
		else:
			flashlight.light_energy = default_flashlight_energy
	else:
		if battery_label:
			battery_label.visible = false


func execute_interaction() -> void:
	if interaction_ray and interaction_ray.is_colliding():
		var target = interaction_ray.get_collider()
		if target.has_method("interact"):
			target.interact(self)


func use_active_item() -> void:
	var current_item = inventory[active_slot_index]
	
	if current_item == "Батарейка":
		if flashlight_battery >= 100.0:
			print("Фонарик уже полностью заряжен!")
			return
			
		flashlight_battery = 100.0
		print("Фонарик заряжен!")
		
		# Очищаем слот локально
		inventory[active_slot_index] = ""
		
		# === СИНХРОНИЗАЦИЯ ПОСЛЕ ИСПОЛЬЗОВАНИЯ ПРЕДМЕТА ===
		GlobalData.saved_inventory = inventory.duplicate()
		
		update_inventory_ui()
		check_active_item()


func add_item_to_inventory(item_name: String) -> bool:
	for i in range(inventory.size()):
		if inventory[i] == "":
			inventory[i] = item_name
			
			# === СИНХРОНИЗАЦИЯ ПОСЛЕ ПОДБОРА ПРЕДМЕТА ===
			GlobalData.saved_inventory = inventory.duplicate()
			
			update_inventory_ui()
			check_active_item()
			return true
	print("Инвентарь полон!")
	return false


func change_active_slot(slot_index: int) -> void:
	active_slot_index = slot_index
	highlight_active_slot()
	check_active_item()


func highlight_active_slot() -> void:
	if not hotbar_container: return
	var slots = hotbar_container.get_children()
	for i in range(slots.size()):
		if i == active_slot_index:
			slots[i].modulate = Color(1.5, 1.5, 1.5, 1.0) 
		else:
			slots[i].modulate = Color(1.0, 1.0, 1.0, 1.0)


func check_active_item() -> void:
	var current_item = inventory[active_slot_index]
	if current_item == "Фонарик" and flashlight_battery > 0:
		if flashlight: flashlight.visible = true
	else:
		if flashlight: flashlight.visible = false


func update_inventory_ui() -> void:
	if not hotbar_container: return
	var slots = hotbar_container.get_children()
	for i in range(slots.size()):
		if i < inventory.size():
			var label = slots[i].get_node_or_null("Label")
			if label:
				if inventory[i] != "":
					label.text = inventory[i]
				else:
					label.text = ""
