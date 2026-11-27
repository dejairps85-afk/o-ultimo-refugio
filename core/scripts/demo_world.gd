extends Node3D
## Demonstração do novo núcleo: uma rua abandonada, personagem, câmera e controles.
## Mundo simples e plano DE PROPÓSITO: primeiro o movimento/câmera/colisão precisam
## ser comprovadamente corretos; relevo e mundo aberto vêm depois.

const ROAD_HALF := 6.0
const SIDEWALK_W := 3.0
const SIDEWALK_H := 0.08
const BUILD_DEPTH := 10.0
const WALL_X := ROAD_HALF + SIDEWALK_W  # face dos prédios voltada para a rua
const STREET_HALF_LEN := 70.0
const SPAWN := Vector3(0.0, 0.1, 34.0)

var player: PlayerController
var rig: CameraRig
var hud: TouchHud
var fps_label: Label
var rng := RandomNumberGenerator.new()
var _probe_z := 0.0
var _concrete_cache := {}


func _ready() -> void:
	rng.seed = 20261127
	_build_environment()
	_build_ground_and_street()
	_build_buildings()
	_build_props()
	_build_vegetation()
	_build_player_and_camera()
	_build_hud()
	if "--playtest" in OS.get_cmdline_user_args():
		_run_playtest.call_deferred()


func _process(_delta: float) -> void:
	if is_instance_valid(rig) and is_instance_valid(hud):
		var look := hud.consume_look()
		if look != Vector2.ZERO:
			rig.rotate_view(look)
	if fps_label:
		fps_label.text = "NÚCLEO 0.1  |  %d FPS" % Engine.get_frames_per_second()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	player.cam_yaw = rig.yaw
	player.move_input = hud.move_vector
	if player.global_position.y < -15.0:
		_respawn()


func _respawn() -> void:
	player.global_position = SPAWN
	player.velocity = Vector3.ZERO


# ───────────────────────── ambiente e luz ─────────────────────────

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.20, 0.33, 0.48)
	sky_mat.sky_horizon_color = Color(0.86, 0.66, 0.46)
	sky_mat.ground_horizon_color = Color(0.55, 0.48, 0.38)
	sky_mat.ground_bottom_color = Color(0.12, 0.12, 0.10)
	sky_mat.sun_angle_max = 28.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.62, 0.50)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Sol baixo (fim de tarde): sombras longas e luz quente.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.82, 0.60)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_blur = 1.5
	add_child(sun)


# ───────────────────────── chão e rua ─────────────────────────

