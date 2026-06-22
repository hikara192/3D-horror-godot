extends Node3D

# Путь к следующей сцене, на которую нужно перейти (выбирается в инспекторе)
@export_file("*.tscn") var target_scene: String

# Ссылка на черный прямоугольник по уникальному имени %FadeRect
@onready var fade_rect: ColorRect = %FadeRect

var player_in_range: bool = false
var is_transitioning: bool = false # Блокировка повторных нажатий

func _ready() -> void:
	# Проверка при старте, чтобы сразу выявить проблемы с интерфейсом
	if not is_instance_valid(fade_rect):
		print("[Дверь-Переход] ВНИМАНИЕ: Узел %FadeRect не найден в сцене! Проверь, задано ли уникальное имя (Access as Unique Name) в интерфейсе.")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E:
			# Если игрок в радиусе и переход еще не запущен
			if player_in_range and not is_transitioning:
				start_transition()
			elif not player_in_range:
				print("[Дверь-Переход] Нажата кнопка E, но игрок вне радиуса действия двери.")

func start_transition() -> void:
	# Защита от спама клавиши E
	is_transitioning = true
	
	if target_scene == "":
		push_error("ОШИБКА: Забыл указать Target Scene в инспекторе двери!")
		is_transitioning = false
		return
		
	if not is_instance_valid(fade_rect):
		push_error("ОШИБКА: Узел %FadeRect не найден в сцене! Переход невозможен.")
		is_transitioning = false # Возвращаем возможность нажать кнопку после исправления
		return
		
	# Делаем черный прямоугольник видимым (но пока прозрачным)
	fade_rect.show()
	print("[Дверь-Переход] Начинаем переход на сцену: ", target_scene)
	
	# Плавное появление черного экрана за 1.5 секунды
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
		
	# Когда экран полностью потемнел, меняем уровень
	tween.tween_callback(change_level)

func change_level() -> void:
	print("[Дверь-Переход] Меняем сцену...")
	get_tree().change_scene_to_file(target_scene)


# === СИГНАЛЫ ДЛЯ УЗЛА Area3D ===
# Важно: Убедись, что сигналы подключены именно к этим функциям!

func _on_area_3d_body_entered(body: Node3D) -> void:
	# Проверяем, что вошел игрок (по группе или имени)
	if body.is_in_group("player") or body.name == "Player":
		player_in_range = true
		print("[Дверь-Переход] Игрок подошел к двери! Нажми E для перехода.")

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_in_range = false
		print("[Дверь-Переход] Игрок отошел от двери.")
