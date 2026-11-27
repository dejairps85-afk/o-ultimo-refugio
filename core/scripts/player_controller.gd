class_name PlayerController
extends CharacterBody3D
## Controlador do personagem.
##
## Regra de ouro (corrige o "girando sem sair do lugar"): este corpo NUNCA gira.
## Só o nó visual gira, e o ângulo-alvo vem da direção do movimento (relativa à
## câmera). A câmera nunca é filha deste nó nem depende da rotação dele, então
## não existe laço de realimentação entre rotação do personagem e direção do input.

const JOG_SPEED := 4.2
const RUN_SPEED := 6.6
const CROUCH_SPEED := 1.8
const ACCEL := 16.0
const AIR_ACCEL := 4.0
const GRAVITY := 18.0
const JUMP_VELOCITY := 6.0
const TURN_RATE := 12.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.2
const CAPSULE_RADIUS := 0.35
## Modelos glTF olham para +Z. Se na tela o personagem andar "de costas", troque para PI.
const MODEL_YAW_OFFSET := 0.0
const SURVIVOR_PATH := "res://assets/models/player/survivor-soldier.glb"

## Entrada (preenchida pelo HUD de toque ou pelo teclado). x = direita, y = frente.
var move_input := Vector2.ZERO
var wants_jump := false
var running := false
var crouching := false
## Yaw da câmera, atualizado por quem controla a câmera.
var cam_yaw := 0.0

var visual: Node3D
var anim: AnimationPlayer
var _facing_yaw := 0.0
var _collision: CollisionShape3D
var _capsule: CapsuleShape3D
var _current_anim := ""


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	floor_stop_on_slope = true
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	up_direction = Vector3.UP

	_capsule = CapsuleShape3D.new()
	_capsule.radius = CAPSULE_RADIUS
	_capsule.height = STAND_HEIGHT
	_collision = CollisionShape3D.new()
	_collision.shape = _capsule
	_collision.position.y = STAND_HEIGHT * 0.5
	add_child(_collision)

	_build_visual()


func _build_visual() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var model := ModelUtil.load_model(SURVIVOR_PATH)
	if model == null:
		# Fallback visível (e óbvio) caso o GLB não importe: cápsula + marcador de frente.
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = CAPSULE_RADIUS
		cm.height = STAND_HEIGHT
		mi.mesh = cm
		mi.position.y = STAND_HEIGHT * 0.5
		mi.material_override = PBR.flat(Color(0.2, 0.3, 0.2))
		visual.add_child(mi)
		var nose := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.12, 0.3)
		nose.mesh = bm
		nose.position = Vector3(0, 1.5, 0.35)
		nose.material_override = PBR.flat(Color(0.9, 0.2, 0.1))
		visual.add_child(nose)
		return
	model.name = "Model"
	visual.add_child(model)
	ModelUtil.fit_height(model, STAND_HEIGHT)
	anim = ModelUtil.find_anim(model)
	if anim:
		for n in ["Idle", "Walk", "Run"]:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		_play("Idle")


func _play(name_: String) -> void:
	if anim == null or _current_anim == name_ or not anim.has_animation(name_):
		return
	_current_anim = name_
	anim.play(name_, 0.2)


func set_crouch(on: bool) -> void:
	crouching = on
	var h := CROUCH_HEIGHT if on else STAND_HEIGHT
	_capsule.height = h
	_collision.position.y = h * 0.5
	if visual:
		visual.scale.y = 0.8 if on else 1.0


func _physics_process(delta: float) -> void:
	# Teclado (desenvolvimento no computador). O toque sobrescreve quando ativo.
	var key_vec := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var mi := move_input if move_input.length() > 0.01 else key_vec
	if Input.is_action_just_pressed("jump"):
		wants_jump = true

	var fwd := Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))
	var mag := minf(mi.length(), 1.0)
	var dir := Vector3.ZERO
	if mag > 0.001:
		dir = (right * mi.x + fwd * mi.y).normalized()

	var top_speed := CROUCH_SPEED if crouching else (RUN_SPEED if running else JOG_SPEED)
	var target := dir * top_speed * mag
	var horizontal := Vector2(velocity.x, velocity.z)
	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	horizontal = horizontal.move_toward(Vector2(target.x, target.z), accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y

	if is_on_floor():
		if wants_jump and not crouching:
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta
	wants_jump = false

	# Só o visual gira; o alvo depende apenas da direção do input e da câmera.
	if mag > 0.1 and visual:
		var target_yaw := atan2(dir.x, dir.z) + MODEL_YAW_OFFSET
		_facing_yaw = lerp_angle(_facing_yaw, target_yaw, 1.0 - exp(-TURN_RATE * delta))
		visual.rotation.y = _facing_yaw

	move_and_slide()

	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 4.8:
		_play("Run")
	elif speed > 0.4:
		_play("Walk")
	else:
		_play("Idle")


func facing_yaw() -> float:
	return _facing_yaw
