extends Node3D

# Путь к следующей сцене, на которую нужно перейти (выбирается в инспекторе)
@export_file("*.tscn") var target_scene: String

# Ссылка на черный прямоугольник перехода (ColorRect)
@onready var fade_rect: Control = %FadeRect if has_node("%FadeRect") else null

# Ссылка на текст реплики (%SubtitleLabel)
@onready var subtitle_label: Label = %SubtitleLabel if has_node("%SubtitleLabel") else null

var player_in_range: bool = false
var is_transitioning: bool = false # Блокировка повторных нажатий

func _ready() -> void:
	# 1. Скрываем черный экран перехода на старте игры
	if is_instance_valid(fade_rect):
		fade_rect.hide()
		fade_rect.modulate.a = 0.0
	else:
		print("[Сцена] Предупреждение: Узел %FadeRect не найден.")
		
	# 2. ЗАПУСКАЕМ ЭФФЕКТ ПЕЧАТАНИЯ ТЕКСТА
	if is_instance_valid(subtitle_label):
		# Вбиваем фразу, но делаем её полностью невидимой на старте
		subtitle_label.text = "Блять, заебали свет выключать. Пойду прогуляюсь."
		subtitle_label.visible_ratio = 0.0
		subtitle_label.show()
		subtitle_label.modulate.a = 1.0
		
		# Создаем анимацию появления букв
		var text_tween = create_tween()
		
		# Плавно за 2.5 секунды "печатаем" текст (меняем visible_ratio с 0 до 1)
		text_tween.tween_property(subtitle_label, "visible_ratio", 1.0, 2.5)\
			.set_trans(Tween.TRANS_LINEAR)
		
		# Ждем 3.5 секунды, пока игрок читает готовую строчку
		text_tween.tween_interval(3.5)
		
		# Плавно стираем (растворяем) весь текст за 1 секунду
		text_tween.tween_property(subtitle_label, "modulate:a", 0.0, 1.0)
		
		print("[Сцена] Эффект печатанья реплики запущен.")
	else:
		print("[Сцена] ВНИМАНИЕ: Узел %SubtitleLabel не найден!")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E:
			if player_in_range and not is_transitioning:
				start_transition()
			elif not player_in_range:
				print("[Дверь-Переход] Нажата кнопка E, но игрок вне радиуса.")

func start_transition() -> void:
	is_transitioning = true
	
	if target_scene == "":
		push_error("ОШИБКА: Забыл указать Target Scene в инспекторе двери!")
		is_transitioning = false
		return
		
	if not is_instance_valid(fade_rect):
		push_error("ОШИБКА: Узел %FadeRect не найден в сцене! Переход невозможен.")
		is_transitioning = false 
		return
		
	fade_rect.show()
	print("[Дверь-Переход] Начинаем переход на сцену: ", target_scene)
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
		
	tween.tween_callback(change_level)

func change_level() -> void:
	print("[Дверь-Переход] Меняем сцену...")
	get_tree().change_scene_to_file(target_scene)


# === СИГНАЛЫ ДЛЯ УЗЛА Area3D ===
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_in_range = true
		print("[Дверь-Переход] Игрок подошел к двери! Нажми E для перехода.")

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_in_range = false
		print("[Дверь-Переход] Игрок отошел от двери.")
