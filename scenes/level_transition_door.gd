extends Node3D

@export_file("*.tscn") var target_scene: String # Путь к новой сцене (выбирается в инспекторе)
@onready var fade_rect: ColorRect = %FadeRect # Ссылка на черный прямоугольник

var player_in_range: bool = false
var is_transitioning: bool = false # Блокировка, чтобы не нажать дважды

func _input(event):
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E and player_in_range and not is_transitioning:
			start_transition()

func start_transition():
	is_transitioning = true
	
	# Создаем плавное появление черного экрана
	var tween = create_tween()
	# Делаем экран черным за 1.5 секунды
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	
	# Когда экран стал полностью черным, меняем сцену
	tween.tween_callback(change_level)

func change_level():
	if target_scene == "":
		print("Забыл указать путь к сцене в инспекторе!")
		return
	
	# Команда смены сцены
	get_tree().change_scene_to_file(target_scene)

# Стандартные сигналы для Area3D (как в прошлой двери)
func _on_area_3d_body_entered(body):
	if body.is_in_group("player") or body.name == "Player":
		player_in_range = true

func _on_area_3d_body_exited(body):
	if body.is_in_group("player") or body.name == "Player":
		player_in_range = false
