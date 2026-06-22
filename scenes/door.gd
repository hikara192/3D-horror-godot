extends Node3D

@export var open_angle: float = 90.0
@export var animation_speed: float = 0.8

var is_open: bool = false
var tween: Tween
var player_in_range: bool = false # Следим, рядом ли игрок

func toggle_door():
	if tween and tween.is_running():
		tween.kill()
		
	tween = create_tween()
	var target_angle = deg_to_rad(open_angle) if not is_open else 0.0
	
	# Твой поворот двери по оси Z
	tween.tween_property(self, "rotation:z", target_angle, animation_speed)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
		
	is_open = !is_open

# Обработка нажатия клавиши E
func _input(event):
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E:
			# Дверь откроется ТОЛЬКО если игрок в радиусе
			if player_in_range:
				toggle_door()

# Этот метод вызываем, когда игрок заходит в зону
func _on_interaction_area_body_entered(body: Node3D) -> void:
	# Проверяем, что вошедшее тело — это игрок (укажи имя своей группы или класс)
	if body.is_in_group("player") or body.name == "Player":
		player_in_range = true

# Этот метод вызываем, когда игрок выходит из зоны
func _on_interaction_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_in_range = false