func _static_box(parent: Node, center: Vector3, size: Vector3, mat: Material, with_mesh := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if with_mesh:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = mat
		body.add_child(mi)
	parent.add_child(body)
	return body


func _build_ground_and_street() -> void:
	# Chão: topo exatamente em y=0.
	_static_box(self, Vector3(0, -0.5, 0), Vector3(500, 1.0, 500), PBR.ground())
	# Asfalto: faixa levemente acima do chão (sem colisão própria; o chão já colide).
	var road := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(ROAD_HALF * 2.0, 0.04, STREET_HALF_LEN * 2.0 + 20.0)
	road.mesh = rm
	road.position = Vector3(0, 0.02, 0)
	road.material_override = PBR.asphalt()
	add_child(road)
	# Faixa central tracejada.
	var paint := PBR.flat(Color(0.75, 0.68, 0.38), 0.9)
	var z := -STREET_HALF_LEN
	while z < STREET_HALF_LEN:
		var dash := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(0.18, 0.02, 2.2)
		dash.mesh = dm
		dash.position = Vector3(0, 0.045, z)
		dash.material_override = paint
		add_child(dash)
		z += 5.0
	# Calçadas com colisão (altura baixa para a cápsula subir sem travar).
	var curb := PBR.concrete(Color(0.75, 0.75, 0.72))
	for side in [-1.0, 1.0]:
		_static_box(self, Vector3(side * (ROAD_HALF + SIDEWALK_W * 0.5), SIDEWALK_H * 0.5, 0), Vector3(SIDEWALK_W, SIDEWALK_H, STREET_HALF_LEN * 2.0), curb)


# ───────────────────────── prédios ─────────────────────────

func _concrete(tint: Color) -> StandardMaterial3D:
	var key := tint.to_html()
	if not _concrete_cache.has(key):
		_concrete_cache[key] = PBR.concrete(tint)
	return _concrete_cache[key]


func _build_buildings() -> void:
	var tints := [Color(0.62, 0.60, 0.55), Color(0.50, 0.48, 0.46), Color(0.58, 0.54, 0.47), Color(0.45, 0.46, 0.46)]
	var z_centers := [-52.0, -34.0, -12.0, 6.0, 24.0, 44.0]
	var window_mat := StandardMaterial3D.new()
	window_mat.albedo_color = Color(0.05, 0.07, 0.08)
	window_mat.roughness = 0.15
	window_mat.metallic = 0.4
	window_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var door_mat := PBR.flat(Color(0.14, 0.09, 0.06), 0.9)
	for side in [-1.0, 1.0]:  # -1 = lado esquerdo (x<0), +1 = direito
		for i in range(z_centers.size()):
			var floors := rng.randi_range(3, 5)
			var h := floors * 3.2
			var len_z := 16.0
			var cz: float = z_centers[i] + (rng.randf() - 0.5) * 2.0
			var cx: float = side * (WALL_X + BUILD_DEPTH * 0.5)
			var tint: Color = tints[rng.randi() % tints.size()]
			var body := _static_box(self, Vector3(cx, h * 0.5, cz), Vector3(BUILD_DEPTH, h, len_z), _concrete(tint))
			# Beiral/parapeito.
			var lip := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(BUILD_DEPTH + 0.4, 0.5, len_z + 0.4)
			lip.mesh = lm
			lip.position = Vector3(0, h * 0.5 + 0.25, 0)
			lip.material_override = _concrete(tint.darkened(0.25))
			body.add_child(lip)
			# Janelas (uma malha só por prédio) e porta.
			var face_x := -side * (BUILD_DEPTH * 0.5 + 0.03)  # em coordenadas locais do prédio, voltado à rua
			var win := _window_mesh(floors, len_z, face_x, -side)
			var wi := MeshInstance3D.new()
			wi.mesh = win
			wi.material_override = window_mat
			wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			body.add_child(wi)
			var door := MeshInstance3D.new()
			var dm := BoxMesh.new()
			dm.size = Vector3(0.12, 2.3, 1.5)
			door.mesh = dm
			door.position = Vector3(face_x, -h * 0.5 + SIDEWALK_H + 1.15, 0)
			door.material_override = door_mat
			body.add_child(door)
			if side < 0.0 and absf(cz + 12.0) < 3.0:
				_probe_z = cz
	if _probe_z == 0.0:
		_probe_z = -12.0


## Janelas como quads agrupados num único mesh. `facing` = +1 voltado a +X, -1 a -X.
func _window_mesh(floors: int, len_z: float, face_x: float, facing: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := Vector3(facing, 0, 0)
	var cols := 5
	var spacing := len_z / float(cols)
	var h := floors * 3.2
	for f in range(floors):
		if f == 0:
			continue  # térreo: porta e vitrines escuras ficam como parede
		var cy := -h * 0.5 + 1.6 + f * 3.2 + 0.3
		for c in range(cols):
			if rng.randf() < 0.12:
				continue  # janela "faltando"
			var cz := -len_z * 0.5 + spacing * (c + 0.5)
			var hw := 0.7
			var hh := 0.9
			var p0 := Vector3(face_x, cy - hh, cz - hw)
			var p1 := Vector3(face_x, cy - hh, cz + hw)
			var p2 := Vector3(face_x, cy + hh, cz + hw)
			var p3 := Vector3(face_x, cy + hh, cz - hw)
			for v in [p0, p1, p2, p0, p2, p3]:
				st.set_normal(n)
				st.add_vertex(v)
	return st.commit()


# ───────────────────────── objetos de cena ─────────────────────────

func _build_props() -> void:
	var rust := PBR.flat(Color(0.30, 0.17, 0.11), 0.65, 0.55)
	var tire := PBR.flat(Color(0.04, 0.04, 0.04), 0.95)
	var glass := PBR.flat(Color(0.08, 0.10, 0.11), 0.2, 0.3)
	# Carros abandonados (poucos, com colisão simples).
	var cars := [Vector3(-3.2, 0, 14.0), Vector3(3.0, 0, -8.0), Vector3(-2.6, 0, -30.0)]
	var yaws := [0.12, -0.2, 0.35]
	for i in range(cars.size()):
		_add_car(cars[i], yaws[i], rust, tire, glass)
	# Postes de luz.
	var pole_mat := PBR.flat(Color(0.12, 0.12, 0.12), 0.6, 0.6)
	for side in [-1.0, 1.0]:
		var z := -60.0
		while z <= 60.0:
			_add_pole(Vector3(side * (ROAD_HALF + 0.6), 0, z), -side, pole_mat)
			z += 20.0
	# Barreira de concreto e barris bloqueando parte da rua (ao fundo).
	var jersey := _concrete(Color(0.7, 0.7, 0.68))
	for i in range(3):
		_static_box(self, Vector3(-4.0 + i * 2.6, 0.45, -62.0), Vector3(2.4, 0.9, 0.6), jersey)
	var barrel := PBR.flat(Color(0.35, 0.10, 0.08), 0.5, 0.5)
	for p in [Vector3(1.2, 0, -60.0), Vector3(2.0, 0, -61.0), Vector3(0.6, 0, -61.4)]:
		var b := StaticBody3D.new()
		b.collision_layer = 1
		b.position = p + Vector3(0, 0.45, 0)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3
		cyl.height = 0.9
		cs.shape = cyl
		b.add_child(cs)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.3
		cm.bottom_radius = 0.3
		cm.height = 0.9
		mi.mesh = cm
		mi.material_override = barrel
		b.add_child(mi)
		add_child(b)


func _add_car(pos: Vector3, yaw: float, rust: Material, tire: Material, glass: Material) -> void:
	var root := StaticBody3D.new()
	root.collision_layer = 1
	root.position = pos
	root.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.5, 4.3)
	cs.shape = box
	cs.position.y = 0.75
	root.add_child(cs)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.9, 0.65, 4.3)
	body.mesh = bm
	body.position.y = 0.6
	body.material_override = rust
	root.add_child(body)
	var cabin := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.7, 0.6, 2.2)
	cabin.mesh = cm
	cabin.position = Vector3(0, 1.2, -0.2)
	cabin.material_override = glass
	root.add_child(cabin)
	for wx in [-0.95, 0.95]:
		for wz in [-1.4, 1.4]:
			var w := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = 0.36
			wm.bottom_radius = 0.36
			wm.height = 0.26
			w.mesh = wm
			w.rotation.z = PI * 0.5
			w.position = Vector3(wx, 0.36, wz)
			w.material_override = tire
			root.add_child(w)
	add_child(root)


