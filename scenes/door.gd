extends Node3D

@export var open_angle: float = 90.0
@export var animation_speed: float = 0.8

var is_open: bool = false
var tween: Tween

func toggle_door():
	if tween and tween.is_running():
		tween.kill()
		
	tween = create_tween()
	var target_angle = deg_to_rad(open_angle) if not is_open else 0.0
	
	# Теперь мы просто крутим саму петлю вокруг вертикальной оси Y!
	tween.tween_property(self, "rotation:z", target_angle, animation_speed)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
		
	is_open = !is_open

# Временный тест на Пробел/Enter
func _input(event):
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E:
			toggle_door()
