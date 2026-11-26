extends Node3D

const WORLD_SIZE := 220.0
const TERRAIN_SEGMENTS := 112
const PLAYER_SPEED := 6.0
const JUMP_VELOCITY := 6.8

var player: CharacterBody3D
var camera_pivot: Node3D
var camera: Camera3D
var move_touch := Vector2.ZERO
var look_touch := Vector2.ZERO
var active_move_touch := -1
var active_look_touch := -1
var jump_requested := false
var attack_requested := false
var _touch_move := Vector2.ZERO
var _attack_feedback_time := 0.0
var rng := RandomNumberGenerator.new()
var status_label: Label

func _ready() -> void:
	rng.randomize()
	_setup_environment()
	_build_terrain()
	_scatter_environment()
	_build_player()
	_build_hud()

func _setup_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.22, 0.25)
	sky_mat.sky_horizon_color = Color(0.68, 0.65, 0.51)
	sky_mat.ground_bottom_color = Color(0.08, 0.10, 0.08)
	sky_mat.ground_horizon_color = Color(0.42, 0.43, 0.34)
	sky.sky_material = sky_mat
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.54, 0.48)
	env.ambient_light_energy = 0.65
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.fog_enabled = true
	env.fog_light_color = Color(0.48, 0.53, 0.46)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.45
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_color = Color(1.0, 0.88, 0.68)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)

func _height_at(x: float, z: float) -> float:
	return sin(x * 0.035) * 1.6 + cos(z * 0.028) * 1.25 + sin((x + z) * 0.018) * 2.0 + cos(x * 0.075) * sin(z * 0.061) * 0.55

func _build_terrain() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var half := WORLD_SIZE * 0.5
	for z in range(TERRAIN_SEGMENTS + 1):
		for x in range(TERRAIN_SEGMENTS + 1):
			var px := -half + WORLD_SIZE * float(x) / TERRAIN_SEGMENTS
			var pz := -half + WORLD_SIZE * float(z) / TERRAIN_SEGMENTS
			vertices.append(Vector3(px, _height_at(px, pz), pz))
			var dx := _height_at(px + 0.15, pz) - _height_at(px - 0.15, pz)
			var dz := _height_at(px, pz + 0.15) - _height_at(px, pz - 0.15)
			normals.append(Vector3(-dx, 0.30, -dz).normalized())
			uvs.append(Vector2(float(x) / 8.0, float(z) / 8.0))
	for z in range(TERRAIN_SEGMENTS):
		for x in range(TERRAIN_SEGMENTS):
			var a := z * (TERRAIN_SEGMENTS + 1) + x
			var b := a + 1
			var c := a + TERRAIN_SEGMENTS + 1
			var d := c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.29, 0.20)
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.vertex_color_use_as_albedo = false
	mesh.surface_set_material(0, mat)
	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	var faces := PackedVector3Array()
	for tri in range(0, indices.size(), 3):
		faces.append(vertices[indices[tri]])
		faces.append(vertices[indices[tri + 1]])
		faces.append(vertices[indices[tri + 2]])
	var terrain_collision := ConcavePolygonShape3D.new()
	terrain_collision.set_faces(faces)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = terrain_collision
	body.add_child(shape)
	add_child(body)

