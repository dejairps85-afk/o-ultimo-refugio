class_name CameraRig
extends Node3D
## Câmera em terceira pessoa independente do personagem.
## - top_level: não herda rotação/posição do alvo, só o segue (suavizado).
## - SpringArm3D: encurta quando há parede/terreno entre o alvo e a câmera.

const MIN_PITCH := -0.95
const MAX_PITCH := 0.5
const ARM_LENGTH := 3.4
const FOLLOW_RATE := 16.0
const FOCUS_HEIGHT := 1.55

var yaw := 0.0
var pitch := -0.18
var target: Node3D
var arm: SpringArm3D
var cam: Camera3D


func setup(follow_target: Node3D, exclude: RID) -> void:
	target = follow_target
	top_level = true
	arm = SpringArm3D.new()
	arm.spring_length = ARM_LENGTH
	arm.margin = 0.15
	arm.collision_mask = 1  # só o mundo; nunca o próprio jogador
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	arm.shape = probe
	arm.add_excluded_object(exclude)
	add_child(arm)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	cam.far = 400.0
	cam.h_offset = 0.35  # leve enquadramento por cima do ombro
	cam.current = true
	arm.add_child(cam)
	if target:
		global_position = target.global_position + Vector3.UP * FOCUS_HEIGHT
	_apply()


func rotate_view(delta_rad: Vector2) -> void:
	yaw -= delta_rad.x
	pitch = clampf(pitch - delta_rad.y, MIN_PITCH, MAX_PITCH)
	_apply()


func _apply() -> void:
	rotation = Vector3(0.0, yaw, 0.0)
	if arm:
		arm.rotation = Vector3(pitch, 0.0, 0.0)


func _process(delta: float) -> void:
	if target == null:
		return
	var focus := target.global_position + Vector3.UP * FOCUS_HEIGHT
	if global_position.distance_to(focus) > 8.0:
		global_position = focus
	else:
		global_position = global_position.lerp(focus, 1.0 - exp(-FOLLOW_RATE * delta))