func _add_pole(pos: Vector3, arm_dir: float, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.12
	cyl.height = 5.5
	cs.shape = cyl
	cs.position.y = 2.75
	body.add_child(cs)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.07
	pm.bottom_radius = 0.1
	pm.height = 5.5
	pole.mesh = pm
	pole.position.y = 2.75
	pole.material_override = mat
	body.add_child(pole)
	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(1.4, 0.08, 0.08)
	arm.mesh = am
	arm.position = Vector3(arm_dir * 0.7, 5.4, 0)
	arm.material_override = mat
	body.add_child(arm)
	add_child(body)


# ───────────────────────── vegetação ─────────────────────────
# Os GLBs de vegetação são pesados (a árvore tem ~6 MB). Poucas instâncias; se o
# modelo não importar, simplesmente não aparece (sem quebrar o jogo).

func _build_vegetation() -> void:
	var tree_path := "res://assets/models/tree_small_02/tree_small_02_mobile.glb"
	var fern_path := "res://assets/models/fern_02/fern_02_mobile.glb"
	var rock_path := "res://assets/models/rock_moss_set_01/rock_moss_set_01_mobile.glb"
	var spots := []
	for i in range(14):
		var side := -1.0 if i % 2 == 0 else 1.0
		spots.append(Vector3(side * rng.randf_range(WALL_X + BUILD_DEPTH + 4.0, WALL_X + BUILD_DEPTH + 30.0), 0, rng.randf_range(-STREET_HALF_LEN, STREET_HALF_LEN)))
	for p in spots:
		_place_model(tree_path, p, rng.randf_range(5.0, 8.0), rng.randf() * TAU)
	# Samambaias e rochas nas bordas da calçada e nos vãos.
	for i in range(18):
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(side * (ROAD_HALF + SIDEWALK_W - 0.5 + rng.randf() * 0.4), SIDEWALK_H, rng.randf_range(-STREET_HALF_LEN, STREET_HALF_LEN))
		_place_model(fern_path, p, rng.randf_range(0.5, 0.9), rng.randf() * TAU)
	for i in range(6):
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(side * rng.randf_range(ROAD_HALF + 0.4, ROAD_HALF + 2.0), 0, rng.randf_range(-40.0, 40.0))
		_place_model(rock_path, p, rng.randf_range(0.5, 1.1), rng.randf() * TAU)


func _place_model(path: String, pos: Vector3, height: float, yaw: float) -> void:
	var m := ModelUtil.load_model(path)
	if m == null:
		return
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	holder.add_child(m)
	add_child(holder)
	ModelUtil.fit_height(m, height)


# ───────────────────────── jogador, câmera e HUD ─────────────────────────

func _build_player_and_camera() -> void:
	player = PlayerController.new()
	player.name = "Survivor"
	player.position = SPAWN
	add_child(player)
	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.setup(player, player.get_rid())
	rig.yaw = 0.0  # olhando para -Z, ao longo da rua
	rig.rotate_view(Vector2.ZERO)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = TouchHud.new()
	layer.add_child(hud)
	hud.jump_pressed.connect(func(): player.wants_jump = true)
	hud.run_toggled.connect(func(on: bool): player.running = on)
	hud.crouch_toggled.connect(func(on: bool): player.set_crouch(on))
	fps_label = Label.new()
	fps_label.position = Vector2(16, 10)
	fps_label.add_theme_font_size_override("font_size", 16)
	fps_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	layer.add_child(fps_label)


# ───────────────────────── playtest automático ─────────────────────────
# Rodar: godot --headless --path . -- --playtest
# Injeta toques reais (InputEventScreenTouch/Drag) e verifica o comportamento.

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(index: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = rel
	Input.parse_input_event(e)


func _angle_diff(a: float, b: float) -> float:
	return absf(wrapf(a - b, -PI, PI))


func _run_playtest() -> void:
	var fails: Array[String] = []
	var vs := get_viewport().get_visible_rect().size
	await _frames(90)

	# 1) Pousa no chão e não afunda.
	if not player.is_on_floor():
		fails.append("Jogador não está no chão após 90 frames")
	if absf(player.global_position.y) > 0.4:
		fails.append("Altura inicial incorreta: %.2f" % player.global_position.y)

	# 2) Joystick para frente: deve ANDAR, na direção da câmera, sem girar a câmera.
	var start := player.global_position
	var yaw0 := rig.yaw
	var stick := Vector2(160.0, vs.y - 170.0)
	_touch(0, stick, true)
	_drag(0, stick + Vector2(0, -70), Vector2(0, -70))
	await _frames(90)
	var disp := player.global_position - start
	var flat := Vector3(disp.x, 0, disp.z)
	var fwd := Vector3(-sin(rig.yaw), 0, -cos(rig.yaw))
	print("PLAYTEST: deslocamento com joystick = %.2f m" % flat.length())
	if flat.length() < 3.5:
		fails.append("Joystick não moveu o jogador (%.2f m em 1,5 s)" % flat.length())
	elif flat.normalized().dot(fwd) < 0.95:
		fails.append("Movimento fora da direção da câmera")
	if _angle_diff(rig.yaw, yaw0) > 0.01:
		fails.append("Câmera girou sozinha ao usar o joystick")
	var expected_yaw := atan2(flat.x, flat.z)
	if flat.length() >= 3.5 and _angle_diff(player.facing_yaw(), expected_yaw) > 0.35:
		fails.append("Personagem não está virado para onde anda")
	_touch(0, stick, false)
	await _frames(40)
	if Vector2(player.velocity.x, player.velocity.z).length() > 0.6:
		fails.append("Personagem não parou ao soltar o joystick")

	# 3) Arrastar na metade direita gira a câmera e NÃO move o personagem.
	var pos_before := player.global_position
	var yaw_before := rig.yaw
	var look_pos := Vector2(vs.x * 0.75, vs.y * 0.4)
	_touch(1, look_pos, true)
	_drag(1, look_pos + Vector2(200, 0), Vector2(200, 0))
	await _frames(5)
	_touch(1, look_pos, false)
	await _frames(10)
	if _angle_diff(rig.yaw, yaw_before) < 0.5:
		fails.append("Arrastar na direita não girou a câmera")
	if player.global_position.distance_to(pos_before) > 0.2:
		fails.append("Girar a câmera moveu o personagem")

	# 4) Depois de girar, o joystick segue a NOVA direção da câmera.
	start = player.global_position
	_touch(0, stick, true)
	_drag(0, stick + Vector2(0, -70), Vector2(0, -70))
	await _frames(60)
	disp = player.global_position - start
	flat = Vector3(disp.x, 0, disp.z)
	fwd = Vector3(-sin(rig.yaw), 0, -cos(rig.yaw))
	if flat.length() < 2.0 or flat.normalized().dot(fwd) < 0.95:
		fails.append("Após girar a câmera, o movimento não seguiu a nova direção")
	_touch(0, stick, false)
	await _frames(40)

	# 5) Multitoque: joystick + olhar ao mesmo tempo.
	start = player.global_position
	yaw_before = rig.yaw
	_touch(0, stick, true)
	_drag(0, stick + Vector2(0, -70), Vector2(0, -70))
	_touch(1, look_pos, true)
	_drag(1, look_pos + Vector2(-120, 0), Vector2(-120, 0))
	await _frames(45)
	if player.global_position.distance_to(start) < 1.5:
		fails.append("Multitoque: personagem parou ao girar a câmera")
	if _angle_diff(rig.yaw, yaw_before) < 0.3:
		fails.append("Multitoque: câmera não girou durante o movimento")
	_touch(0, stick, false)
	_touch(1, look_pos, false)
	await _frames(40)

	# 6) Pulo pelo botão da tela.
	var y0 := player.global_position.y
	var jump_c := hud.jump_button_center()
	_touch(2, jump_c, true)
	_touch(2, jump_c, false)
	var peak := y0
	for i in range(40):
		await get_tree().physics_frame
		peak = maxf(peak, player.global_position.y)
	print("PLAYTEST: altura do pulo = %.2f m" % (peak - y0))
	if peak - y0 < 0.5:
		fails.append("Botão de pulo não fez o personagem pular")

	# 7) Colisão: empurrar contra a parede de um prédio não pode atravessar.
	player.global_position = Vector3(-WALL_X + 3.0, 0.1, _probe_z)
	player.velocity = Vector3.ZERO
	rig.yaw = PI * 0.5  # frente da câmera = -X (em direção ao prédio da esquerda)
	rig.rotate_view(Vector2.ZERO)
	await _frames(5)
	_touch(0, stick, true)
	_drag(0, stick + Vector2(0, -70), Vector2(0, -70))
	await _frames(150)
	_touch(0, stick, false)
	print("PLAYTEST: x final junto à parede = %.2f (parede em %.2f)" % [player.global_position.x, -WALL_X])
	if player.global_position.x < -WALL_X - 0.02:
		fails.append("Personagem atravessou a parede do prédio")
	if player.global_position.x > -WALL_X + 1.0:
		fails.append("Teste de parede inconclusivo: personagem não chegou à parede")

	if fails.is_empty():
		print("PLAYTEST: PASS")
		get_tree().quit(0)
	else:
		for f in fails:
			print("PLAYTEST: FAIL - " + f)
		get_tree().quit(1)
