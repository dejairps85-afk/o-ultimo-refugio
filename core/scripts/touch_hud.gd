class_name TouchHud
extends Control
## Controles de toque multitoque, tratados por índice de dedo.
## - Joystick flutuante: aparece onde o dedo toca na metade esquerda da tela.
## - Olhar: arrastar na metade direita (fora dos botões).
## - Botões: círculos desenhados e testados aqui mesmo (nada de Button/Control
##   interceptando toques), então joystick + olhar + botão funcionam juntos.

signal jump_pressed
signal run_toggled(on: bool)
signal crouch_toggled(on: bool)

const STICK_RADIUS := 70.0
const DEADZONE := 0.12
const LOOK_SENSITIVITY := 0.0045  # radianos por pixel lógico

## x = direita, y = frente (tela para cima = frente).
var move_vector := Vector2.ZERO

var _look_accum := Vector2.ZERO
var _move_touch := -1
var _look_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _button_touches: Dictionary = {}  # índice do dedo -> id do botão
var _buttons: Dictionary = {}  # id -> {center, radius, label, toggle, on}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var w := size.x
	var h := size.y
	var on_run: bool = _buttons.get("run", {}).get("on", false)
	var on_crouch: bool = _buttons.get("crouch", {}).get("on", false)
	_buttons = {
		"jump": {"center": Vector2(w - 120.0, h - 120.0), "radius": 58.0, "label": "PULAR", "toggle": false, "on": false},
		"run": {"center": Vector2(w - 255.0, h - 82.0), "radius": 44.0, "label": "CORRER", "toggle": true, "on": on_run},
		"crouch": {"center": Vector2(w - 92.0, h - 245.0), "radius": 44.0, "label": "AGACHAR", "toggle": true, "on": on_crouch},
	}
	queue_redraw()


## Rotação de câmera acumulada desde a última chamada, em radianos.
func consume_look() -> Vector2:
	var out := _look_accum * LOOK_SENSITIVITY
	_look_accum = Vector2.ZERO
	return out


func jump_button_center() -> Vector2:
	return _buttons["jump"]["center"]


func _in_stick_zone(p: Vector2) -> bool:
	return p.x < size.x * 0.45 and p.y > size.y * 0.2


func _button_at(p: Vector2) -> String:
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		if p.distance_to(b["center"]) <= float(b["radius"]) * 1.2:
			return id
	return ""


func _press_button(id: String) -> void:
	var b: Dictionary = _buttons[id]
	match id:
		"jump":
			jump_pressed.emit()
		"run":
			b["on"] = not b["on"]
			if b["on"]:
				_set_toggle("crouch", false)
			run_toggled.emit(b["on"])
		"crouch":
			b["on"] = not b["on"]
			if b["on"]:
				_set_toggle("run", false)
			crouch_toggled.emit(b["on"])
	queue_redraw()


func _set_toggle(id: String, on: bool) -> void:
	if _buttons[id]["on"] == on:
		return
	_buttons[id]["on"] = on
	if id == "run":
		run_toggled.emit(on)
	else:
		crouch_toggled.emit(on)


func _update_stick() -> void:
	var delta := _stick_pos - _stick_origin
	var dist := delta.length()
	if dist > STICK_RADIUS:
		# O stick "acompanha" o dedo quando ele passa do limite.
		_stick_origin += delta.normalized() * (dist - STICK_RADIUS)
		delta = _stick_pos - _stick_origin
		dist = STICK_RADIUS
	var n := dist / STICK_RADIUS
	if n < DEADZONE:
		move_vector = Vector2.ZERO
	else:
		var scaled := (n - DEADZONE) / (1.0 - DEADZONE)
		var d := delta.normalized()
		move_vector = Vector2(d.x, -d.y) * scaled
	queue_redraw()


func _release(idx: int) -> void:
	if idx == _move_touch:
		_move_touch = -1
		move_vector = Vector2.ZERO
	if idx == _look_touch:
		_look_touch = -1
	_button_touches.erase(idx)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and not t.canceled:
			var b := _button_at(t.position)
			if b != "":
				_button_touches[t.index] = b
				_press_button(b)
			elif _in_stick_zone(t.position):
				if _move_touch == -1:
					_move_touch = t.index
					_stick_origin = t.position
					_stick_pos = t.position
					_update_stick()
			elif _look_touch == -1:
				_look_touch = t.index
		else:
			_release(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _move_touch:
			_stick_pos = d.position
			_update_stick()
		elif d.index == _look_touch:
			_look_accum += d.relative
	elif event is InputEventMouseMotion:
		# Computador: arrastar com o botão direito gira a câmera.
		var m := event as InputEventMouseMotion
		if (m.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			_look_accum += m.relative


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Joystick: mostra a posição sugerida quando parado, e o stick real quando em uso.
	var base_center := _stick_origin if _move_touch != -1 else Vector2(150.0, size.y - 150.0)
	var alpha := 0.55 if _move_touch != -1 else 0.25
	draw_circle(base_center, STICK_RADIUS, Color(0.05, 0.06, 0.05, alpha * 0.6))
	draw_arc(base_center, STICK_RADIUS, 0.0, TAU, 48, Color(0.85, 0.9, 0.8, alpha), 3.0, true)
	var knob := _stick_pos if _move_touch != -1 else base_center
	draw_circle(knob, 30.0, Color(0.85, 0.9, 0.8, alpha + 0.1))
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		var lit: bool = b["on"] or _button_touches.values().has(id)
		draw_circle(c, r, Color(0.9, 0.85, 0.6, 0.55) if lit else Color(0.05, 0.06, 0.05, 0.45))
		draw_arc(c, r, 0.0, TAU, 40, Color(0.9, 0.92, 0.85, 0.8), 3.0, true)
		var label: String = b["label"]
		var fs := 14
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, c + Vector2(-tw * 0.5, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))