func _make_material(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _scatter_environment() -> void:
	var tree_scene: PackedScene = load("res://assets/models/tree_small_02/tree_small_02_mobile.glb") if ResourceLoader.exists("res://assets/models/tree_small_02/tree_small_02_mobile.glb") else null
	var rock_scene: PackedScene = load("res://assets/models/rock_moss_set_01/rock_moss_set_01_mobile.glb") if ResourceLoader.exists("res://assets/models/rock_moss_set_01/rock_moss_set_01_mobile.glb") else null
	var fern_scene: PackedScene = load("res://assets/models/fern_02/fern_02_mobile.glb") if ResourceLoader.exists("res://assets/models/fern_02/fern_02_mobile.glb") else null
	for i in range(100):
		var x := rng.randf_range(-98, 98)
		var z := rng.randf_range(-98, 98)
		if Vector2(x, z).length() < 12.0:
			continue
		var instance: Node3D
		if tree_scene:
			instance = tree_scene.instantiate()
			instance.scale = Vector3.ONE * rng.randf_range(0.72, 1.25)
		else:
			instance = _procedural_tree()
		instance.position = Vector3(x, _height_at(x, z), z)
		instance.rotation.y = rng.randf_range(0, TAU)
		add_child(instance)
	for i in range(42):
		var x := rng.randf_range(-96, 96)
		var z := rng.randf_range(-96, 96)
		if Vector2(x, z).length() < 9.0:
			continue
		var instance: Node3D
		if rock_scene:
			instance = rock_scene.instantiate()
			instance.scale = Vector3.ONE * rng.randf_range(0.45, 1.2)
		else:
			instance = _procedural_rock()
		instance.position = Vector3(x, _height_at(x, z), z)
		instance.rotation.y = rng.randf_range(0, TAU)
		add_child(instance)
	for i in range(80):
		var x := rng.randf_range(-95, 95)
		var z := rng.randf_range(-95, 95)
		if Vector2(x, z).length() < 7.0:
			continue
		var instance: Node3D
		if fern_scene:
			instance = fern_scene.instantiate()
			instance.scale = Vector3.ONE * rng.randf_range(0.65, 1.15)
		else:
			instance = _procedural_fern()
		instance.position = Vector3(x, _height_at(x, z), z)
		instance.rotation.y = rng.randf_range(0, TAU)
		add_child(instance)

func _procedural_tree() -> Node3D:
	var root := Node3D.new()
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.38
	trunk_mesh.height = 4.2
	trunk.mesh = trunk_mesh
	trunk.position.y = 2.1
	trunk.material_override = _make_material(Color(0.20, 0.12, 0.075))
	root.add_child(trunk)
	for j in range(3):
		var crown := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = 1.65 - j * 0.18
		cm.height = 3.2 - j * 0.25
		crown.mesh = cm
		crown.position = Vector3(rng.randf_range(-0.25, 0.25), 3.6 + j * 0.9, rng.randf_range(-0.2, 0.2))
		crown.material_override = _make_material(Color(0.12 + j * 0.025, 0.20 + j * 0.025, 0.12))
		root.add_child(crown)
	return root

func _procedural_rock() -> Node3D:
	var root := Node3D.new()
	var rock := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = rng.randf_range(0.45, 0.9)
	sphere.height = sphere.radius * 1.35
	rock.mesh = sphere
	rock.scale = Vector3(1.3, 0.75, 1.0)
	rock.material_override = _make_material(Color(0.20, 0.23, 0.19))
	root.add_child(rock)
	return root

func _procedural_fern() -> Node3D:
	var root := Node3D.new()
	for i in range(7):
		var leaf := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.055
		capsule.height = rng.randf_range(0.8, 1.35)
		leaf.mesh = capsule
		leaf.position = Vector3(cos(i * TAU / 7.0) * 0.25, 0.48, sin(i * TAU / 7.0) * 0.25)
		leaf.rotation = Vector3(rng.randf_range(-0.5, 0.5), i * TAU / 7.0, rng.randf_range(-0.55, 0.55))
		leaf.material_override = _make_material(Color(0.16, 0.29, 0.13))
		root.add_child(leaf)
	return root

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Survivor"
	player.position = Vector3(0, _height_at(0, 0) + 1.1, 0)
	player.floor_snap_length = 0.35
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	player.add_child(collision)
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.36
	body_mesh.height = 1.25
	body.mesh = body_mesh
	body.position.y = 1.0
	body.material_override = _make_material(Color(0.18, 0.22, 0.18))
	player.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.23
	head_mesh.height = 0.46
	head.mesh = head_mesh
	head.position.y = 1.82
	head.material_override = _make_material(Color(0.55, 0.39, 0.27))
	player.add_child(head)
	var pack := MeshInstance3D.new()
	var pack_mesh := BoxMesh.new()
	pack_mesh.size = Vector3(0.48, 0.62, 0.24)
	pack.mesh = pack_mesh
	pack.position = Vector3(0, 1.08, 0.31)
	pack.material_override = _make_material(Color(0.12, 0.16, 0.12))
	player.add_child(pack)
	add_child(player)
	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 1.55, 0)
	player.add_child(camera_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0, 2.0, 6.5)
	camera.rotation_degrees.x = -12
	camera.current = true
	camera_pivot.add_child(camera)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	status_label = Label.new()
	status_label.text = "O ÚLTIMO REFÚGIO  |  PROTÓTIPO GODOT 4"
	status_label.position = Vector2(22, 18)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.88, 0.91, 0.78))
	layer.add_child(status_label)
	var hint := Label.new()
	hint.text = "WASD: mover  •  Espaço: pular  •  F: atacar  •  Toque esquerdo: mover  •  Arraste direito: câmera"
	hint.position = Vector2(22, 48)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.75, 0.79, 0.70))
	layer.add_child(hint)
	var jump_button := Button.new()
	jump_button.text = "PULAR"
	jump_button.custom_minimum_size = Vector2(112, 58)
	jump_button.anchor_left = 1.0
	jump_button.anchor_right = 1.0
	jump_button.anchor_top = 1.0
	jump_button.anchor_bottom = 1.0
	jump_button.offset_left = -144
	jump_button.offset_right = -24
	jump_button.offset_top = -158
	jump_button.offset_bottom = -94
	jump_button.pressed.connect(func(): jump_requested = true)
	layer.add_child(jump_button)
	var attack_button := Button.new()
	attack_button.text = "ATACAR"
	attack_button.custom_minimum_size = Vector2(112, 58)
	attack_button.anchor_left = 1.0
	attack_button.anchor_right = 1.0
	attack_button.anchor_top = 1.0
	attack_button.anchor_bottom = 1.0
	attack_button.offset_left = -144
	attack_button.offset_right = -24
	attack_button.offset_top = -82
	attack_button.offset_bottom = -18
	attack_button.pressed.connect(func(): attack_requested = true)
	layer.add_child(attack_button)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < get_viewport().get_visible_rect().size.x * 0.48 and event.position.y > get_viewport().get_visible_rect().size.y * 0.35:
				active_move_touch = event.index
				move_touch = event.position
			else:
				active_look_touch = event.index
				look_touch = event.position
		else:
			if event.index == active_move_touch:
				active_move_touch = -1
				move_touch = Vector2.ZERO
				_touch_move = Vector2.ZERO
			if event.index == active_look_touch:
				active_look_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == active_move_touch:
			var delta: Vector2 = event.position - move_touch
			move_touch = event.position
			var size := get_viewport().get_visible_rect().size
			_touch_move = Vector2(clampf(delta.x / 34.0, -1.0, 1.0), clampf(delta.y / 34.0, -1.0, 1.0))
		elif event.index == active_look_touch:
			camera_pivot.rotation.y -= event.relative.x * 0.004
			camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -0.85, 0.15)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var input_dir := keyboard
	if _touch_move.length() > 0.08:
		input_dir = _touch_move
	var forward := -camera_pivot.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := camera_pivot.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	var direction := (right * input_dir.x + forward * -input_dir.y).normalized()
	if direction.length() > 0.05:
		player.velocity.x = direction.x * PLAYER_SPEED
		player.velocity.z = direction.z * PLAYER_SPEED
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), delta * 9.0)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, PLAYER_SPEED * 5.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, PLAYER_SPEED * 5.0 * delta)
	if not player.is_on_floor():
		player.velocity.y -= 19.0 * delta
	elif jump_requested or Input.is_action_just_pressed("jump"):
		player.velocity.y = JUMP_VELOCITY
	if attack_requested or Input.is_action_just_pressed("attack"):
		status_label.text = "O ÚLTIMO REFÚGIO  |  ATAQUE"
		_attack_feedback_time = 0.45
	attack_requested = false
	jump_requested = false
	player.move_and_slide()
	var ground_y := _height_at(player.global_position.x, player.global_position.z)
	if player.global_position.y < ground_y - 3.0:
		player.global_position.y = ground_y + 1.0
		player.velocity = Vector3.ZERO
	if _attack_feedback_time > 0.0:
		_attack_feedback_time -= delta
		if _attack_feedback_time <= 0.0 and is_instance_valid(status_label):
			status_label.text = "O ÚLTIMO REFÚGIO  |  PROTÓTIPO GODOT 4"
