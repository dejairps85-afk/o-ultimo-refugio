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
var camera_shake_timer := 0.0
var camera_shake_strength := 0.0
var rng := RandomNumberGenerator.new()
var status_label: Label
var health_bar: ProgressBar
var enemies: Array = []
var hostile_humans: Array[Dictionary] = []
var faction_alerts: Dictionary = {}
var gunshot_noise_timer := 0.0
var gunshot_noise_position := Vector3.ZERO
var movement_noise_timer := 0.0
var movement_noise_position := Vector3.ZERO
var movement_noise_radius := 0.0
var footstep_noise_cooldown := 0.0
var environment_obstacles: Array[Dictionary] = []
var player_animation: AnimationPlayer
var player_health := 100.0
var stamina := 100.0
var sprint_enabled := false
var crouch_enabled := false
var crouch_button: Button
var player_visual_base_scale := Vector3.ONE
var dodge_requested := false
var dodge_timer := 0.0
var dodge_cooldown := 0.0
var dodge_direction := Vector3.ZERO
var stamina_bar: ProgressBar
var sprint_button: Button
var player_attack_cooldown := 0.0
var player_attack_anim_time := 0.0
var game_over := false
var game_over_label: Label
var restart_button: Button
var wallet_label: Label
var mission_label: Label
var mission_kills := 0
var mission_goal := 5
var mission_reward_claimed := false
var wave_number := 1
var wave_intermission := -1.0
var wave_label: Label
var shop_panel: PanelContainer
var shop_list: VBoxContainer
var shop_open := false
var credits := 250
var unlocked_items: Array[String] = ["character_survivor", "outfit_field", "accessory_none", "weapon_fists"]
var equipped_items := {"character": "character_survivor", "outfit": "outfit_field", "accessory": "accessory_none", "weapon": "weapon_fists", "vehicle": "vehicle_none"}
var shop_category := "personagens"
var weapon_damage := 50.0
var rifle_ammo := 30
var rifle_reserve := 120
var rifle_reload_timer := 0.0
var rifle_reloading := false
var ammo_label: Label

var accessory_visual: Node3D
var outfit_tint := Color.WHITE
var vehicle: CharacterBody3D
var vehicle_active := false
var vehicle_flying := false
var vehicle_toggle_button: Button
var resource_label: Label
var wood := 0
var scrap := 0
var food := 0
var medical_supplies := 0
var resource_nodes: Array[Dictionary] = []
var collect_requested := false
var collect_cooldown := 0.0
var built_structures: Array[Dictionary] = []
var allied_survivors: Array[Dictionary] = []
var shelter_level := 0
var shelter_root: Node3D
var shelter_heal_timer := 0.0
var shelter_label: Label
var sun_light: DirectionalLight3D
var world_environment: WorldEnvironment
var world_time_seconds := 420.0
var world_day := 1
var world_clock_label: Label
var wildlife: Array[Dictionary] = []
var boat: CharacterBody3D
var boat_active := false
var boat_toggle_button: Button
var boat_speed := 0.0
var fishing_cooldown := 0.0
var wilderness_button: Button
var poi_cache_nodes: Array[Dictionary] = []
var looted_poi_ids: Array[String] = []

func _ready() -> void:
	rng.randomize()
	_setup_environment()
	_build_terrain()
	_build_river()
	_scatter_environment()
	_spawn_points_of_interest()
	_build_abandoned_town()
	_spawn_wildlife()
	_build_boat()
	_build_player()
	_spawn_infected()
	_spawn_city_horde()
	_spawn_hostile_factions()
	_spawn_allied_survivors()
	_load_profile()
	_load_saved_buildings()
	_apply_player_customization()
	_build_vehicle()
	_build_hud()

func _setup_environment() -> void:
	world_environment = WorldEnvironment.new()
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
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.10
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.54, 0.48)
	env.ambient_light_energy = 0.65
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.fog_enabled = true
	env.fog_light_color = Color(0.48, 0.53, 0.46)
	env.fog_density = 0.0048
	env.fog_sky_affect = 0.45
	world_environment.environment = env
	add_child(world_environment)

	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-42, -28, 0)
	sun_light.light_color = Color(1.0, 0.88, 0.68)
	sun_light.light_energy = 1.35
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_max_distance = 90.0
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun_light)

func _base_height_at(x: float, z: float) -> float:
	return sin(x * 0.035) * 1.6 + cos(z * 0.028) * 1.25 + sin((x + z) * 0.018) * 2.0 + cos(x * 0.075) * sin(z * 0.061) * 0.55

func _river_center_x(z: float) -> float:
	return 34.0 + sin(z * 0.035) * 10.0 + sin(z * 0.012) * 5.0

func _is_in_river(x: float, z: float, margin := 0.0) -> bool:
	return absf(x - _river_center_x(z)) < 5.0 + margin

func _river_surface_y(z: float) -> float:
	return _base_height_at(_river_center_x(z), z) - 0.22

func _height_at(x: float, z: float) -> float:
	var base := _base_height_at(x, z)
	var distance := absf(x - _river_center_x(z))
	if distance < 5.0:
		var depth := 1.35 * pow(1.0 - distance / 5.0, 1.7)
		return base - depth
	return base

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
	var ground_diffuse := "res://assets/textures/forest_ground_06/Diffuse_1k_jpg.jpg"
	var ground_normal := "res://assets/textures/forest_ground_06/nor_gl_1k_jpg.jpg"
	var ground_roughness := "res://assets/textures/forest_ground_06/Rough_1k_jpg.jpg"
	if ResourceLoader.exists(ground_diffuse):
		mat.albedo_texture = load(ground_diffuse) as Texture2D
	if ResourceLoader.exists(ground_normal):
		mat.normal_enabled = true
		mat.normal_texture = load(ground_normal) as Texture2D
	if ResourceLoader.exists(ground_roughness):
		mat.roughness_texture = load(ground_roughness) as Texture2D
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
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

func _build_river() -> void:
	# Leito sinuoso esculpido no terreno; a lâmina d'água acompanha a altura natural do vale.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var segments := 180
	for i in range(segments + 1):
		var z := -108.0 + 216.0 * float(i) / float(segments)
		var center_x := _river_center_x(z)
		var water_y := _river_surface_y(z)
		vertices.append(Vector3(center_x - 4.15, water_y, z))
		vertices.append(Vector3(center_x + 4.15, water_y, z))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, float(i) / 8.0))
		uvs.append(Vector2(1.0, float(i) / 8.0))
	for i in range(segments):
		var a := i * 2
		indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var river_mesh := ArrayMesh.new()
	river_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.035, 0.20, 0.25, 0.88)
	water_material.metallic = 0.22
	water_material.roughness = 0.16
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	water_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	river_mesh.surface_set_material(0, water_material)
	var water := MeshInstance3D.new()
	water.name = "SinuousRiver"
	water.mesh = river_mesh
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	_build_river_bridge()

func _build_river_bridge() -> void:
	var bridge := StaticBody3D.new()
	bridge.name = "RiverCrossingBridge"
	var z := 14.0
	var center_x := _river_center_x(z)
	bridge.position = Vector3(center_x, _river_surface_y(z) + 0.48, z)
	var deck := MeshInstance3D.new()
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(12.2, 0.22, 1.7)
	deck.mesh = deck_mesh
	deck.material_override = _make_material(Color(0.30, 0.19, 0.11), 0.88)
	bridge.add_child(deck)
	var deck_collision := CollisionShape3D.new()
	var deck_shape := BoxShape3D.new()
	deck_shape.size = deck_mesh.size
	deck_collision.shape = deck_shape
	deck_collision.position.y = 0.08
	bridge.add_child(deck_collision)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(12.2, 0.16, 0.12)
		rail.mesh = rail_mesh
		rail.position = Vector3(0, 0.68, side * 0.78)
		rail.material_override = _make_material(Color(0.22, 0.15, 0.09))
		bridge.add_child(rail)
		for x_offset in [-5.5, 5.5]:
			var post := MeshInstance3D.new()
			var post_mesh := BoxMesh.new()
			post_mesh.size = Vector3(0.16, 0.9, 0.16)
			post.mesh = post_mesh
			post.position = Vector3(x_offset, 0.34, side * 0.78)
			post.material_override = _make_material(Color(0.20, 0.13, 0.08))
			bridge.add_child(post)
	add_child(bridge)

func _spawn_wildlife() -> void:
	var species := ["CERVO", "JAVALI", "COELHO"]
	for i in range(12):
		var kind: String = species[i % species.size()]
		var x := rng.randf_range(-88.0, 88.0)
		var z := rng.randf_range(-88.0, 88.0)
		if Vector2(x, z).length() < 18.0 or _is_in_river(x, z, 2.0):
			x = -42.0 + rng.randf_range(-18.0, 18.0)
			z = rng.randf_range(-78.0, 78.0)
		var animal := Node3D.new()
		animal.name = "Wildlife_" + kind + "_" + str(i)
		animal.position = Vector3(x, _height_at(x, z), z)
		var body := MeshInstance3D.new()
		var body_mesh := SphereMesh.new()
		body_mesh.radius = 0.55 if kind != "COELHO" else 0.25
		body_mesh.height = 0.72 if kind != "COELHO" else 0.38
		body.mesh = body_mesh
		body.position.y = 0.72 if kind != "COELHO" else 0.32
		body.scale = Vector3(1.0, 0.78, 1.45)
		var animal_color := Color(0.48, 0.30, 0.16) if kind == "CERVO" else Color(0.24, 0.19, 0.14) if kind == "JAVALI" else Color(0.58, 0.48, 0.38)
		body.material_override = _make_material(animal_color, 0.92)
		animal.add_child(body)
		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.22 if kind != "COELHO" else 0.14
		head_mesh.height = head_mesh.radius * 2.0
		head.mesh = head_mesh
		head.position = Vector3(0.0, 1.0 if kind != "COELHO" else 0.48, -0.62 if kind != "COELHO" else -0.30)
		head.material_override = _make_material(animal_color.lightened(0.12), 0.9)
		animal.add_child(head)
		for leg_x in [-0.28, 0.28]:
			for leg_z in [-0.34, 0.34]:
				var leg := MeshInstance3D.new()
				var leg_mesh := CylinderMesh.new()
				leg_mesh.top_radius = 0.055 if kind != "COELHO" else 0.035
				leg_mesh.bottom_radius = leg_mesh.top_radius
				leg_mesh.height = 0.58 if kind != "COELHO" else 0.28
				leg.mesh = leg_mesh
				leg.position = Vector3(leg_x, 0.30 if kind != "COELHO" else 0.13, leg_z)
				leg.material_override = _make_material(animal_color.darkened(0.25), 0.95)
				animal.add_child(leg)
		add_child(animal)
		wildlife.append({"node": animal, "kind": kind, "speed": 3.8 if kind == "JAVALI" else 5.4 if kind == "CERVO" else 2.8, "timer": rng.randf_range(1.0, 4.0), "attack_timer": rng.randf_range(0.4, 1.2), "direction": Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()})

func _update_wildlife(delta: float) -> void:
	if not is_instance_valid(player):
		return
	for i in range(wildlife.size()):
		var data: Dictionary = wildlife[i]
		var animal := data["node"] as Node3D
		if not is_instance_valid(animal):
			continue
		var kind := str(data["kind"])
		var direction: Vector3 = data["direction"]
		var distance := animal.global_position.distance_to(player.global_position)
		var flee_radius := 15.0 if kind == "CERVO" else 9.0 if kind == "COELHO" else 0.0
		var fleeing := distance < flee_radius
		var charging := kind == "JAVALI" and distance < 7.0 and not boat_active
		data["attack_timer"] = maxf(0.0, float(data.get("attack_timer", 0.0)) - delta)
		if charging:
			direction = Vector3(player.global_position.x - animal.global_position.x, 0, player.global_position.z - animal.global_position.z).normalized()
			if distance < 1.65 and float(data["attack_timer"]) <= 0.0:
				player_health = maxf(0.0, player_health - 8.0)
				data["attack_timer"] = 1.5
				if is_instance_valid(status_label):
					status_label.text = "JAVALI ATACOU! AFASTE-SE OU REVIDE"
		elif fleeing:
			direction = Vector3(animal.global_position.x - player.global_position.x, 0, animal.global_position.z - player.global_position.z).normalized()
			data["timer"] = 2.0
		else:
			data["timer"] = float(data["timer"]) - delta
			if float(data["timer"]) <= 0.0:
				direction = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
				data["timer"] = rng.randf_range(2.0, 5.0)
		var speed_factor := 1.8 if charging else 1.65 if fleeing else 0.35
		var speed := float(data["speed"]) * speed_factor
		animal.position.x += direction.x * speed * delta
		animal.position.z += direction.z * speed * delta
		animal.position.x = clampf(animal.position.x, -100.0, 100.0)
		animal.position.z = clampf(animal.position.z, -100.0, 100.0)
		if _is_in_river(animal.position.x, animal.position.z, 1.0):
			animal.position.x += signf(animal.position.x - _river_center_x(animal.position.z)) * 2.0
		animal.position.y = _height_at(animal.position.x, animal.position.z)
		if direction.length() > 0.1:
			animal.rotation.y = lerp_angle(animal.rotation.y, atan2(-direction.x, -direction.z), delta * 3.0)
		wildlife[i] = data

func _build_boat() -> void:
	boat = CharacterBody3D.new()
	boat.name = "RiverBoat"
	var start_z := -28.0
	boat.position = Vector3(_river_center_x(start_z), _river_surface_y(start_z) + 0.16, start_z)
	var hull := MeshInstance3D.new()
	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(1.65, 0.42, 3.8)
	hull.mesh = hull_mesh
	hull.position.y = 0.0
	hull.material_override = _make_material(Color(0.30, 0.19, 0.10), 0.55)
	boat.add_child(hull)
	var bow := MeshInstance3D.new()
	var bow_mesh := PrismMesh.new()
	bow_mesh.size = Vector3(1.55, 0.38, 1.15)
	bow.mesh = bow_mesh
	bow.position = Vector3(0, 0.02, -2.0)
	bow.material_override = _make_material(Color(0.36, 0.24, 0.13), 0.5)
	boat.add_child(bow)
	var seat := MeshInstance3D.new()
	var seat_mesh := BoxMesh.new()
	seat_mesh.size = Vector3(0.72, 0.14, 0.48)
	seat.mesh = seat_mesh
	seat.position = Vector3(0, 0.27, 0.25)
	seat.material_override = _make_material(Color(0.12, 0.14, 0.12))
	boat.add_child(seat)
	add_child(boat)

func _toggle_boat() -> void:
	if not is_instance_valid(boat):
		return
	if not boat_active:
		if player.global_position.distance_to(boat.global_position) > 5.0:
			status_label.text = "APROXIME-SE DO BARCO NA MARGEM DO RIO"
			return
		player.collision_layer = 0
		player.collision_mask = 0
		player.velocity = Vector3.ZERO
		remove_child(player)
		boat.add_child(player)
		player.position = Vector3(0, 0.65, 0.35)
		var visual := player.get_node_or_null("SurvivorVisual") as Node3D
		if visual:
			visual.visible = true
		boat_active = true
		boat_toggle_button.text = "SAIR DO BARCO"
		status_label.text = "BARCO: USE O JOYSTICK PARA NAVEGAR"
	else:
		boat.remove_child(player)
		add_child(player)
		player.global_position = boat.global_position + boat.global_transform.basis.x * 2.0 + Vector3.UP * 0.3
		player.collision_layer = 1
		player.collision_mask = 1
		player.velocity = Vector3.ZERO
		boat_active = false
		boat_toggle_button.text = "USAR BARCO"
		status_label.text = "VOCÊ DESEMBARCOU"

func _update_boat(delta: float) -> void:
	if not boat_active or not is_instance_valid(boat):
		return
	var steering := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _touch_move.length() > 0.08:
		steering = _touch_move
	boat_speed = move_toward(boat_speed, -steering.y * 9.0, 8.0 * delta)
	boat.rotation.y -= steering.x * delta * 0.9 * signf(boat_speed) if absf(boat_speed) > 0.1 else 0.0
	var next_z := clampf(boat.position.z + (-boat_speed * cos(boat.rotation.y)) * delta, -105.0, 105.0)
	var next_x := boat.position.x + (-boat_speed * sin(boat.rotation.y)) * delta
	var river_x := _river_center_x(next_z)
	boat.position.x = lerpf(next_x, river_x, 0.18)
	boat.position.z = next_z
	boat.position.y = _river_surface_y(next_z) + 0.16
	boat.velocity = Vector3.ZERO

func _make_material(color: Color, roughness := 0.9, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _scatter_environment() -> void:
	var tree_scene: PackedScene = load("res://assets/models/tree_small_02/tree_small_02_mobile.glb") if ResourceLoader.exists("res://assets/models/tree_small_02/tree_small_02_mobile.glb") else null
	var rock_scene: PackedScene = load("res://assets/models/rock_moss_set_01/rock_moss_set_01_mobile.glb") if ResourceLoader.exists("res://assets/models/rock_moss_set_01/rock_moss_set_01_mobile.glb") else null
	var fern_scene: PackedScene = load("res://assets/models/fern_02/fern_02_mobile.glb") if ResourceLoader.exists("res://assets/models/fern_02/fern_02_mobile.glb") else null
	var stump_scene: PackedScene = load("res://assets/models/tree_stump_01/tree_stump_01_mobile.glb") if ResourceLoader.exists("res://assets/models/tree_stump_01/tree_stump_01_mobile.glb") else null
	for i in range(100):
		var x := rng.randf_range(-98, 98)
		var z := rng.randf_range(-98, 98)
		if Vector2(x, z).length() < 12.0 or _is_in_river(x, z, 2.0):
			continue
		var instance: Node3D
		if tree_scene:
			instance = tree_scene.instantiate()
			instance.scale = Vector3.ONE * rng.randf_range(0.72, 1.25)
		else:
			instance = _procedural_tree()
		instance.position = Vector3(x, _height_at(x, z), z)
		instance.rotation.y = rng.randf_range(0, TAU)
		environment_obstacles.append({"position": Vector2(x, z), "radius": 1.45 * instance.scale.x})
		_add_tree_collision(instance)
		add_child(instance)
	for i in range(42):
		var x := rng.randf_range(-96, 96)
		var z := rng.randf_range(-96, 96)
		if Vector2(x, z).length() < 9.0 or _is_in_river(x, z, 2.0):
			continue
		var instance: Node3D
		if rock_scene:
			instance = rock_scene.instantiate()
			instance.scale = Vector3.ONE * rng.randf_range(0.45, 1.2)
		else:
			instance = _procedural_rock()
		instance.position = Vector3(x, _height_at(x, z), z)
		instance.rotation.y = rng.randf_range(0, TAU)
		environment_obstacles.append({"position": Vector2(x, z), "radius": 1.0 * instance.scale.x})
		_add_rock_collision(instance)
		add_child(instance)
	for i in range(18):
		if stump_scene:
			var x := rng.randf_range(-92, 92)
			var z := rng.randf_range(-92, 92)
			if Vector2(x, z).length() > 13.0 and not _is_in_river(x, z, 2.0):
				var stump := stump_scene.instantiate() as Node3D
				stump.scale = Vector3.ONE * rng.randf_range(0.7, 1.15)
				stump.position = Vector3(x, _height_at(x, z), z)
				stump.rotation.y = rng.randf_range(0.0, TAU)
				environment_obstacles.append({"position": Vector2(x, z), "radius": 0.85 * stump.scale.x})
				_add_stump_collision(stump)
				add_child(stump)
	for i in range(80):
		var x := rng.randf_range(-95, 95)
		var z := rng.randf_range(-95, 95)
		if Vector2(x, z).length() < 7.0 or _is_in_river(x, z, 1.5):
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
	_spawn_resource_nodes()

func _spawn_resource_nodes() -> void:
	var resource_types := ["wood", "scrap", "food"]
	for i in range(24):
		var kind: String = resource_types[i % resource_types.size()]
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(13.0, 88.0)
		var x := cos(angle) * distance
		var z := sin(angle) * distance
		var node := Node3D.new()
		node.name = "Resource_" + kind
		node.position = Vector3(x, _height_at(x, z), z)
		var mesh_node := MeshInstance3D.new()
		if kind == "wood":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.42, 0.34, 0.85)
			mesh_node.mesh = mesh
			mesh_node.position.y = 0.22
			mesh_node.rotation.y = rng.randf_range(0.0, TAU)
			mesh_node.material_override = _make_material(Color(0.38, 0.22, 0.11))
		elif kind == "scrap":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.48, 0.42, 0.38)
			mesh_node.mesh = mesh
			mesh_node.position.y = 0.24
			mesh_node.rotation_degrees = Vector3(12, rng.randf_range(0.0, 360.0), 8)
			mesh_node.material_override = _make_material(Color(0.32, 0.37, 0.36), 0.48)
		else:
			var mesh := SphereMesh.new()
			mesh.radius = 0.22
			mesh.height = 0.42
			mesh_node.mesh = mesh
			mesh_node.position.y = 0.25
			mesh_node.material_override = _make_material(Color(0.55, 0.24, 0.16))
		node.add_child(mesh_node)
		add_child(node)
		resource_nodes.append({"node": node, "kind": kind, "amount": rng.randi_range(2, 4)})


func _build_abandoned_town() -> void:
	var town := Node3D.new()
	town.name = "AbandonedTown_EastDistrict"
	var center := Vector2(72.0, -66.0)
	town.position = Vector3(center.x, 0.0, center.y)
	add_child(town)
	var road_material := _make_material(Color(0.12, 0.13, 0.12), 0.98)
	var curb_material := _make_material(Color(0.34, 0.34, 0.29), 0.95)
	var road_x := MeshInstance3D.new()
	var road_x_mesh := BoxMesh.new()
	road_x_mesh.size = Vector3(52.0, 0.12, 5.2)
	road_x.mesh = road_x_mesh
	road_x.position = Vector3(0.0, _height_at(center.x, center.y) + 0.07, 0.0)
	road_x.material_override = road_material
	town.add_child(road_x)
	var road_z := MeshInstance3D.new()
	var road_z_mesh := BoxMesh.new()
	road_z_mesh.size = Vector3(5.2, 0.12, 52.0)
	road_z.mesh = road_z_mesh
	road_z.position = road_x.position
	road_z.material_override = road_material
	town.add_child(road_z)
	for offset in [-18.0, 18.0]:
		var side_road := MeshInstance3D.new()
		var side_mesh := BoxMesh.new()
		side_mesh.size = Vector3(46.0, 0.10, 3.2)
		side_road.mesh = side_mesh
		side_road.position = Vector3(0.0, road_x.position.y + 0.01, offset)
		side_road.material_override = road_material
		town.add_child(side_road)
		var cross_road := MeshInstance3D.new()
		var cross_mesh := BoxMesh.new()
		cross_mesh.size = Vector3(3.2, 0.10, 46.0)
		cross_road.mesh = cross_mesh
		cross_road.position = Vector3(offset, road_x.position.y + 0.01, 0.0)
		cross_road.material_override = road_material
		town.add_child(cross_road)
	var building_specs := [
		{"p": Vector3(-13.0, 0.0, -13.0), "s": Vector3(10.0, 7.0, 9.0), "c": Color(0.43, 0.39, 0.31), "n": "RESIDÊNCIA"},
		{"p": Vector3(13.0, 0.0, -13.0), "s": Vector3(11.0, 10.0, 9.0), "c": Color(0.36, 0.39, 0.38), "n": "CLÍNICA"},
		{"p": Vector3(-13.0, 0.0, 13.0), "s": Vector3(12.0, 8.0, 10.0), "c": Color(0.39, 0.31, 0.25), "n": "MERCADO"},
		{"p": Vector3(13.0, 0.0, 13.0), "s": Vector3(9.0, 6.0, 9.0), "c": Color(0.42, 0.38, 0.32), "n": "OFICINA"},
		{"p": Vector3(-21.0, 0.0, 0.0), "s": Vector3(7.0, 5.0, 8.0), "c": Color(0.34, 0.37, 0.34), "n": "GARAGEM"},
		{"p": Vector3(21.0, 0.0, 0.0), "s": Vector3(7.0, 8.0, 8.0), "c": Color(0.38, 0.36, 0.31), "n": "DELEGACIA"}
	]
	for spec in building_specs:
		var building_position: Vector3 = spec["p"]
		var dimensions: Vector3 = spec["s"]
		var ground_y := _height_at(center.x + building_position.x, center.y + building_position.z)
		var building := StaticBody3D.new()
		building.name = str(spec["n"]).replace(" ", "_")
		building.position = Vector3(building_position.x, ground_y + dimensions.y * 0.5, building_position.z)
		var is_explorable := str(spec["n"]) in ["RESIDÊNCIA", "CLÍNICA", "MERCADO", "OFICINA", "DELEGACIA"]
		var wall_material := _make_material(spec["c"], 0.92)
		if is_explorable:
			var floor_mesh := BoxMesh.new()
			floor_mesh.size = Vector3(dimensions.x - 0.25, 0.18, dimensions.z - 0.25)
			var floor_visual := MeshInstance3D.new()
			floor_visual.mesh = floor_mesh
			floor_visual.position.y = -dimensions.y * 0.5 + 0.12
			floor_visual.material_override = _make_material(Color(0.25, 0.24, 0.20), 0.98)
			building.add_child(floor_visual)
			var floor_collision := CollisionShape3D.new()
			var floor_shape := BoxShape3D.new()
			floor_shape.size = floor_mesh.size
			floor_collision.shape = floor_shape
			floor_collision.position = floor_visual.position
			building.add_child(floor_collision)
			var wall_height := dimensions.y - 0.65
			var wall_y := -dimensions.y * 0.5 + wall_height * 0.5 + 0.18
			_add_town_wall(building, Vector3(dimensions.x, wall_height, 0.24), Vector3(0.0, wall_y, dimensions.z * 0.5), wall_material)
			_add_town_wall(building, Vector3(0.24, wall_height, dimensions.z), Vector3(-dimensions.x * 0.5, wall_y, 0.0), wall_material)
			_add_town_wall(building, Vector3(0.24, wall_height, dimensions.z), Vector3(dimensions.x * 0.5, wall_y, 0.0), wall_material)
			var doorway_width := 2.25
			var front_segment := (dimensions.x - doorway_width) * 0.5
			for side in [-1.0, 1.0]:
				_add_town_wall(building, Vector3(front_segment, wall_height, 0.24), Vector3(side * (doorway_width * 0.5 + front_segment * 0.5), wall_y, -dimensions.z * 0.5), wall_material)
			var lintel := MeshInstance3D.new()
			var lintel_mesh := BoxMesh.new()
			lintel_mesh.size = Vector3(doorway_width, 0.35, 0.28)
			lintel.mesh = lintel_mesh
			lintel.position = Vector3(0.0, wall_y + wall_height * 0.5 - 0.12, -dimensions.z * 0.5)
			lintel.material_override = wall_material
			building.add_child(lintel)
			var divider_width := dimensions.x * 0.52
			_add_town_wall(building, Vector3(divider_width, wall_height * 0.72, 0.18), Vector3(-dimensions.x * 0.16, wall_y - 0.12, dimensions.z * 0.12), _make_material(Color(0.29, 0.27, 0.22), 0.98))
			var interior_light := OmniLight3D.new()
			interior_light.position = Vector3(0.0, dimensions.y * 0.5 - 0.65, 0.0)
			interior_light.light_color = Color(0.82, 0.72, 0.48)
			interior_light.light_energy = 0.48
			interior_light.omni_range = 8.5
			building.add_child(interior_light)
			if str(spec["n"]) == "CLÍNICA":
				_add_town_furniture(building, Vector3(2.5, 0.72, 0.85), Vector3(-2.8, -dimensions.y * 0.5 + 0.55, 1.6), Color(0.63, 0.64, 0.58))
				_add_town_furniture(building, Vector3(1.7, 0.95, 0.65), Vector3(2.8, -dimensions.y * 0.5 + 0.65, 1.8), Color(0.34, 0.43, 0.40))
			elif str(spec["n"]) == "MERCADO":
				for shelf_x in [-3.6, 0.0, 3.6]:
					_add_town_furniture(building, Vector3(0.72, 1.65, 2.5), Vector3(shelf_x, -dimensions.y * 0.5 + 0.95, 1.0), Color(0.35, 0.25, 0.15))
			elif str(spec["n"]) == "RESIDÊNCIA":
				_add_town_furniture(building, Vector3(2.4, 0.55, 1.5), Vector3(-2.8, -dimensions.y * 0.5 + 0.45, 1.6), Color(0.39, 0.31, 0.25))
				_add_town_furniture(building, Vector3(1.2, 0.72, 0.8), Vector3(2.8, -dimensions.y * 0.5 + 0.52, 1.8), Color(0.29, 0.24, 0.19))
			elif str(spec["n"]) == "OFICINA":
				_add_town_furniture(building, Vector3(3.2, 0.95, 1.1), Vector3(-2.0, -dimensions.y * 0.5 + 0.65, 1.5), Color(0.24, 0.27, 0.27))
				_add_town_furniture(building, Vector3(0.65, 1.8, 0.65), Vector3(3.2, -dimensions.y * 0.5 + 1.0, 1.7), Color(0.34, 0.29, 0.21))
			else:
				_add_town_furniture(building, Vector3(2.2, 0.82, 1.0), Vector3(-2.4, -dimensions.y * 0.5 + 0.62, 1.4), Color(0.22, 0.24, 0.23))
				_add_town_furniture(building, Vector3(1.0, 1.2, 0.45), Vector3(2.8, -dimensions.y * 0.5 + 0.8, 1.7), Color(0.28, 0.30, 0.31))
		else:
			var shell := MeshInstance3D.new()
			var shell_mesh := BoxMesh.new()
			shell_mesh.size = dimensions
			shell.mesh = shell_mesh
			shell.material_override = wall_material
			building.add_child(shell)
			var collision := CollisionShape3D.new()
			var collision_shape := BoxShape3D.new()
			collision_shape.size = dimensions
			collision.shape = collision_shape
			building.add_child(collision)
		var roof := MeshInstance3D.new()
		var roof_mesh := BoxMesh.new()
		roof_mesh.size = Vector3(dimensions.x + 0.5, 0.28, dimensions.z + 0.5)
		roof.mesh = roof_mesh
		roof.position.y = dimensions.y * 0.5 + 0.12
		roof.material_override = _make_material(Color(0.17, 0.19, 0.18), 0.86)
		building.add_child(roof)
		for side in [-1.0, 1.0]:
			var window := MeshInstance3D.new()
			var window_mesh := BoxMesh.new()
			window_mesh.size = Vector3(1.25, 1.0, 0.08)
			window.mesh = window_mesh
			window.position = Vector3(side * dimensions.x * 0.24, 0.5, -dimensions.z * 0.5 - 0.045)
			window.material_override = _make_material(Color(0.10, 0.17, 0.18), 0.25)
			building.add_child(window)
		town.add_child(building)
		if is_explorable:
			var cache_id := "east_" + str(spec["n"]).to_lower().replace("í", "i")
			var cache_position := Vector3(center.x + building_position.x, ground_y, center.y + building_position.z)
			_add_town_loot_cache(cache_id, str(spec["n"]), cache_position)
		var sign := Label3D.new()
		sign.text = str(spec["n"])
		sign.position = Vector3(building_position.x, ground_y + dimensions.y + 1.5, building_position.z)
		sign.font_size = 26
		sign.modulate = Color(0.85, 0.79, 0.62)
		town.add_child(sign)
	for lamp_x in [-23.0, 0.0, 23.0]:
		for lamp_z in [-23.0, 0.0, 23.0]:
			if absf(lamp_x) < 1.0 and absf(lamp_z) < 1.0:
				continue
			var lamp := Node3D.new()
			lamp.position = Vector3(lamp_x, _height_at(center.x + lamp_x, center.y + lamp_z), lamp_z)
			var pole := MeshInstance3D.new()
			var pole_mesh := CylinderMesh.new()
			pole_mesh.top_radius = 0.07
			pole_mesh.bottom_radius = 0.11
			pole_mesh.height = 4.6
			pole.mesh = pole_mesh
			pole.position.y = 2.3
			pole.material_override = _make_material(Color(0.16, 0.17, 0.16), 0.7)
			lamp.add_child(pole)
			var bulb := MeshInstance3D.new()
			var bulb_mesh := SphereMesh.new()
			bulb_mesh.radius = 0.24
			bulb_mesh.height = 0.42
			bulb.mesh = bulb_mesh
			bulb.position.y = 4.55
			var bulb_material := StandardMaterial3D.new()
			bulb_material.albedo_color = Color(1.0, 0.72, 0.35)
			bulb_material.emission_enabled = true
			bulb_material.emission = Color(1.0, 0.55, 0.22)
			bulb_material.emission_energy_multiplier = 1.4
			bulb.material_override = bulb_material
			lamp.add_child(bulb)
			if (lamp_x == 0.0 and absf(lamp_z) > 1.0) or (lamp_z == 0.0 and absf(lamp_x) > 1.0):
				var street_light := OmniLight3D.new()
				street_light.position = Vector3(0.0, 4.35, 0.0)
				street_light.light_color = Color(1.0, 0.66, 0.36)
				street_light.light_energy = 0.55
				street_light.omni_range = 10.0
				street_light.shadow_enabled = false
				lamp.add_child(street_light)
			town.add_child(lamp)
	_add_abandoned_vehicle(town, Vector3(-7.0, _height_at(center.x - 7.0, center.y - 27.0), -27.0), -0.18)
	_add_abandoned_vehicle(town, Vector3(8.0, _height_at(center.x + 8.0, center.y + 27.0), 27.0), 2.85)
	for debris_data in [
		{"p": Vector3(-25.0, 0.25, -7.0), "s": Vector3(1.4, 0.5, 0.8)},
		{"p": Vector3(25.0, 0.18, 8.0), "s": Vector3(1.0, 0.36, 1.1)},
		{"p": Vector3(-8.0, 0.2, 25.0), "s": Vector3(1.6, 0.4, 0.65)}
	]:
		var debris := MeshInstance3D.new()
		var debris_mesh := BoxMesh.new()
		debris_mesh.size = debris_data["s"]
		debris.mesh = debris_mesh
		debris.position = debris_data["p"]
		debris.rotation.y = rng.randf_range(-0.8, 0.8)
		debris.material_override = _make_material(Color(0.25, 0.24, 0.20), 0.98)
		town.add_child(debris)
	var road_marking_material := _make_material(Color(0.62, 0.52, 0.30), 0.98)
	for mark in range(-22, 23, 4):
		var center_line := MeshInstance3D.new()
		var center_line_mesh := BoxMesh.new()
		center_line_mesh.size = Vector3(1.8, 0.025, 0.10)
		center_line.mesh = center_line_mesh
		center_line.position = Vector3(float(mark), road_x.position.y + 0.085, 0.0)
		center_line.material_override = road_marking_material
		town.add_child(center_line)
		var cross_line := MeshInstance3D.new()
		var cross_line_mesh := BoxMesh.new()
		cross_line_mesh.size = Vector3(0.10, 0.025, 1.8)
		cross_line.mesh = cross_line_mesh
		cross_line.position = Vector3(0.0, road_x.position.y + 0.085, float(mark))
		cross_line.material_override = road_marking_material
		town.add_child(cross_line)
	for side in [-1.0, 1.0]:
		var sidewalk := MeshInstance3D.new()
		var sidewalk_mesh := BoxMesh.new()
		sidewalk_mesh.size = Vector3(50.0, 0.16, 1.05)
		sidewalk.mesh = sidewalk_mesh
		sidewalk.position = Vector3(0.0, road_x.position.y + 0.02, side * 3.2)
		sidewalk.material_override = curb_material
		town.add_child(sidewalk)
		var vertical_walk := MeshInstance3D.new()
		var vertical_mesh := BoxMesh.new()
		vertical_mesh.size = Vector3(1.05, 0.16, 50.0)
		vertical_walk.mesh = vertical_mesh
		vertical_walk.position = Vector3(side * 3.2, road_x.position.y + 0.02, 0.0)
		vertical_walk.material_override = curb_material
		town.add_child(vertical_walk)
	var town_label := Label3D.new()
	town_label.text = "DISTRITO LESTE  •  ZONA DE RISCO"
	town_label.position = Vector3(0.0, 5.0, -27.0)
	town_label.font_size = 38
	town_label.modulate = Color(0.88, 0.48, 0.34)
	town.add_child(town_label)



func _add_town_furniture(parent: Node3D, item_size: Vector3, item_position: Vector3, item_color: Color) -> void:
	var item_body := StaticBody3D.new()
	item_body.position = item_position
	var item_mesh := BoxMesh.new()
	item_mesh.size = item_size
	var item_visual := MeshInstance3D.new()
	item_visual.mesh = item_mesh
	item_visual.material_override = _make_material(item_color, 0.88)
	item_body.add_child(item_visual)
	var item_collision := CollisionShape3D.new()
	var item_shape := BoxShape3D.new()
	item_shape.size = item_size
	item_collision.shape = item_shape
	item_body.add_child(item_collision)
	parent.add_child(item_body)

func _add_abandoned_vehicle(parent: Node3D, local_position: Vector3, rotation_y: float) -> void:
	var wreck := Node3D.new()
	wreck.position = local_position
	wreck.rotation.y = rotation_y
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(2.0, 0.78, 4.1)
	body.mesh = body_mesh
	body.position.y = 0.72
	body.material_override = _make_material(Color(0.20, 0.23, 0.21), 0.82)
	wreck.add_child(body)
	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.72, 0.72, 1.9)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0.0, 1.38, -0.18)
	cabin.material_override = _make_material(Color(0.10, 0.15, 0.16), 0.28)
	wreck.add_child(cabin)
	for wheel_x in [-1.02, 1.02]:
		for wheel_z in [-1.28, 1.28]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.38
			wheel_mesh.bottom_radius = 0.38
			wheel_mesh.height = 0.22
			wheel.mesh = wheel_mesh
			wheel.position = Vector3(wheel_x, 0.42, wheel_z)
			wheel.rotation.z = PI * 0.5
			wheel.material_override = _make_material(Color(0.055, 0.06, 0.055), 0.98)
			wreck.add_child(wheel)
	var wreck_collision := StaticBody3D.new()
	var wreck_shape := CollisionShape3D.new()
	var wreck_box := BoxShape3D.new()
	wreck_box.size = Vector3(2.05, 1.55, 4.15)
	wreck_shape.shape = wreck_box
	wreck_shape.position.y = 0.82
	wreck_collision.add_child(wreck_shape)
	wreck.add_child(wreck_collision)
	parent.add_child(wreck)


func _add_town_wall(parent: StaticBody3D, wall_size: Vector3, wall_position: Vector3, material: Material) -> void:
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = wall_size
	var wall_visual := MeshInstance3D.new()
	wall_visual.mesh = wall_mesh
	wall_visual.position = wall_position
	wall_visual.material_override = material
	parent.add_child(wall_visual)
	var wall_collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = wall_size
	wall_collision.shape = wall_shape
	wall_collision.position = wall_position
	parent.add_child(wall_collision)

func _add_town_loot_cache(cache_id: String, building_name: String, world_position: Vector3) -> void:
	var cache := Node3D.new()
	cache.name = "LootCache_" + cache_id
	cache.position = world_position + Vector3(0.0, 0.05, 0.0)
	var chest := MeshInstance3D.new()
	var chest_mesh := BoxMesh.new()
	chest_mesh.size = Vector3(0.95, 0.68, 0.72)
	chest.mesh = chest_mesh
	chest.position.y = 0.38
	chest.material_override = _make_material(Color(0.31, 0.22, 0.13), 0.7)
	cache.add_child(chest)
	var lid := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(1.0, 0.12, 0.76)
	lid.mesh = lid_mesh
	lid.position.y = 0.76
	lid.material_override = _make_material(Color(0.42, 0.32, 0.19), 0.58)
	cache.add_child(lid)
	add_child(cache)
	if cache_id in looted_poi_ids:
		cache.visible = false
	poi_cache_nodes.append({"id": cache_id, "name": "SUPRIMENTOS: " + building_name, "node": cache})


func _spawn_points_of_interest() -> void:
	var locations := [
		{"id": "north_camp", "name": "ACAMPAMENTO DA SERRA", "position": Vector3(-58.0, 0.0, -48.0)},
		{"id": "river_outpost", "name": "POSTO ABANDONADO", "position": Vector3(68.0, 0.0, 48.0)},
		{"id": "old_hunters", "name": "ACAMPAMENTO DE CAÇADORES", "position": Vector3(-72.0, 0.0, 62.0)}
	]
	for data in locations:
		var spot: Vector3 = data["position"]
		if _is_in_river(spot.x, spot.z, 9.0):
			continue
		var camp := Node3D.new()
		camp.name = "POI_" + str(data["id"])
		camp.position = Vector3(spot.x, _height_at(spot.x, spot.z), spot.z)
		var tent := MeshInstance3D.new()
		var tent_mesh := PrismMesh.new()
		tent_mesh.size = Vector3(4.2, 2.5, 3.2)
		tent.mesh = tent_mesh
		tent.position = Vector3(0.0, 1.15, -1.0)
		tent.material_override = _make_material(Color(0.27, 0.30, 0.22), 0.95)
		camp.add_child(tent)
		var fire_ring := MeshInstance3D.new()
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 0.72
		ring_mesh.bottom_radius = 0.72
		ring_mesh.height = 0.18
		fire_ring.mesh = ring_mesh
		fire_ring.position = Vector3(0.0, 0.12, 2.0)
		fire_ring.material_override = _make_material(Color(0.20, 0.19, 0.16))
		camp.add_child(fire_ring)
		for crate_offset in [Vector3(2.2, 0.0, 1.1), Vector3(-2.1, 0.0, -1.4)]:
			var crate := MeshInstance3D.new()
			var crate_mesh := BoxMesh.new()
			crate_mesh.size = Vector3(0.9, 0.72, 0.82)
			crate.mesh = crate_mesh
			crate.position = crate_offset + Vector3.UP * 0.38
			crate.material_override = _make_material(Color(0.30, 0.20, 0.11))
			camp.add_child(crate)
		var label := Label3D.new()
		label.text = str(data["name"])
		label.position = Vector3(0.0, 3.1, 0.0)
		label.font_size = 30
		label.modulate = Color(0.90, 0.82, 0.62)
		camp.add_child(label)
		add_child(camp)
		var cache := Node3D.new()
		cache.name = "LootCache_" + str(data["id"])
		cache.position = camp.position + Vector3(2.2, 0.0, 1.1)
		var chest := MeshInstance3D.new()
		var chest_mesh := BoxMesh.new()
		chest_mesh.size = Vector3(0.9, 0.65, 0.7)
		chest.mesh = chest_mesh
		chest.position.y = 0.36
		chest.material_override = _make_material(Color(0.42, 0.27, 0.12), 0.62)
		cache.add_child(chest)
		add_child(cache)
		if str(data["id"]) in looted_poi_ids:
			cache.visible = false
		poi_cache_nodes.append({"id": str(data["id"]), "name": str(data["name"]), "node": cache})

func _interact_with_wilderness() -> void:
	if collect_cooldown > 0.0:
		return
	var nearest_cache_index := -1
	var nearest_cache_distance := 3.6
	for i in range(poi_cache_nodes.size()):
		var cache_data: Dictionary = poi_cache_nodes[i]
		var cache_node := cache_data["node"] as Node3D
		if is_instance_valid(cache_node) and cache_node.visible:
			var cache_distance := player.global_position.distance_to(cache_node.global_position)
			if cache_distance < nearest_cache_distance:
				nearest_cache_distance = cache_distance
				nearest_cache_index = i
	if nearest_cache_index >= 0:
		var cache_data: Dictionary = poi_cache_nodes[nearest_cache_index]
		var poi_id := str(cache_data["id"])
		var found_wood := rng.randi_range(3, 7)
		var found_scrap := rng.randi_range(2, 5)
		var found_food := rng.randi_range(1, 3)
		var found_medicine := 0
		var found_ammo := 0
		match poi_id:
			"east_clinica":
				found_medicine = rng.randi_range(2, 4)
				found_food = 0
			"east_mercado":
				found_food += 4
				found_wood = 0
			"east_residencia":
				found_food += 2
				found_wood += 3
			"east_oficina":
				found_scrap += 7
				found_wood = 0
				found_ammo = 20
			"east_delegacia":
				found_scrap += 5
				credits += 75
				found_ammo = 30
			"faction_corvos":
				found_scrap += 8
				found_food += 2
				credits += 90
			"faction_porto":
				found_scrap += 11
				found_medicine += 1
				credits += 120
				found_ammo = 45
			_:
				credits += 35
		wood += found_wood
		scrap += found_scrap
		food += found_food
		medical_supplies += found_medicine
		rifle_reserve += found_ammo
		looted_poi_ids.append(poi_id)
		(cache_data["node"] as Node3D).visible = false
		_save_profile()
		collect_cooldown = 0.6
		if is_instance_valid(ammo_label):
			ammo_label.text = "MUNIÇÃO %02d / %03d" % [rifle_ammo, rifle_reserve]
		status_label.text = "%s: +%d MADEIRA, +%d SUCATA, +%d COMIDA, +%d KITS MÉDICOS, +%d MUNIÇÃO" % [str(cache_data["name"]), found_wood, found_scrap, found_food, found_medicine, found_ammo]
		return
	var nearest_resource := 999.0
	for data in resource_nodes:
		var node := data["node"] as Node3D
		if is_instance_valid(node):
			nearest_resource = minf(nearest_resource, player.global_position.distance_to(node.global_position))
	if nearest_resource < 2.8:
		_collect_nearby_resource()
		return
	var river_distance := absf(player.global_position.x - _river_center_x(player.global_position.z))
	if river_distance < 9.0 and not boat_active:
		if fishing_cooldown > 0.0:
			status_label.text = "AGUARDE PARA TENTAR PESCAR NOVAMENTE"
			return
		fishing_cooldown = 7.0
		if rng.randf() <= 0.72:
			var catch_amount := rng.randi_range(1, 2)
			food += catch_amount
			status_label.text = "PESCARIA: +%d PEIXE(S)" % catch_amount
			_save_profile()
		else:
			status_label.text = "OS PEIXES NÃO MORDERAM A ISCA. TENTE NOVAMENTE"
		return
	_collect_nearby_resource()


func _use_medkit() -> void:
	if medical_supplies <= 0:
		status_label.text = "NENHUM KIT MÉDICO DISPONÍVEL"
		return
	if player_health >= 100.0:
		status_label.text = "SUA VIDA JÁ ESTÁ COMPLETA"
		return
	medical_supplies -= 1
	player_health = minf(100.0, player_health + 45.0)
	if is_instance_valid(health_bar):
		health_bar.value = player_health
	_save_profile()
	status_label.text = "KIT MÉDICO UTILIZADO: +45 VIDA"


func _collect_nearby_resource() -> void:
	if collect_cooldown > 0.0:
		return
	var nearest_index := -1
	var nearest_distance := 2.8
	for i in range(resource_nodes.size()):
		var data := resource_nodes[i]
		var node: Node3D = data["node"]
		if not is_instance_valid(node):
			continue
		var distance := player.global_position.distance_to(node.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = i
	if nearest_index < 0:
		status_label.text = "NENHUM RECURSO PRÓXIMO"
		return
	var found: Dictionary = resource_nodes[nearest_index]
	var amount := int(found["amount"])
	match str(found["kind"]):
		"wood":
			wood += amount
		"scrap":
			scrap += amount
		"food":
			food += amount
	(found["node"] as Node3D).queue_free()
	resource_nodes.remove_at(nearest_index)
	collect_cooldown = 0.45
	_save_profile()
	status_label.text = "RECURSO COLETADO: %s +%d" % [str(found["kind"]).to_upper(), amount]

func _upgrade_shelter() -> void:
	if shelter_level >= 3:
		status_label.text = "REFÚGIO NO NÍVEL MÁXIMO"
		return
	var costs := [{"wood": 20, "scrap": 8, "food": 4}, {"wood": 28, "scrap": 15, "food": 8}, {"wood": 40, "scrap": 24, "food": 12}]
	var cost: Dictionary = costs[shelter_level]
	if wood < int(cost["wood"]) or scrap < int(cost["scrap"]) or food < int(cost["food"]):
		status_label.text = "MATERIAIS INSUFICIENTES PARA A MELHORIA"
		return
	wood -= int(cost["wood"])
	scrap -= int(cost["scrap"])
	food -= int(cost["food"])
	shelter_level += 1
	_build_shelter_visual()
	_save_profile()
	_save_buildings()
	_update_shelter_hud()
	status_label.text = "REFÚGIO APRIMORADO PARA O NÍVEL %d" % shelter_level

func _build_shelter_visual() -> void:
	if is_instance_valid(shelter_root):
		shelter_root.queue_free()
	shelter_root = Node3D.new()
	shelter_root.name = "SurvivorShelter_Level_%d" % shelter_level
	shelter_root.position = Vector3(0, _height_at(0, -8), -8)
	add_child(shelter_root)
	var post_material := _make_material(Color(0.22, 0.15, 0.09))
	var canvas_material := _make_material(Color(0.34, 0.39, 0.29))
	for x in [-2.2, 2.2]:
		for z in [-1.8, 1.8]:
			var post := MeshInstance3D.new()
			var post_mesh := BoxMesh.new()
			post_mesh.size = Vector3(0.18, 2.6, 0.18)
			post.mesh = post_mesh
			post.position = Vector3(x, 1.3, z)
			post.material_override = post_material
			shelter_root.add_child(post)
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(5.0, 0.18, 4.4)
	roof.mesh = roof_mesh
	roof.position.y = 2.65
	roof.material_override = canvas_material
	shelter_root.add_child(roof)
	if shelter_level >= 2:
		for z in [-2.0, 2.0]:
			var wall := MeshInstance3D.new()
			var wall_mesh := BoxMesh.new()
			wall_mesh.size = Vector3(4.3, 1.45, 0.12)
			wall.mesh = wall_mesh
			wall.position = Vector3(0, 0.75, z)
			wall.material_override = _make_material(Color(0.25, 0.28, 0.21))
			shelter_root.add_child(wall)
	if shelter_level >= 3:
		var beacon := OmniLight3D.new()
		beacon.position = Vector3(0, 3.2, 0)
		beacon.light_color = Color(1.0, 0.68, 0.32)
		beacon.light_energy = 1.8
		beacon.omni_range = 13.0
		shelter_root.add_child(beacon)
		var mast := MeshInstance3D.new()
		var mast_mesh := CylinderMesh.new()
		mast_mesh.top_radius = 0.07
		mast_mesh.bottom_radius = 0.10
		mast_mesh.height = 3.4
		mast.mesh = mast_mesh
		mast.position = Vector3(0, 4.2, -1.6)
		mast.material_override = post_material
		shelter_root.add_child(mast)

func _update_shelter_hud() -> void:
	if is_instance_valid(shelter_label):
		var names := ["ACAMPAMENTO", "ABRIGO BÁSICO", "ABRIGO REFORÇADO", "REFÚGIO FORTIFICADO"]
		shelter_label.text = "%s  •  NÍVEL %d/3" % [names[shelter_level], shelter_level]

func _update_shelter_support(delta: float) -> void:
	if shelter_level <= 0 or not is_instance_valid(shelter_root) or not is_instance_valid(player):
		return
	if player.global_position.distance_to(shelter_root.global_position) > 9.0:
		return
	shelter_heal_timer = maxf(0.0, shelter_heal_timer - delta)
	if shelter_heal_timer <= 0.0 and player_health < 100.0 and food > 0:
		food -= 1
		player_health = minf(100.0, player_health + 5.0 + float(shelter_level) * 2.0)
		shelter_heal_timer = maxf(18.0 - float(shelter_level) * 3.0, 8.0)
		_save_profile()

func _build_barricade() -> void:
	if wood < 8 or scrap < 5:
		status_label.text = "PRECISA DE 8 MADEIRAS E 5 SUCATAS"
		return
	var forward := -player.global_transform.basis.z
	var build_position := player.global_position + forward * 2.8
	build_position.y = _height_at(build_position.x, build_position.z)
	var barricade := StaticBody3D.new()
	barricade.name = "PlayerBarricade"
	barricade.position = build_position
	barricade.rotation.y = player.rotation.y
	var plank := MeshInstance3D.new()
	var plank_mesh := BoxMesh.new()
	plank_mesh.size = Vector3(2.8, 1.25, 0.22)
	plank.mesh = plank_mesh
	plank.position.y = 0.68
	plank.material_override = _make_material(Color(0.30, 0.19, 0.10))
	barricade.add_child(plank)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.8, 1.25, 0.28)
	collision.shape = shape
	collision.position.y = 0.68
	barricade.add_child(collision)
	add_child(barricade)
	wood -= 8
	scrap -= 5
	built_structures.append({"x": build_position.x, "z": build_position.z, "rotation": player.rotation.y})
	_save_profile()
	_save_buildings()
	status_label.text = "BARRICADA CONSTRUÍDA: REFÚGIO FORTIFICADO"

func _community_scavenge_from_base() -> void:
	var base_position := shelter_root.global_position if is_instance_valid(shelter_root) else Vector3(0, _height_at(0, -8), -8)
	var nearest_index := -1
	var nearest_distance := 22.0
	for index in range(resource_nodes.size()):
		var data: Dictionary = resource_nodes[index]
		var node := data["node"] as Node3D
		if not is_instance_valid(node):
			continue
		var distance := Vector2(node.global_position.x - base_position.x, node.global_position.z - base_position.z).length()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	if nearest_index < 0:
		return
	var found: Dictionary = resource_nodes[nearest_index]
	var amount := int(found["amount"])
	match str(found["kind"]):
		"wood": wood += amount
		"scrap": scrap += amount
		"food": food += amount
	var resource_node := found["node"] as Node3D
	if is_instance_valid(resource_node):
		resource_node.queue_free()
	resource_nodes.remove_at(nearest_index)
	_save_profile()
	if is_instance_valid(status_label) and is_instance_valid(player) and player.global_position.distance_to(base_position) < 18.0:
		status_label.text = "DAVI RECOLHEU %d DE %s PARA A COMUNIDADE" % [amount, str(found["kind"]).to_upper()]

func _try_community_construction(builder: CharacterBody3D) -> void:
	var community_count := 0
	for structure in built_structures:
		if bool(structure.get("community", false)):
			community_count += 1
	if community_count >= 4:
		return
	if wood < 10 or scrap < 6:
		if is_instance_valid(status_label) and player.global_position.distance_to(builder.global_position) < 18.0:
			status_label.text = "DAVI PRECISA DE 10 MADEIRAS E 6 SUCATAS PARA CONSTRUIR"
		return
	var base_position := shelter_root.global_position if is_instance_valid(shelter_root) else Vector3(0, _height_at(0, -8), -8)
	var offsets := [
		{"offset": Vector3(-4.0, 0, 0), "rotation": PI * 0.5},
		{"offset": Vector3(4.0, 0, 0), "rotation": PI * 0.5},
		{"offset": Vector3(0, 0, -4.0), "rotation": 0.0},
		{"offset": Vector3(0, 0, 4.0), "rotation": 0.0}
	]
	for item in offsets:
		var candidate: Vector3 = base_position + item["offset"]
		var occupied := false
		for existing in built_structures:
			if Vector2(float(existing["x"]) - candidate.x, float(existing["z"]) - candidate.z).length() < 2.6:
				occupied = true
				break
		if occupied:
			continue
		wood -= 10
		scrap -= 6
		var rotation := float(item["rotation"])
		_spawn_community_barricade(candidate, rotation)
		built_structures.append({"x": candidate.x, "z": candidate.z, "rotation": rotation, "community": true})
		_save_profile()
		_save_buildings()
		if is_instance_valid(status_label) and player.global_position.distance_to(builder.global_position) < 18.0:
			status_label.text = "DAVI CONSTRUIU UMA DEFESA PARA O REFÚGIO"
		return

func _spawn_community_barricade(build_position: Vector3, rotation: float) -> void:
	var barricade := StaticBody3D.new()
	barricade.name = "CommunityBarricade"
	barricade.position = Vector3(build_position.x, _height_at(build_position.x, build_position.z), build_position.z)
	barricade.rotation.y = rotation
	var plank := MeshInstance3D.new()
	var plank_mesh := BoxMesh.new()
	plank_mesh.size = Vector3(2.8, 1.25, 0.22)
	plank.mesh = plank_mesh
	plank.position.y = 0.68
	plank.material_override = _make_material(Color(0.30, 0.19, 0.10))
	barricade.add_child(plank)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.8, 1.25, 0.28)
	collision.shape = shape
	collision.position.y = 0.68
	barricade.add_child(collision)
	add_child(barricade)

func _save_buildings() -> void:
	var config := ConfigFile.new()
	config.set_value("world", "barricades", built_structures)
	config.set_value("world", "shelter_level", shelter_level)
	config.set_value("world", "world_time_seconds", world_time_seconds)
	config.set_value("world", "world_day", world_day)
	config.save("user://survivor_world.cfg")

func _load_saved_buildings() -> void:
	var config := ConfigFile.new()
	if config.load("user://survivor_world.cfg") != OK:
		return
	built_structures = config.get_value("world", "barricades", [])
	shelter_level = int(config.get_value("world", "shelter_level", shelter_level))
	world_time_seconds = float(config.get_value("world", "world_time_seconds", world_time_seconds))
	world_day = int(config.get_value("world", "world_day", world_day))
	if shelter_level > 0:
		_build_shelter_visual()
	for data in built_structures:
		_spawn_community_barricade(Vector3(float(data["x"]), 0, float(data["z"])), float(data["rotation"]))

func _add_tree_collision(root: Node3D) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.48
	trunk_shape.height = 3.4
	collision.shape = trunk_shape
	collision.position.y = 1.7
	body.add_child(collision)
	root.add_child(body)

func _add_rock_collision(root: Node3D) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var rock_shape := SphereShape3D.new()
	rock_shape.radius = 0.72
	collision.shape = rock_shape
	collision.position.y = 0.48
	body.add_child(collision)
	root.add_child(body)

func _add_stump_collision(root: Node3D) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var stump_shape := CylinderShape3D.new()
	stump_shape.radius = 0.52
	stump_shape.height = 0.72
	collision.shape = stump_shape
	collision.position.y = 0.36
	body.add_child(collision)
	root.add_child(body)

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

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _fit_model_height(root: Node3D, target_height: float) -> void:
	var bounds := AABB()
	var found := false
	for mesh_node in root.find_children("*", "MeshInstance3D", true, false):
		var relative_transform: Transform3D = root.global_transform.affine_inverse() * mesh_node.global_transform
		var mesh_bounds: AABB = relative_transform * mesh_node.get_aabb()
		if not found:
			bounds = mesh_bounds
			found = true
		else:
			bounds = bounds.merge(mesh_bounds)
	if found and bounds.size.y > 0.01:
		var factor := target_height / bounds.size.y
		root.scale = Vector3.ONE * factor
		root.position.y = -bounds.position.y * factor

func _play_best_animation(anim: AnimationPlayer, keywords: Array[String]) -> void:
	if not anim:
		return
	var names := anim.get_animation_list()
	for keyword in keywords:
		for animation_name in names:
			if keyword in animation_name.to_lower():
				if anim.current_animation != animation_name:
					anim.play(animation_name)
				return
	if not names.is_empty() and anim.current_animation != names[0]:
		anim.play(names[0])

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Survivor"
	player.position = Vector3(0, _height_at(0, 0) + 1.05, 0)
	player.floor_snap_length = 0.45
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.85
	collision.shape = capsule
	collision.position.y = 0.92
	player.add_child(collision)

	var survivor_path := "res://assets/models/player/survivor-soldier.glb"
	if ResourceLoader.exists(survivor_path):
		var survivor_scene := load(survivor_path) as PackedScene
		if survivor_scene:
			var visual := survivor_scene.instantiate() as Node3D
			visual.name = "SurvivorVisual"
			player.add_child(visual)
			_fit_model_height(visual, 1.82)
			player_visual_base_scale = visual.scale
			player_animation = _find_animation_player(visual)
			_play_best_animation(player_animation, ["idle", "breath", "stand"])
	else:
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
	camera.position = Vector3(0, 2.15, 6.8)
	camera.fov = 74.0
	camera.rotation_degrees.x = -12
	camera.current = true
	camera_pivot.add_child(camera)

func _spawn_infected(count: int = 7) -> void:
	var variants := [
		"res://assets/models/infected/zombie-walker.glb",
		"res://assets/models/infected/zombie-runner.glb",
		"res://assets/models/infected/zombie-brute.glb"
	]
	for i in range(count):
		var variant_path: String = variants[i % variants.size()]
		if not ResourceLoader.exists(variant_path):
			continue
		var packed := load(variant_path) as PackedScene
		if not packed:
			continue
		var enemy := CharacterBody3D.new()
		enemy.name = "Infected_%02d" % i
		enemy.floor_snap_length = 0.45
		enemy.floor_max_angle = deg_to_rad(48.0)
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.34 if i % variants.size() != 2 else 0.48
		capsule.height = 1.9 if i % variants.size() != 2 else 2.15
		collision.shape = capsule
		collision.position.y = capsule.height * 0.5
		enemy.add_child(collision)
		var visual := packed.instantiate() as Node3D
		enemy.add_child(visual)
		_fit_model_height(visual, 1.9 if i % variants.size() != 2 else 2.15)
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(24.0, 42.0)
		var center := player.global_position if is_instance_valid(player) else Vector3.ZERO
		var spawn_x := center.x + cos(angle) * distance
		var spawn_z := center.z + sin(angle) * distance
		enemy.position = Vector3(spawn_x, _height_at(spawn_x, spawn_z) + 0.08, spawn_z)
		enemy.rotation.y = rng.randf_range(0.0, TAU)
		add_child(enemy)
		var animator := _find_animation_player(visual)
		_play_best_animation(animator, ["idle", "walk", "move"])
		var difficulty := 1.0 + float(wave_number - 1) * 0.10
		enemies.append({"node": enemy, "anim": animator, "health": 100.0 * difficulty, "speed": rng.randf_range(1.0, 1.8) * minf(difficulty, 1.45), "attack_timer": rng.randf_range(0.4, 1.5), "stagger_timer": 0.0, "knockback": Vector3.ZERO, "alive": true})


func _build_faction_camp(camp: Dictionary) -> void:
	var center: Vector2 = camp["center"]
	var root := Node3D.new()
	root.name = "FactionCamp_" + str(camp["name"]).replace(" ", "_")
	root.position = Vector3(center.x, _height_at(center.x, center.y), center.y)
	var tent := MeshInstance3D.new()
	var tent_mesh := PrismMesh.new()
	tent_mesh.size = Vector3(5.0, 2.8, 4.0)
	tent.mesh = tent_mesh
	tent.position = Vector3(-1.8, 1.25, -1.0)
	tent.material_override = _make_material(camp["color"], 0.92)
	root.add_child(tent)
	var canopy := MeshInstance3D.new()
	var canopy_mesh := BoxMesh.new()
	canopy_mesh.size = Vector3(4.2, 0.16, 3.2)
	canopy.mesh = canopy_mesh
	canopy.position = Vector3(2.1, 2.05, 1.0)
	canopy.material_override = _make_material(Color(0.12, 0.14, 0.13), 0.88)
	root.add_child(canopy)
	# Barricadas baixas com uma abertura frontal para entrada do jogador.
	for offset in [Vector3(-4.2, 0.65, -2.8), Vector3(0.0, 0.65, -4.0), Vector3(4.2, 0.65, -2.8), Vector3(-4.2, 0.65, 2.8), Vector3(4.2, 0.65, 2.8)]:
		var barricade := MeshInstance3D.new()
		var barricade_mesh := BoxMesh.new()
		barricade_mesh.size = Vector3(2.8, 1.3, 0.42)
		barricade.mesh = barricade_mesh
		barricade.position = offset
		barricade.rotation.y = 0.0
		barricade.material_override = _make_material(Color(0.24, 0.19, 0.13), 0.95)
		root.add_child(barricade)
	var signal_post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.07
	post_mesh.bottom_radius = 0.09
	post_mesh.height = 3.2
	signal_post.mesh = post_mesh
	signal_post.position = Vector3(3.9, 1.6, 3.6)
	signal_post.material_override = _make_material(Color(0.18, 0.16, 0.12))
	root.add_child(signal_post)
	var flag := MeshInstance3D.new()
	var flag_mesh := PlaneMesh.new()
	flag_mesh.size = Vector2(1.2, 0.72)
	flag.mesh = flag_mesh
	flag.position = Vector3(3.35, 2.65, 3.6)
	flag.material_override = _make_material(camp["color"], 0.8)
	root.add_child(flag)
	add_child(root)
	var cache_id := "faction_corvos" if str(camp["name"]) == "GANGUE DOS CORVOS" else "faction_porto"
	_add_town_loot_cache(cache_id, "ESCONDERIJO: " + str(camp["name"]), Vector3(center.x + 2.8, _height_at(center.x + 2.8, center.y + 1.2), center.y + 1.2))

func _spawn_hostile_factions() -> void:
	var camps := [
		{"name":"GANGUE DOS CORVOS", "center":Vector2(48.0, -104.0), "count":3, "color":Color(0.16, 0.19, 0.22), "health":170.0},
		{"name":"FACÇÃO DO PORTO", "center":Vector2(103.0, -25.0), "count":3, "color":Color(0.34, 0.20, 0.13), "health":205.0}
	]
	for camp in camps:
		_build_faction_camp(camp)
		for i in range(int(camp["count"])):
			var human := CharacterBody3D.new()
			human.name = "Hostile_" + str(camp["name"]).replace(" ", "_") + "_" + str(i + 1)
			human.floor_snap_length = 0.45
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.34
			capsule.height = 1.82
			var collision := CollisionShape3D.new()
			collision.shape = capsule
			collision.position.y = 0.91
			human.add_child(collision)
			var body := MeshInstance3D.new()
			var body_mesh := CapsuleMesh.new()
			body_mesh.radius = 0.34
			body_mesh.height = 1.22
			body.mesh = body_mesh
			body.position.y = 0.98
			body.material_override = _make_material(camp["color"])
			human.add_child(body)
			var head := MeshInstance3D.new()
			var head_mesh := SphereMesh.new()
			head_mesh.radius = 0.22
			head_mesh.height = 0.44
			head.mesh = head_mesh
			head.position.y = 1.78
			head.material_override = _make_material(Color(0.48, 0.34, 0.25))
			human.add_child(head)
			var helmet := MeshInstance3D.new()
			var helmet_mesh := SphereMesh.new()
			helmet_mesh.radius = 0.235
			helmet_mesh.height = 0.18
			helmet.mesh = helmet_mesh
			helmet.position.y = 1.96
			helmet.material_override = _make_material(Color(0.10, 0.13, 0.12))
			human.add_child(helmet)
			var rifle := MeshInstance3D.new()
			var rifle_mesh := BoxMesh.new()
			rifle_mesh.size = Vector3(0.10, 0.11, 0.82)
			rifle.mesh = rifle_mesh
			rifle.position = Vector3(0.34, 1.20, -0.30)
			rifle.rotation_degrees.x = -7.0
			rifle.material_override = _make_material(Color(0.055, 0.065, 0.06))
			human.add_child(rifle)
			var label := Label3D.new()
			label.text = str(camp["name"])
			label.font_size = 30
			label.pixel_size = 0.006
			label.position.y = 2.35
			label.modulate = Color(1.0, 0.68, 0.48)
			human.add_child(label)
			var health_back := MeshInstance3D.new()
			var health_back_mesh := BoxMesh.new()
			health_back_mesh.size = Vector3(1.08, 0.085, 0.045)
			health_back.mesh = health_back_mesh
			health_back.position = Vector3(0.0, 2.52, 0.0)
			health_back.material_override = _make_material(Color(0.055, 0.045, 0.04))
			human.add_child(health_back)
			var health_green := _make_material(Color(0.18, 0.72, 0.24), 0.35)
			var health_orange := _make_material(Color(0.92, 0.56, 0.12), 0.35)
			var health_red := _make_material(Color(0.88, 0.12, 0.08), 0.35)
			var health_fill := MeshInstance3D.new()
			var health_fill_mesh := BoxMesh.new()
			health_fill_mesh.size = Vector3(1.0, 0.055, 0.055)
			health_fill.mesh = health_fill_mesh
			health_fill.position = Vector3(0.0, 2.52, -0.035)
			health_fill.material_override = _make_material(Color(0.72, 0.16, 0.10), 0.35)
			human.add_child(health_fill)
			var point: Vector2 = camp["center"] + Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0))
			human.position = Vector3(point.x, _height_at(point.x, point.y) + 0.08, point.y)
			add_child(human)
			hostile_humans.append({
				"node": human, "faction": str(camp["name"]), "health": float(camp["health"]), "health_mesh": health_fill, "health_green": health_green, "health_orange": health_orange, "health_red": health_red,
				"max_health": float(camp["health"]), "speed": rng.randf_range(2.0, 2.8),
				"fire_timer": rng.randf_range(0.5, 1.8), "stagger_timer": 0.0,
				"knockback": Vector3.ZERO, "alive": true,
				"camp_center": camp["center"], "squad_slot": i, "patrol_phase": rng.randf_range(0.0, TAU),
				"patrol_timer": rng.randf_range(1.5, 4.0), "patrol_target": human.global_position
			})

func _alive_hostile_count() -> int:
	var count := 0
	for hostile in hostile_humans:
		if bool(hostile["alive"]) and is_instance_valid(hostile["node"]):
			count += 1
	return count

func _spawn_bullet_trace(from_pos: Vector3, to_pos: Vector3) -> void:
	var trace := MeshInstance3D.new()
	var beam := BoxMesh.new()
	beam.size = Vector3(0.035, 0.035, maxf(0.1, from_pos.distance_to(to_pos)))
	trace.mesh = beam
	trace.material_override = _make_material(Color(1.0, 0.72, 0.32))
	add_child(trace)
	trace.global_position = (from_pos + to_pos) * 0.5
	trace.look_at(to_pos, Vector3.UP)
	get_tree().create_timer(0.09).timeout.connect(trace.queue_free)

func _has_line_of_sight(shooter: CharacterBody3D, target: CharacterBody3D) -> bool:
	if not is_instance_valid(shooter) or not is_instance_valid(target):
		return false
	var origin := shooter.global_position + Vector3(0.0, 1.28, 0.0)
	var destination := target.global_position + Vector3(0.0, 1.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(origin, destination)
	query.exclude = [shooter.get_rid()]
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return hit.get("collider") == target



func _update_hostile_factions(delta: float) -> void:
	for faction_key in faction_alerts.keys():
		var alert_data: Dictionary = faction_alerts[faction_key]
		alert_data["timer"] = maxf(0.0, float(alert_data.get("timer", 0.0)) - delta)
		faction_alerts[faction_key] = alert_data
	for hostile in hostile_humans:
		if not bool(hostile["alive"]):
			continue
		var npc := hostile["node"] as CharacterBody3D
		if not is_instance_valid(npc):
			continue
		var health_ratio := clampf(float(hostile["health"]) / maxf(1.0, float(hostile["max_health"])), 0.0, 1.0)
		var health_mesh := hostile.get("health_mesh") as MeshInstance3D
		if is_instance_valid(health_mesh):
			health_mesh.scale.x = maxf(0.001, health_ratio)
			health_mesh.position.x = -(1.0 - health_ratio) * 0.5
			health_mesh.material_override = hostile["health_green"] if health_ratio > 0.55 else hostile["health_orange"] if health_ratio > 0.25 else hostile["health_red"]
		var offset := player.global_position - npc.global_position
		var distance := Vector2(offset.x, offset.z).length()
		var noise_offset := gunshot_noise_position - npc.global_position
		var noise_distance := Vector2(noise_offset.x, noise_offset.z).length()
		var heard_gunshot := gunshot_noise_timer > 0.0 and noise_distance < 88.0
		var foot_offset := movement_noise_position - npc.global_position
		var foot_distance := Vector2(foot_offset.x, foot_offset.z).length()
		var heard_footsteps := movement_noise_timer > 0.0 and foot_distance < movement_noise_radius
		var faction_key := str(hostile["faction"])
		var direct_detection := distance < (14.0 if crouch_enabled else 38.0)
		if direct_detection or heard_gunshot or heard_footsteps:
			var alert_position := player.global_position if direct_detection else gunshot_noise_position if heard_gunshot else movement_noise_position
			faction_alerts[faction_key] = {"position": alert_position, "timer": 12.0}
		var shared_alert: Dictionary = faction_alerts.get(faction_key, {})
		var shared_position: Vector3 = shared_alert.get("position", npc.global_position)
		var shared_offset := shared_position - npc.global_position
		var shared_distance := Vector2(shared_offset.x, shared_offset.z).length()
		var responding_to_alert := float(shared_alert.get("timer", 0.0)) > 0.0 and shared_distance < 72.0
		if float(hostile.get("stagger_timer", 0.0)) > 0.0:
			hostile["stagger_timer"] = maxf(0.0, float(hostile["stagger_timer"]) - delta)
			var push: Vector3 = hostile.get("knockback", Vector3.ZERO)
			npc.velocity.x = push.x
			npc.velocity.z = push.z
			hostile["knockback"] = push.move_toward(Vector3.ZERO, 24.0 * delta)
		elif direct_detection or heard_gunshot or heard_footsteps or responding_to_alert:
			var pursuit_target := player.global_position if direct_detection else gunshot_noise_position if heard_gunshot else movement_noise_position if heard_footsteps else shared_position
			# Cada combatente ocupa um setor diferente: a equipe cerca a última posição
			# conhecida em vez de formar uma fila compacta no mesmo ponto.
			var squad_slot := int(hostile.get("squad_slot", 0))
			var flank_angle := float(squad_slot) * TAU / 3.0
			var flank_radius := 8.0 + float(squad_slot % 2) * 3.0
			var tactical_target := pursuit_target + Vector3(cos(flank_angle) * flank_radius, 0.0, sin(flank_angle) * flank_radius)
			var pursuit_offset := tactical_target - npc.global_position
			var pursuit_distance := Vector2(pursuit_offset.x, pursuit_offset.z).length()
			var toward := Vector3(offset.x, 0.0, offset.z).normalized()
			if pursuit_distance > 2.2:
				var direction := _steer_around_obstacles(npc.global_position, tactical_target)
				npc.velocity.x = direction.x * float(hostile["speed"])
				npc.velocity.z = direction.z * float(hostile["speed"])
			else:
				npc.velocity.x = move_toward(npc.velocity.x, 0.0, 8.0 * delta)
				npc.velocity.z = move_toward(npc.velocity.z, 0.0, 8.0 * delta)
			if distance > 0.5:
				npc.rotation.y = lerp_angle(npc.rotation.y, atan2(-toward.x, -toward.z), delta * 5.0)
			hostile["fire_timer"] = float(hostile["fire_timer"]) - delta
			if distance <= 27.0 and distance >= 5.0 and float(hostile["fire_timer"]) <= 0.0:
				if _has_line_of_sight(npc, player):
					var muzzle := npc.global_position + Vector3(0.0, 1.28, 0.0) - npc.global_transform.basis.z * 0.65
					var target := player.global_position + Vector3(0.0, 1.0, 0.0)
					_spawn_bullet_trace(muzzle, target)
					if dodge_timer <= 0.0 and rng.randf() > 0.22:
						player_health = maxf(0.0, player_health - rng.randf_range(5.0, 9.0))
						_trigger_camera_shake(0.035)
						status_label.text = "SOB FOGO!  •  %s" % str(hostile["faction"])
					else:
						status_label.text = "TIROS DESVIADOS"
					hostile["fire_timer"] = rng.randf_range(1.4, 2.2)
				else:
					# Sem linha de visão: aproxima-se para procurar outro ângulo.
					var flank := _steer_around_obstacles(npc.global_position, player.global_position)
					npc.velocity.x = flank.x * float(hostile["speed"])
					npc.velocity.z = flank.z * float(hostile["speed"])
					hostile["fire_timer"] = 0.35
		else:
			# Patrulha leve em torno do esconderijo quando não há ameaça próxima.
			hostile["patrol_timer"] = float(hostile.get("patrol_timer", 0.0)) - delta
			var camp_center: Vector2 = hostile.get("camp_center", Vector2(npc.global_position.x, npc.global_position.z))
			var patrol_target: Vector3 = hostile.get("patrol_target", npc.global_position)
			if float(hostile["patrol_timer"]) <= 0.0 or Vector2(npc.global_position.x - patrol_target.x, npc.global_position.z - patrol_target.z).length() < 1.4:
				var phase := float(hostile.get("patrol_phase", 0.0)) + rng.randf_range(0.9, 2.2)
				hostile["patrol_phase"] = phase
				var patrol_point := camp_center + Vector2(cos(phase), sin(phase)) * rng.randf_range(3.0, 7.0)
				patrol_target = Vector3(patrol_point.x, _height_at(patrol_point.x, patrol_point.y), patrol_point.y)
				hostile["patrol_target"] = patrol_target
				hostile["patrol_timer"] = rng.randf_range(3.0, 6.0)
			var patrol_direction := _steer_around_obstacles(npc.global_position, patrol_target)
			if Vector2(npc.global_position.x - patrol_target.x, npc.global_position.z - patrol_target.z).length() > 1.2:
				npc.velocity.x = patrol_direction.x * 1.15
				npc.velocity.z = patrol_direction.z * 1.15
				npc.rotation.y = lerp_angle(npc.rotation.y, atan2(-patrol_direction.x, -patrol_direction.z), delta * 2.8)
			else:
				npc.velocity.x = move_toward(npc.velocity.x, 0.0, 6.0 * delta)
				npc.velocity.z = move_toward(npc.velocity.z, 0.0, 6.0 * delta)
		if npc.is_on_floor():
			npc.velocity.y = 0.0
		else:
			npc.velocity.y -= 19.0 * delta
		npc.move_and_slide()

func _spawn_city_horde() -> void:
	var spawn_points := [
		Vector2(57.0, -87.0), Vector2(88.0, -87.0),
		Vector2(48.0, -66.0), Vector2(96.0, -66.0),
		Vector2(57.0, -45.0), Vector2(88.0, -45.0)
	]
	var variants := [
		"res://assets/models/infected/zombie-walker.glb",
		"res://assets/models/infected/zombie-runner.glb",
		"res://assets/models/infected/zombie-brute.glb"
	]
	for i in range(spawn_points.size()):
		var path: String = variants[i % variants.size()]
		if not ResourceLoader.exists(path):
			continue
		var packed := load(path) as PackedScene
		if not packed:
			continue
		var brute := i % variants.size() == 2
		var height := 2.15 if brute else 1.9
		var enemy := CharacterBody3D.new()
		enemy.name = "Town_Infected_%02d" % i
		enemy.floor_snap_length = 0.45
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.48 if brute else 0.34
		capsule.height = height
		collision.shape = capsule
		collision.position.y = height * 0.5
		enemy.add_child(collision)
		var visual := packed.instantiate() as Node3D
		enemy.add_child(visual)
		_fit_model_height(visual, height)
		var point: Vector2 = spawn_points[i]
		enemy.position = Vector3(point.x, _height_at(point.x, point.y) + 0.08, point.y)
		enemy.rotation.y = rng.randf_range(0.0, TAU)
		add_child(enemy)
		var animator := _find_animation_player(visual)
		_play_best_animation(animator, ["idle", "walk", "move"])
		enemies.append({
			"node": enemy, "anim": animator, "health": 125.0 if brute else 100.0,
			"speed": rng.randf_range(1.0, 1.65), "attack_timer": rng.randf_range(0.5, 1.6),
			"alive": true, "territorial": true, "activation_radius": 44.0
		})


func _steer_around_obstacles(from_position: Vector3, target_position: Vector3) -> Vector3:
	var desired := Vector3(target_position.x - from_position.x, 0.0, target_position.z - from_position.z).normalized()
	var avoidance := Vector3.ZERO
	var current := Vector2(from_position.x, from_position.z)
	for obstacle in environment_obstacles:
		var offset: Vector2 = current - obstacle["position"]
		var distance := offset.length()
		var safe_distance: float = float(obstacle["radius"]) + 1.35
		if distance < safe_distance and distance > 0.05:
			var strength := 1.0 - distance / safe_distance
			avoidance += Vector3(offset.x, 0.0, offset.y).normalized() * strength * 1.8
	var result := desired + avoidance
	if result.length() < 0.05:
		return desired
	return result.normalized()

func _update_infected(delta: float) -> void:
	for enemy_data in enemies:
		if not enemy_data["alive"]:
			continue
		var infected := enemy_data["node"] as CharacterBody3D
		if not is_instance_valid(infected):
			continue
		var to_player := player.global_position - infected.global_position
		var distance := Vector2(to_player.x, to_player.z).length()
		var noise_offset := gunshot_noise_position - infected.global_position
		var noise_distance := Vector2(noise_offset.x, noise_offset.z).length()
		var heard_gunshot := gunshot_noise_timer > 0.0 and noise_distance < 70.0
		var foot_offset := movement_noise_position - infected.global_position
		var foot_distance := Vector2(foot_offset.x, foot_offset.z).length()
		var heard_footsteps := movement_noise_timer > 0.0 and foot_distance < movement_noise_radius
		if float(enemy_data.get("stagger_timer", 0.0)) > 0.0:
			enemy_data["stagger_timer"] = maxf(0.0, float(enemy_data["stagger_timer"]) - delta)
			var push: Vector3 = enemy_data.get("knockback", Vector3.ZERO)
			infected.velocity.x = push.x
			infected.velocity.z = push.z
			infected.velocity.y = -1.5 if infected.is_on_floor() else infected.velocity.y - 19.0 * delta
			infected.move_and_slide()
			enemy_data["knockback"] = push.move_toward(Vector3.ZERO, 24.0 * delta)
			continue
		var infected_detection_radius := 17.0 if crouch_enabled else float(enemy_data.get("activation_radius", 44.0))
		var territorial_dormant := distance > infected_detection_radius
		if territorial_dormant and not heard_gunshot and not heard_footsteps:
			infected.velocity.x = move_toward(infected.velocity.x, 0.0, 5.0 * delta)
			infected.velocity.z = move_toward(infected.velocity.z, 0.0, 5.0 * delta)
			if infected.is_on_floor():
				infected.velocity.y = 0.0
			else:
				infected.velocity.y -= 19.0 * delta
			infected.move_and_slide()
			continue
		var pursuit_target := gunshot_noise_position if territorial_dormant and heard_gunshot else movement_noise_position if territorial_dormant and heard_footsteps else player.global_position
		var pursuit_offset := pursuit_target - infected.global_position
		var pursuit_distance := Vector2(pursuit_offset.x, pursuit_offset.z).length()
		if pursuit_distance > 1.55:
			var direction := _steer_around_obstacles(infected.global_position, pursuit_target)
			infected.velocity.x = direction.x * float(enemy_data["speed"])
			infected.velocity.z = direction.z * float(enemy_data["speed"])
			infected.rotation.y = lerp_angle(infected.rotation.y, atan2(-direction.x, -direction.z), delta * 3.0)
			_play_best_animation(enemy_data["anim"], ["walk", "run", "move"])
		else:
			infected.velocity.x = move_toward(infected.velocity.x, 0.0, 7.0 * delta)
			infected.velocity.z = move_toward(infected.velocity.z, 0.0, 7.0 * delta)
			_play_best_animation(enemy_data["anim"], ["attack", "bite", "idle", "stand"])
			enemy_data["attack_timer"] = float(enemy_data["attack_timer"]) - delta
			if float(enemy_data["attack_timer"]) <= 0.0:
				if dodge_timer <= 0.0:
					player_health = maxf(0.0, player_health - 7.0)
					_trigger_camera_shake(0.055)
					status_label.text = "ALERTA: VOCE FOI ATACADO"
				else:
					status_label.text = "ESQUIVA PERFEITA"
				enemy_data["attack_timer"] = 1.25
		if infected.is_on_floor():
			infected.velocity.y = 0.0
		else:
			infected.velocity.y -= 19.0 * delta
		infected.move_and_slide()
	if player_attack_cooldown > 0.0:
		player_attack_cooldown -= delta
	if attack_requested and player_attack_cooldown <= 0.0:
		player_attack_cooldown = 0.65
		if equipped_items.get("weapon", "") == "weapon_rifle":
			_fire_rifle()
		else:
			player_attack_anim_time = 0.48
			_play_best_animation(player_animation, ["attack", "punch", "hit"])
			for enemy_data in enemies:
				if not enemy_data["alive"]:
					continue
				var infected: CharacterBody3D = enemy_data["node"]
				var attack_offset := infected.global_position - player.global_position
				var attack_distance := Vector2(attack_offset.x, attack_offset.z).length()
				var forward := -player.global_transform.basis.z
				var target_direction := Vector3(attack_offset.x, 0.0, attack_offset.z).normalized()
				if attack_distance < 3.2 and forward.dot(target_direction) > 0.15:
					enemy_data["health"] = float(enemy_data["health"]) - weapon_damage
					enemy_data["stagger_timer"] = 0.20
					enemy_data["knockback"] = target_direction * 6.5
					_trigger_camera_shake(0.035)
					_attack_feedback_time = 0.55
					status_label.text = "ACERTO!  -%d HP" % int(weapon_damage)
					if float(enemy_data["health"]) <= 0.0:
						enemy_data["alive"] = false
						_award_infected_kill()
						infected.queue_free()
			for hostile in hostile_humans:
				if not bool(hostile["alive"]):
					continue
				var npc := hostile["node"] as CharacterBody3D
				if not is_instance_valid(npc):
					continue
				var human_offset := npc.global_position - player.global_position
				var human_distance := Vector2(human_offset.x, human_offset.z).length()
				var human_direction := Vector3(human_offset.x, 0.0, human_offset.z).normalized()
				if human_distance < 3.4 and forward.dot(human_direction) > 0.15:
					hostile["health"] = float(hostile["health"]) - weapon_damage
					hostile["stagger_timer"] = 0.22
					hostile["knockback"] = human_direction * 7.0
					_trigger_camera_shake(0.04)
					status_label.text = "ACERTO NO COMBATENTE  •  %s" % str(hostile["faction"])
					if float(hostile["health"]) <= 0.0:
						hostile["alive"] = false
						credits += 25
						_save_profile()
						npc.queue_free()
						status_label.text = "AMEAÇA ELIMINADA  •  +25 CRÉDITOS"
			for wildlife_index in range(wildlife.size() - 1, -1, -1):
				var animal_data: Dictionary = wildlife[wildlife_index]
				var animal := animal_data["node"] as Node3D
				if not is_instance_valid(animal):
					continue
				var animal_offset := animal.global_position - player.global_position
				var animal_distance := Vector2(animal_offset.x, animal_offset.z).length()
				var animal_direction := Vector3(animal_offset.x, 0.0, animal_offset.z).normalized()
				if animal_distance < 3.0 and forward.dot(animal_direction) > 0.0:
					var hunted_kind := str(animal_data["kind"])
					var meat_amount := 3 if hunted_kind == "JAVALI" else 2 if hunted_kind == "CERVO" else 1
					food += meat_amount
					animal.queue_free()
					wildlife.remove_at(wildlife_index)
					_save_profile()
					status_label.text = "CAÇA: +%d COMIDA (%s)" % [meat_amount, hunted_kind]

func _fire_rifle() -> void:
	gunshot_noise_timer = 9.0
	gunshot_noise_position = player.global_position
	if rifle_reloading:
		status_label.text = "RECARREGANDO..."
		return
	if rifle_ammo <= 0:
		status_label.text = "SEM MUNIÇÃO — RECARREGUE"
		return
	rifle_ammo -= 1
	var origin := player.global_position + Vector3(0.0, 1.35, 0.0)
	var forward := -player.global_transform.basis.z
	var target_point := origin + forward * 55.0
	var query := PhysicsRayQueryParameters3D.create(origin, target_point)
	query.exclude = [player.get_rid()]
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var hit_position: Vector3 = hit.get("position", target_point)
	_spawn_bullet_trace(origin, hit_position)
	var collider: Object = hit.get("collider")
	var hit_target := false
	for enemy_data in enemies:
		if not bool(enemy_data["alive"]):
			continue
		var infected := enemy_data["node"] as CharacterBody3D
		if is_instance_valid(infected) and collider == infected:
			enemy_data["health"] = float(enemy_data["health"]) - 42.0
			enemy_data["stagger_timer"] = 0.35
			enemy_data["knockback"] = forward * 3.5
			hit_target = true
			if float(enemy_data["health"]) <= 0.0:
				enemy_data["alive"] = false
				_award_infected_kill()
				infected.queue_free()
			break
	if not hit_target:
		for hostile in hostile_humans:
			if not bool(hostile["alive"]):
				continue
			var npc := hostile["node"] as CharacterBody3D
			if is_instance_valid(npc) and collider == npc:
				hostile["health"] = float(hostile["health"]) - 42.0
				hostile["stagger_timer"] = 0.35
				hostile["knockback"] = forward * 3.5
				hit_target = true
				if float(hostile["health"]) <= 0.0:
					hostile["alive"] = false
					credits += 25
					_save_profile()
					npc.queue_free()
					status_label.text = "AMEAÇA ELIMINADA  •  +25 CRÉDITOS"
				break
	if not hit_target:
		status_label.text = "DISPARO — ALVO NÃO ATINGIDO"
	else:
		status_label.text = "DISPARO CONFIRMADO  •  -42 HP"
		_trigger_camera_shake(0.025)
	if is_instance_valid(ammo_label):
		ammo_label.text = "MUNIÇÃO %02d / %03d" % [rifle_ammo, rifle_reserve]
	_save_profile()

func _reload_rifle() -> void:
	if equipped_items.get("weapon", "") != "weapon_rifle":
		status_label.text = "EQUIPE O RIFLE NA LOJA"
		return
	if rifle_reloading or rifle_ammo >= 30 or rifle_reserve <= 0:
		return
	rifle_reloading = true
	rifle_reload_timer = 1.65
	status_label.text = "RECARREGANDO..."

func _trigger_camera_shake(strength: float) -> void:
	camera_shake_timer = 0.18
	camera_shake_strength = maxf(camera_shake_strength, strength)

func _update_camera_feedback(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	if camera_shake_timer > 0.0:
		camera_shake_timer = maxf(0.0, camera_shake_timer - delta)
		var fade := camera_shake_timer / 0.18
		camera.rotation.z = sin(float(Time.get_ticks_msec()) * 0.075) * camera_shake_strength * fade
		if camera_shake_timer <= 0.0:
			camera.rotation.z = 0.0
			camera_shake_strength = 0.0

func _award_infected_kill() -> void:
	credits += 15
	mission_kills = mini(mission_goal, mission_kills + 1)
	if mission_kills >= mission_goal and not mission_reward_claimed:
		mission_reward_claimed = true
		credits += 100
		if is_instance_valid(status_label):
			status_label.text = "CONTRATO CONCLUÍDO: +100 CRÉDITOS"
	_update_mission_hud()
	_save_profile()
func _alive_enemy_count() -> int:
	var alive_count := 0
	for enemy_data in enemies:
		if enemy_data["alive"] and is_instance_valid(enemy_data["node"]):
			alive_count += 1
	return alive_count

func _update_wave_hud() -> void:
	if not is_instance_valid(wave_label):
		return
	if wave_intermission >= 0.0:
		wave_label.text = "ONDA %d  •  PRÓXIMA HORDA EM %d s" % [wave_number, ceili(wave_intermission)]
	else:
		wave_label.text = "ONDA %d  •  INFECTADOS RESTANTES: %d" % [wave_number, _alive_enemy_count()]

func _update_day_night(delta: float) -> void:
	var previous_day := world_day
	world_time_seconds += delta
	var cycle_seconds := 900.0
	var phase := fposmod(world_time_seconds, cycle_seconds) / cycle_seconds
	world_day = int(floor(world_time_seconds / cycle_seconds)) + 1
	var daylight := clampf(sin(phase * TAU - PI * 0.5) * 0.5 + 0.5, 0.0, 1.0)
	if is_instance_valid(sun_light):
		sun_light.rotation_degrees.x = lerpf(-8.0, -172.0, phase)
		sun_light.light_energy = lerpf(0.08, 1.35, pow(daylight, 0.7))
		sun_light.light_color = Color(0.48, 0.58, 0.82).lerp(Color(1.0, 0.88, 0.68), daylight)
	if is_instance_valid(world_environment) and world_environment.environment:
		world_environment.environment.ambient_light_energy = lerpf(0.18, 0.65, daylight)
		world_environment.environment.fog_light_color = Color(0.08, 0.12, 0.19).lerp(Color(0.48, 0.53, 0.46), daylight)
	if world_day != previous_day:
		_save_buildings()
	_update_world_clock_hud()

func _update_world_clock_hud() -> void:
	if not is_instance_valid(world_clock_label):
		return
	var phase := fposmod(world_time_seconds, 900.0) / 900.0
	var minutes_total := int(phase * 24.0 * 60.0)
	var hour := int(minutes_total / 60) % 24
	var minute := minutes_total % 60
	var period := "DIA" if hour >= 6 and hour < 18 else "NOITE"
	world_clock_label.text = "DIA %d  •  %02d:%02d  •  %s" % [world_day, hour, minute, period]
func _update_wave_director(delta: float) -> void:
	if wave_intermission < 0.0 and _alive_enemy_count() == 0:
		wave_intermission = 10.0
		_update_wave_hud()
		return
	if wave_intermission >= 0.0:
		wave_intermission = maxf(0.0, wave_intermission - delta)
		_update_wave_hud()
		if wave_intermission <= 0.0:
			wave_number += 1
			wave_intermission = -1.0
			var next_wave_count := mini(3 + wave_number * 2, 13)
			_spawn_infected(next_wave_count)
			_update_wave_hud()

func _update_mission_hud() -> void:
	if not is_instance_valid(mission_label):
		return
	if mission_reward_claimed:
		mission_label.text = "CONTRATO CONCLUÍDO  •  RECOMPENSA RECEBIDA"
	else:
		mission_label.text = "CONTRATO: ELIMINE INFECTADOS  %d/%d  •  RECOMPENSA: 100 CR" % [mission_kills, mission_goal]

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	status_label = Label.new()
	status_label.text = "O ÚLTIMO REFÚGIO  |  VIDA 100%  |  INFECTADOS %d  |  HOSTIS %d" % [_alive_enemy_count(), _alive_hostile_count()]
	status_label.position = Vector2(22, 18)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.88, 0.91, 0.78))
	layer.add_child(status_label)
	health_bar = ProgressBar.new()
	health_bar.min_value = 0
	health_bar.max_value = 100
	health_bar.value = player_health
	health_bar.show_percentage = true
	health_bar.custom_minimum_size = Vector2(210, 18)
	health_bar.position = Vector2(22, 76)
	layer.add_child(health_bar)
	stamina_bar = ProgressBar.new()
	stamina_bar.min_value = 0
	stamina_bar.max_value = 100
	stamina_bar.value = stamina
	stamina_bar.show_percentage = false
	stamina_bar.custom_minimum_size = Vector2(150, 12)
	stamina_bar.position = Vector2(244, 79)
	stamina_bar.modulate = Color(0.72, 0.88, 0.62)
	layer.add_child(stamina_bar)
	game_over_label = Label.new()
	game_over_label.text = "VOCÊ FOI DERROTADO"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 34)
	game_over_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.68))
	game_over_label.anchor_left = 0.5
	game_over_label.anchor_right = 0.5
	game_over_label.anchor_top = 0.5
	game_over_label.anchor_bottom = 0.5
	game_over_label.offset_left = -220
	game_over_label.offset_right = 220
	game_over_label.offset_top = -90
	game_over_label.offset_bottom = -20
	game_over_label.visible = false
	layer.add_child(game_over_label)
	restart_button = Button.new()
	restart_button.text = "JOGAR NOVAMENTE"
	restart_button.custom_minimum_size = Vector2(220, 58)
	restart_button.anchor_left = 0.5
	restart_button.anchor_right = 0.5
	restart_button.anchor_top = 0.5
	restart_button.anchor_bottom = 0.5
	restart_button.offset_left = -110
	restart_button.offset_right = 110
	restart_button.offset_top = 5
	restart_button.offset_bottom = 63
	restart_button.visible = false
	restart_button.pressed.connect(func(): get_tree().reload_current_scene())
	layer.add_child(restart_button)
	var hint := Label.new()
	hint.text = "WASD: mover  •  Espaço: pular  •  F: atacar  •  Toque esquerdo: mover  •  Arraste direito: câmera"
	hint.position = Vector2(22, 48)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.75, 0.79, 0.70))
	layer.add_child(hint)
	boat_toggle_button = Button.new()
	boat_toggle_button.text = "USAR BARCO"
	boat_toggle_button.custom_minimum_size = Vector2(132, 54)
	boat_toggle_button.anchor_left = 1.0
	boat_toggle_button.anchor_right = 1.0
	boat_toggle_button.anchor_top = 1.0
	boat_toggle_button.anchor_bottom = 1.0
	boat_toggle_button.offset_left = -300
	boat_toggle_button.offset_right = -160
	boat_toggle_button.offset_top = -155
	boat_toggle_button.offset_bottom = -95
	boat_toggle_button.pressed.connect(_toggle_boat)
	layer.add_child(boat_toggle_button)
	wilderness_button = Button.new()
	wilderness_button.text = "INTERAGIR"
	wilderness_button.custom_minimum_size = Vector2(132, 54)
	wilderness_button.anchor_left = 1.0
	wilderness_button.anchor_right = 1.0
	wilderness_button.anchor_top = 1.0
	wilderness_button.anchor_bottom = 1.0
	wilderness_button.offset_left = -300
	wilderness_button.offset_right = -160
	wilderness_button.offset_top = -88
	wilderness_button.offset_bottom = -28
	wilderness_button.pressed.connect(_interact_with_wilderness)
	layer.add_child(wilderness_button)
	var jump_button := Button.new()
	jump_button.text = "VOAR / POUSAR"
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
	sprint_button = Button.new()
	sprint_button.text = "CORRER: OFF"
	sprint_button.custom_minimum_size = Vector2(112, 54)
	sprint_button.anchor_left = 1.0
	sprint_button.anchor_right = 1.0
	sprint_button.anchor_top = 1.0
	sprint_button.anchor_bottom = 1.0
	sprint_button.offset_left = -300
	sprint_button.offset_right = -160
	sprint_button.offset_top = -230
	sprint_button.offset_bottom = -170
	sprint_button.pressed.connect(_toggle_sprint)
	layer.add_child(sprint_button)
	crouch_button = Button.new()
	crouch_button.text = "AGACHAR: OFF"
	crouch_button.custom_minimum_size = Vector2(112, 52)
	crouch_button.anchor_left = 1.0
	crouch_button.anchor_right = 1.0
	crouch_button.anchor_top = 1.0
	crouch_button.anchor_bottom = 1.0
	crouch_button.offset_left = -300
	crouch_button.offset_right = -160
	crouch_button.offset_top = -300
	crouch_button.offset_bottom = -242
	crouch_button.pressed.connect(_toggle_crouch)
	layer.add_child(crouch_button)
	var dodge_button := Button.new()
	dodge_button.text = "ESQUIVAR"
	dodge_button.custom_minimum_size = Vector2(118, 52)
	dodge_button.position = Vector2(22, 430)
	dodge_button.pressed.connect(func(): dodge_requested = true)
	layer.add_child(dodge_button)
	wallet_label = Label.new()
	wallet_label.text = "CRÉDITOS: %d" % credits
	wallet_label.position = Vector2(22, 102)
	wallet_label.add_theme_font_size_override("font_size", 17)
	wallet_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.32))
	layer.add_child(wallet_label)
	wave_label = Label.new()
	wave_label.position = Vector2(22, 126)
	wave_label.add_theme_font_size_override("font_size", 15)
	wave_label.add_theme_color_override("font_color", Color(0.92, 0.55, 0.32))
	layer.add_child(wave_label)
	_update_wave_hud()
	mission_label = Label.new()
	mission_label.position = Vector2(22, 148)
	mission_label.add_theme_font_size_override("font_size", 15)
	mission_label.add_theme_color_override("font_color", Color(0.88, 0.91, 0.78))
	layer.add_child(mission_label)
	_update_mission_hud()
	resource_label = Label.new()
	resource_label.text = "MADEIRA %d  |  SUCATA %d  |  COMIDA %d  |  MED %d" % [wood, scrap, food, medical_supplies]
	resource_label.position = Vector2(22, 170)
	resource_label.add_theme_font_size_override("font_size", 14)
	resource_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.68))
	layer.add_child(resource_label)
	ammo_label = Label.new()
	ammo_label.text = "MUNIÇÃO %02d / %03d" % [rifle_ammo, rifle_reserve]
	ammo_label.position = Vector2(22, 216)
	ammo_label.add_theme_font_size_override("font_size", 14)
	ammo_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.48))
	layer.add_child(ammo_label)
	var reload_button := Button.new()
	reload_button.text = "RECARREGAR"
	reload_button.custom_minimum_size = Vector2(132, 42)
	reload_button.position = Vector2(22, 396)
	reload_button.pressed.connect(_reload_rifle)
	layer.add_child(reload_button)
	var collect_button := Button.new()
	collect_button.text = "COLETAR"
	collect_button.custom_minimum_size = Vector2(120, 44)
	collect_button.position = Vector2(22, 294)
	collect_button.pressed.connect(_collect_nearby_resource)
	layer.add_child(collect_button)
	var medkit_button := Button.new()
	medkit_button.text = "USAR KIT MÉDICO"
	medkit_button.custom_minimum_size = Vector2(150, 44)
	medkit_button.position = Vector2(22, 344)
	medkit_button.pressed.connect(_use_medkit)
	layer.add_child(medkit_button)
	var build_button := Button.new()
	build_button.text = "CONSTRUIR BARRICADA"
	build_button.custom_minimum_size = Vector2(190, 44)
	build_button.position = Vector2(22, 344)
	build_button.pressed.connect(_build_barricade)
	layer.add_child(build_button)
	var shelter_button := Button.new()
	shelter_button.text = "MELHORAR REFÚGIO"
	shelter_button.custom_minimum_size = Vector2(190, 44)
	shelter_button.position = Vector2(222, 344)
	shelter_button.pressed.connect(_upgrade_shelter)
	layer.add_child(shelter_button)
	shelter_label = Label.new()
	shelter_label.position = Vector2(222, 394)
	shelter_label.add_theme_font_size_override("font_size", 14)
	shelter_label.add_theme_color_override("font_color", Color(0.88, 0.91, 0.78))
	layer.add_child(shelter_label)
	_update_shelter_hud()
	world_clock_label = Label.new()
	world_clock_label.position = Vector2(22, 194)
	world_clock_label.add_theme_font_size_override("font_size", 14)
	world_clock_label.add_theme_color_override("font_color", Color(0.91, 0.86, 0.66))
	layer.add_child(world_clock_label)
	_update_world_clock_hud()
	vehicle_toggle_button = Button.new()
	vehicle_toggle_button.text = "ENTRAR NO VEÍCULO" if is_instance_valid(vehicle) else "SEM VEÍCULO"
	vehicle_toggle_button.disabled = not is_instance_valid(vehicle)
	vehicle_toggle_button.custom_minimum_size = Vector2(190, 42)
	vehicle_toggle_button.position = Vector2(22, 240)
	vehicle_toggle_button.pressed.connect(_toggle_vehicle)
	layer.add_child(vehicle_toggle_button)
	var shop_button := Button.new()
	shop_button.text = "LOJA / INVENTÁRIO"
	shop_button.custom_minimum_size = Vector2(190, 48)
	shop_button.position = Vector2(22, 186)
	shop_button.pressed.connect(_toggle_shop)
	layer.add_child(shop_button)
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
	_build_shop_ui(layer)

func _load_profile() -> void:
	var config := ConfigFile.new()
	if config.load("user://survivor_profile.cfg") == OK:
		credits = int(config.get_value("profile", "credits", credits))
		unlocked_items = config.get_value("profile", "unlocked", unlocked_items)
		equipped_items = config.get_value("profile", "equipped", equipped_items)
		mission_kills = int(config.get_value("profile", "mission_kills", 0))
		mission_reward_claimed = bool(config.get_value("profile", "mission_reward_claimed", false))
		wood = int(config.get_value("profile", "wood", 0))
		scrap = int(config.get_value("profile", "scrap", 0))
		food = int(config.get_value("profile", "food", 0))
		medical_supplies = int(config.get_value("profile", "medical_supplies", 0))
		rifle_ammo = int(config.get_value("profile", "rifle_ammo", 30))
		rifle_reserve = int(config.get_value("profile", "rifle_reserve", 120))
		shelter_level = int(config.get_value("profile", "shelter_level", 0))
		looted_poi_ids = config.get_value("profile", "looted_poi_ids", looted_poi_ids)

func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "credits", credits)
	config.set_value("profile", "unlocked", unlocked_items)
	config.set_value("profile", "equipped", equipped_items)
	config.set_value("profile", "mission_kills", mission_kills)
	config.set_value("profile", "mission_reward_claimed", mission_reward_claimed)
	config.set_value("profile", "wood", wood)
	config.set_value("profile", "scrap", scrap)
	config.set_value("profile", "food", food)
	config.set_value("profile", "medical_supplies", medical_supplies)
	config.set_value("profile", "rifle_ammo", rifle_ammo)
	config.set_value("profile", "rifle_reserve", rifle_reserve)
	config.set_value("profile", "shelter_level", shelter_level)
	config.set_value("profile", "looted_poi_ids", looted_poi_ids)
	config.save("user://survivor_profile.cfg")
	if wallet_label:
		wallet_label.text = "CRÉDITOS: %d" % credits
	_update_mission_hud()
	if is_instance_valid(resource_label):
		resource_label.text = "MADEIRA %d  |  SUCATA %d  |  COMIDA %d  |  MED %d" % [wood, scrap, food, medical_supplies]

func _shop_catalog() -> Array[Dictionary]:
	return [
		{"id":"character_survivor","category":"personagens","name":"Sobrevivente","description":"Personagem padrão","price":0,"kind":"character"},
		{"id":"character_ranger","category":"personagens","name":"Patrulheiro","description":"Visual alternativo de campo","price":350,"kind":"character"},
		{"id":"character_medic","category":"personagens","name":"Médico de combate","description":"Uniforme de resgate","price":500,"kind":"character"},
		{"id":"outfit_field","category":"roupas","name":"Uniforme tático","description":"Equipamento padrão","price":0,"kind":"outfit"},
		{"id":"outfit_forest","category":"roupas","name":"Camuflagem floresta","description":"Tonalidade verde militar","price":180,"kind":"outfit"},
		{"id":"outfit_desert","category":"roupas","name":"Camuflagem areia","description":"Tonalidade para terreno seco","price":180,"kind":"outfit"},
		{"id":"accessory_none","category":"adereços","name":"Sem adereço","description":"Visual limpo","price":0,"kind":"accessory"},
		{"id":"accessory_helmet","category":"adereços","name":"Capacete de combate","description":"Proteção visual","price":220,"kind":"accessory"},
		{"id":"accessory_pack","category":"adereços","name":"Mochila de expedição","description":"Acessório de sobrevivência","price":160,"kind":"accessory"},
		{"id":"weapon_fists","category":"armas","name":"Combate corpo a corpo","description":"Dano básico: 50","price":0,"kind":"weapon","damage":50.0},
		{"id":"weapon_knife","category":"armas","name":"Faca de sobrevivência","description":"Dano corpo a corpo: 75","price":250,"kind":"weapon","damage":75.0},
		{"id":"weapon_axe","category":"armas","name":"Machado tático","description":"Dano corpo a corpo: 110","price":500,"kind":"weapon","damage":110.0},
		{"id":"weapon_rifle","category":"armas","name":"Rifle de patrulha","description":"Arma de longo alcance; carregador 30, reserva 120","price":1400,"kind":"weapon","damage":42.0},
		{"id":"vehicle_none","category":"veículos","name":"A pé","description":"Deslocamento padrão","price":0,"kind":"vehicle"},
		{"id":"vehicle_pickup","category":"veículos","name":"Picape 4x4","description":"Veículo leve para exploração e transporte","price":900,"kind":"vehicle"},
		{"id":"vehicle_buggy","category":"veículos","name":"Buggy off-road","description":"Veículo rápido para trilhas","price":1200,"kind":"vehicle"},
		{"id":"vehicle_motorcycle","category":"veículos","name":"Motocicleta trail","description":"Ágil em estradas e trilhas; baixa capacidade de carga","price":1500,"kind":"vehicle"},
		{"id":"vehicle_truck","category":"veículos","name":"Caminhão de carga","description":"Transporte pesado de recursos","price":2600,"kind":"vehicle"},
		{"id":"vehicle_tractor","category":"veículos","name":"Trator agrícola","description":"Máquina robusta para terrenos difíceis","price":2200,"kind":"vehicle"},
		{"id":"vehicle_backhoe","category":"veículos","name":"Retroescavadeira","description":"Máquina de obras para futuras tarefas de construção","price":3800,"kind":"vehicle"},
		{"id":"vehicle_airplane","category":"veículos","name":"Avião monomotor","description":"Aeronave de exploração; decolagem e pouso controlados","price":6500,"kind":"vehicle"},
		{"id":"vehicle_helicopter","category":"veículos","name":"Helicóptero utilitário","description":"Aeronave de pouso vertical para alcançar áreas remotas","price":9000,"kind":"vehicle"}
	]

func _build_shop_ui(layer: CanvasLayer) -> void:
	shop_panel = PanelContainer.new()
	shop_panel.anchor_left = 0.04
	shop_panel.anchor_right = 0.96
	shop_panel.anchor_top = 0.06
	shop_panel.anchor_bottom = 0.94
	shop_panel.offset_left = 0
	shop_panel.offset_right = 0
	shop_panel.offset_top = 0
	shop_panel.offset_bottom = 0
	shop_panel.visible = false
	layer.add_child(shop_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 9)
	shop_panel.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	var heading := Label.new()
	heading.text = "ARSENAL & PERSONALIZAÇÃO"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 18)
	header.add_child(heading)
	var close := Button.new()
	close.text = "FECHAR"
	close.pressed.connect(_toggle_shop)
	header.add_child(close)
	var tabs := GridContainer.new()
	tabs.columns = 3
	outer.add_child(tabs)
	for category in ["personagens", "roupas", "adereços", "armas", "veículos"]:
		var tab := Button.new()
		tab.text = category.to_upper()
		tab.pressed.connect(_show_shop_category.bind(category))
		tabs.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	shop_list = VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(shop_list)
	_show_shop_category(shop_category)

func _toggle_shop() -> void:
	shop_open = not shop_open
	shop_panel.visible = shop_open
	if shop_open:
		_show_shop_category(shop_category)

func _show_shop_category(category: String) -> void:
	shop_category = category
	if not is_instance_valid(shop_list):
		return
	for child in shop_list.get_children():
		child.queue_free()
	for item in _shop_catalog():
		if item["category"] != category:
			continue
		var row := PanelContainer.new()
		shop_list.add_child(row)
		var column := VBoxContainer.new()
		row.add_child(column)
		var title := Label.new()
		title.text = str(item["name"]) + "  •  " + str(item["price"]) + " créditos"
		title.add_theme_font_size_override("font_size", 16)
		column.add_child(title)
		var description := Label.new()
		description.text = str(item["description"])
		description.add_theme_font_size_override("font_size", 12)
		column.add_child(description)
		var action := Button.new()
		var item_id: String = item["id"]
		var owned := unlocked_items.has(item_id)
		var equipped := str(equipped_items.get(str(item["kind"]), "")) == item_id
		if equipped:
			action.text = "EQUIPADO"
			action.disabled = true
		elif owned:
			action.text = "EQUIPAR"
		else:
			action.text = "ADQUIRIR"
		action.pressed.connect(_shop_item_action.bind(item))
		column.add_child(action)

func _shop_item_action(item: Dictionary) -> void:
	var item_id: String = item["id"]
	if not unlocked_items.has(item_id):
		var price := int(item["price"])
		if credits < price:
			status_label.text = "CRÉDITOS INSUFICIENTES"
			return
		credits -= price
		unlocked_items.append(item_id)
	equipped_items[str(item["kind"])] = item_id
	if item["kind"] == "weapon":
		weapon_damage = float(item.get("damage", 50.0))
	_apply_player_customization()
	if item["kind"] == "vehicle":
		if vehicle_active:
			_toggle_vehicle()
		_build_vehicle()
	_save_profile()
	_show_shop_category(shop_category)
	status_label.text = str(item["name"]) + " EQUIPADO"

func _add_vehicle_box(parent: Node3D, size: Vector3, local_position: Vector3, color: Color, metallic: float = 0.25) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = local_position
	part.material_override = _make_material(color, 0.62, metallic)
	parent.add_child(part)
	return part


func _add_vehicle_wheel(parent: Node3D, radius: float, width: float, local_position: Vector3) -> void:
	var wheel := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = width
	wheel.mesh = mesh
	wheel.position = local_position
	wheel.rotation.z = PI * 0.5
	wheel.material_override = _make_material(Color(0.035, 0.04, 0.035), 0.96)
	parent.add_child(wheel)


func _build_vehicle() -> void:
	if is_instance_valid(vehicle):
		vehicle.queue_free()
	vehicle_active = false
	vehicle_flying = false
	var vehicle_id := str(equipped_items.get("vehicle", "vehicle_none"))
	if vehicle_id == "vehicle_none":
		if is_instance_valid(vehicle_toggle_button):
			vehicle_toggle_button.disabled = true
			vehicle_toggle_button.text = "SEM VEÍCULO"
		return
	vehicle = CharacterBody3D.new()
	vehicle.name = "PlayerVehicle_" + vehicle_id
	var spawn := Vector3(0.0, _height_at(0.0, -7.0), -7.0)
	vehicle.position = spawn
	vehicle.floor_snap_length = 0.45
	var is_aircraft := vehicle_id in ["vehicle_airplane", "vehicle_helicopter"]
	var body_size := Vector3(2.0, 1.0, 4.0)
	if vehicle_id == "vehicle_motorcycle":
		body_size = Vector3(0.85, 1.1, 2.5)
	elif vehicle_id == "vehicle_truck":
		body_size = Vector3(2.8, 2.5, 7.0)
	elif vehicle_id == "vehicle_tractor":
		body_size = Vector3(2.7, 2.2, 4.0)
	elif vehicle_id == "vehicle_backhoe":
		body_size = Vector3(2.8, 2.8, 6.0)
	elif vehicle_id == "vehicle_airplane":
		body_size = Vector3(3.0, 1.4, 6.5)
	elif vehicle_id == "vehicle_helicopter":
		body_size = Vector3(2.8, 2.0, 5.5)
	var collision := CollisionShape3D.new()
	var body_shape := BoxShape3D.new()
	body_shape.size = body_size
	collision.shape = body_shape
	collision.position.y = body_size.y * 0.5
	vehicle.add_child(collision)
	var paint := Color(0.16, 0.24, 0.19)
	if vehicle_id == "vehicle_motorcycle":
		_add_vehicle_box(vehicle, Vector3(0.62, 0.42, 1.25), Vector3(0, 0.92, 0), Color(0.68, 0.16, 0.08))
		_add_vehicle_box(vehicle, Vector3(0.48, 0.62, 0.52), Vector3(0, 1.38, -0.12), Color(0.12, 0.15, 0.16))
		_add_vehicle_wheel(vehicle, 0.48, 0.22, Vector3(0, 0.48, -0.92))
		_add_vehicle_wheel(vehicle, 0.48, 0.22, Vector3(0, 0.48, 0.92))
	elif vehicle_id in ["vehicle_pickup", "vehicle_buggy", "vehicle_truck", "vehicle_tractor", "vehicle_backhoe"]:
		var length := 3.5
		var width := 1.95
		var wheel_radius := 0.42
		if vehicle_id == "vehicle_truck":
			length = 6.8
			width = 2.65
			wheel_radius = 0.68
		elif vehicle_id == "vehicle_tractor":
			length = 4.2
			width = 2.5
			wheel_radius = 0.72
		elif vehicle_id == "vehicle_backhoe":
			length = 5.8
			width = 2.6
			wheel_radius = 0.65
		_add_vehicle_box(vehicle, Vector3(width, 0.62, length), Vector3(0, wheel_radius + 0.25, 0), paint)
		if vehicle_id == "vehicle_truck":
			_add_vehicle_box(vehicle, Vector3(2.25, 1.85, 2.0), Vector3(0, 1.65, -1.65), Color(0.12, 0.20, 0.24))
			_add_vehicle_box(vehicle, Vector3(2.5, 1.0, 3.0), Vector3(0, 1.25, 1.35), Color(0.38, 0.35, 0.27))
		elif vehicle_id == "vehicle_tractor":
			_add_vehicle_box(vehicle, Vector3(1.55, 1.35, 1.45), Vector3(0, 1.55, -0.45), Color(0.78, 0.48, 0.08))
			_add_vehicle_box(vehicle, Vector3(1.15, 1.05, 1.0), Vector3(0, 1.95, -0.55), Color(0.12, 0.16, 0.13))
		elif vehicle_id == "vehicle_backhoe":
			_add_vehicle_box(vehicle, Vector3(1.6, 1.35, 1.5), Vector3(0, 1.55, -0.65), Color(0.82, 0.53, 0.10))
			_add_vehicle_box(vehicle, Vector3(0.38, 2.2, 0.45), Vector3(0, 2.3, 1.85), Color(0.82, 0.53, 0.10))
			_add_vehicle_box(vehicle, Vector3(1.0, 0.5, 0.75), Vector3(0, 1.2, 2.35), Color(0.28, 0.24, 0.16))
		else:
			_add_vehicle_box(vehicle, Vector3(1.55, 0.95, 1.6), Vector3(0, 1.25, -0.35), Color(0.10, 0.15, 0.14))
		for x_side in [-1.0, 1.0]:
			for z_side in [-1.0, 1.0]:
				_add_vehicle_wheel(vehicle, wheel_radius, 0.28, Vector3(x_side * (width * 0.5), wheel_radius, z_side * (length * 0.32)))
		if vehicle_id == "vehicle_truck":
			for x_side in [-1.0, 1.0]:
				_add_vehicle_wheel(vehicle, wheel_radius * 0.92, 0.28, Vector3(x_side * (width * 0.5), wheel_radius, 1.8))
	elif vehicle_id == "vehicle_airplane":
		_add_vehicle_box(vehicle, Vector3(0.72, 0.68, 5.7), Vector3(0, 1.0, 0), Color(0.68, 0.69, 0.61))
		_add_vehicle_box(vehicle, Vector3(10.0, 0.22, 1.5), Vector3(0, 1.08, 0.25), Color(0.54, 0.58, 0.52))
		_add_vehicle_box(vehicle, Vector3(3.2, 0.18, 0.85), Vector3(0, 1.55, 2.45), Color(0.54, 0.58, 0.52))
		_add_vehicle_box(vehicle, Vector3(0.25, 1.15, 0.25), Vector3(0, 1.8, 2.55), Color(0.54, 0.58, 0.52))
	elif vehicle_id == "vehicle_helicopter":
		_add_vehicle_box(vehicle, Vector3(2.0, 1.5, 3.4), Vector3(0, 1.45, 0), Color(0.24, 0.32, 0.25))
		_add_vehicle_box(vehicle, Vector3(0.55, 0.55, 2.4), Vector3(0, 1.65, 2.65), Color(0.20, 0.27, 0.21))
		_add_vehicle_box(vehicle, Vector3(9.0, 0.12, 0.18), Vector3(0, 2.55, 0), Color(0.12, 0.14, 0.12))
		_add_vehicle_box(vehicle, Vector3(0.18, 0.12, 1.7), Vector3(0, 2.55, 0), Color(0.12, 0.14, 0.12))
		_add_vehicle_box(vehicle, Vector3(1.8, 0.12, 0.15), Vector3(0, 1.45, 0.1), Color(0.12, 0.14, 0.12))
		for side in [-1.0, 1.0]:
			_add_vehicle_box(vehicle, Vector3(0.12, 0.12, 3.2), Vector3(side * 1.05, 0.35, 0), Color(0.12, 0.14, 0.12))
	add_child(vehicle)
	if is_instance_valid(vehicle_toggle_button):
		vehicle_toggle_button.disabled = false
		vehicle_toggle_button.text = "ENTRAR NO VEÍCULO"



func _toggle_vehicle() -> void:
	if not is_instance_valid(vehicle):
		status_label.text = "ADQUIRA UM VEÍCULO NA LOJA"
		return
	if not vehicle_active:
		var player_visual := player.get_node_or_null("SurvivorVisual") as Node3D
		if player_visual:
			player_visual.visible = false
		player.collision_layer = 0
		player.collision_mask = 0
		player.velocity = Vector3.ZERO
		remove_child(player)
		vehicle.add_child(player)
		player.position = Vector3(0, 1.05, 0)
		player.rotation = Vector3.ZERO
		vehicle_active = true
		vehicle_toggle_button.text = "SAIR DO VEÍCULO"
		status_label.text = "VEÍCULO: USE O JOYSTICK PARA DIRIGIR"
	else:
		vehicle.remove_child(player)
		add_child(player)
		player.global_position = vehicle.global_position + vehicle.global_transform.basis.x * 1.8 + Vector3.UP * 0.2
		player.collision_layer = 1
		player.collision_mask = 1
		var player_visual := player.get_node_or_null("SurvivorVisual") as Node3D
		if player_visual:
			player_visual.visible = true
		player.velocity = Vector3.ZERO
		vehicle.velocity = Vector3.ZERO
		vehicle_active = false
		vehicle_toggle_button.text = "ENTRAR NO VEÍCULO"
		status_label.text = "VOCÊ SAIU DO VEÍCULO"

func _update_vehicle(delta: float) -> void:
	if not vehicle_active or not is_instance_valid(vehicle):
		return
	var vehicle_id := str(equipped_items.get("vehicle", ""))
	var is_aircraft := vehicle_id in ["vehicle_airplane", "vehicle_helicopter"]
	var steering := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _touch_move.length() > 0.08:
		steering = _touch_move
	var forward := -vehicle.global_transform.basis.z
	var speed := 13.0
	match vehicle_id:
		"vehicle_motorcycle": speed = 19.0
		"vehicle_buggy": speed = 17.0
		"vehicle_truck": speed = 9.0
		"vehicle_tractor": speed = 7.0
		"vehicle_backhoe": speed = 6.0
		"vehicle_airplane": speed = 24.0
		"vehicle_helicopter": speed = 15.0
	if is_aircraft:
		if jump_requested:
			vehicle_flying = not vehicle_flying
			jump_requested = false
			status_label.text = "AERONAVE: DECOLANDO" if vehicle_flying else "AERONAVE: INICIANDO POUSO"
		vehicle.velocity.x = forward.x * -steering.y * speed
		vehicle.velocity.z = forward.z * -steering.y * speed
		var target_altitude := _height_at(vehicle.global_position.x, vehicle.global_position.z) + (15.0 if vehicle_flying else 0.0)
		if vehicle_flying:
			vehicle.velocity.y = clampf((target_altitude - vehicle.global_position.y) * 1.8, -5.0, 8.0)
		else:
			vehicle.velocity.y = clampf((target_altitude - vehicle.global_position.y) * 2.0, -8.0, 0.0)
		if absf(steering.x) > 0.08:
			vehicle.rotation.y -= steering.x * delta * 1.35 * (1.0 if steering.y <= 0.0 else -1.0)
	else:
		vehicle.velocity.x = forward.x * -steering.y * speed
		vehicle.velocity.z = forward.z * -steering.y * speed
		if absf(steering.x) > 0.08 and absf(steering.y) > 0.08:
			vehicle.rotation.y -= steering.x * delta * (2.2 if vehicle_id == "vehicle_motorcycle" else 1.5) * signf(-steering.y)
		if vehicle.is_on_floor():
			vehicle.velocity.y = 0.0
		else:
			vehicle.velocity.y -= 19.0 * delta
	vehicle.move_and_slide()

func _apply_player_customization() -> void:
	if not is_instance_valid(player):
		return
	var outfit_id := str(equipped_items.get("outfit", "outfit_field"))
	var character_id := str(equipped_items.get("character", "character_survivor"))
	var tint := Color(0.72, 0.82, 0.62) if outfit_id == "outfit_forest" else Color(0.88, 0.76, 0.54) if outfit_id == "outfit_desert" else Color.WHITE
	if character_id == "character_ranger":
		tint = tint * Color(0.86, 0.96, 0.78)
	elif character_id == "character_medic":
		tint = tint * Color(1.0, 0.84, 0.82)
	var visual := player.get_node_or_null("SurvivorVisual") as Node3D
	if visual:
		for mesh_node in visual.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := mesh_node as MeshInstance3D
			if mesh_instance.mesh:
				for surface_index in range(mesh_instance.mesh.get_surface_count()):
					mesh_instance.set_surface_override_material(surface_index, null)
					var source_material := mesh_instance.get_active_material(surface_index)
					if source_material is StandardMaterial3D:
						var tinted_material := (source_material as StandardMaterial3D).duplicate() as StandardMaterial3D
						tinted_material.albedo_color = tinted_material.albedo_color * tint
						mesh_instance.set_surface_override_material(surface_index, tinted_material)
	if is_instance_valid(accessory_visual):
		accessory_visual.queue_free()
	accessory_visual = Node3D.new()
	accessory_visual.name = "EquippedAccessory"
	player.add_child(accessory_visual)
	var accessory_id := str(equipped_items.get("accessory", "accessory_none"))
	if accessory_id == "accessory_helmet":
		var helmet := MeshInstance3D.new()
		var helmet_mesh := SphereMesh.new()
		helmet_mesh.radius = 0.25
		helmet_mesh.height = 0.22
		helmet.mesh = helmet_mesh
		helmet.position = Vector3(0, 1.91, 0)
		helmet.material_override = _make_material(Color(0.16, 0.22, 0.16), 0.55)
		accessory_visual.add_child(helmet)
	elif accessory_id == "accessory_pack":
		var pack := MeshInstance3D.new()
		var pack_mesh := BoxMesh.new()
		pack_mesh.size = Vector3(0.48, 0.62, 0.25)
		pack.mesh = pack_mesh
		pack.position = Vector3(0, 1.08, 0.36)
		pack.material_override = _make_material(Color(0.12, 0.18, 0.12))
		accessory_visual.add_child(pack)
	var weapon_id := str(equipped_items.get("weapon", "weapon_fists"))
	if weapon_id != "weapon_fists":
		var weapon_mesh := MeshInstance3D.new()
		var blade := BoxMesh.new()
		blade.size = Vector3(0.09, 0.62 if weapon_id == "weapon_knife" else 0.95, 0.055)
		weapon_mesh.mesh = blade
		weapon_mesh.position = Vector3(0.38, 1.05, -0.28)
		weapon_mesh.rotation.z = deg_to_rad(-28.0)
		weapon_mesh.material_override = _make_material(Color(0.55, 0.58, 0.58), 0.28)
		accessory_visual.add_child(weapon_mesh)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if is_instance_valid(boat) and not boat_active and player.global_position.distance_to(boat.global_position) <= 5.0:
			_toggle_boat()
		else:
			_interact_with_wilderness()
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
			_touch_move = Vector2(clampf(delta.x / 72.0, -1.0, 1.0), clampf(delta.y / 72.0, -1.0, 1.0))
		elif event.index == active_look_touch:
			camera_pivot.rotation.y -= event.relative.x * 0.004
			camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -0.85, 0.15)


func _spawn_allied_survivors() -> void:
	# Companheiros locais: IA leve, sem chamadas externas, preparada para evoluir.
	var ally_specs := [
		{"name": "MAYA • MÉDICA", "role": "MÉDICA", "color": Color(0.72, 0.28, 0.22), "offset": Vector3(2.8, 0, 2.2)},
		{"name": "RAUL • PATRULHEIRO", "role": "PATRULHEIRO", "color": Color(0.22, 0.38, 0.25), "offset": Vector3(-2.8, 0, 2.2)},
		{"name": "DAVI • CONSTRUTOR", "role": "CONSTRUTOR", "color": Color(0.42, 0.34, 0.22), "offset": Vector3(4.5, 0, -8.0)}
	]
	for spec in ally_specs:
		var ally := CharacterBody3D.new()
		ally.name = str(spec["name"]).replace(" ", "_")
		ally.position = Vector3(spec["offset"].x, _height_at(spec["offset"].x, spec["offset"].z), spec["offset"].z)
		ally.floor_snap_length = 0.35
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.34
		capsule.height = 1.72
		collision.shape = capsule
		collision.position.y = 0.86
		ally.add_child(collision)
		var body_mesh := MeshInstance3D.new()
		var body_shape := CapsuleMesh.new()
		body_shape.radius = 0.34
		body_shape.height = 1.72
		body_mesh.mesh = body_shape
		body_mesh.position.y = 0.86
		body_mesh.material_override = _make_material(spec["color"], 0.82)
		ally.add_child(body_mesh)
		var head := MeshInstance3D.new()
		var head_shape := SphereMesh.new()
		head_shape.radius = 0.19
		head_shape.height = 0.38
		head.mesh = head_shape
		head.position.y = 1.78
		head.material_override = _make_material(Color(0.66, 0.48, 0.36))
		ally.add_child(head)
		var role_label := Label3D.new()
		role_label.text = str(spec["role"])
		role_label.position.y = 2.15
		role_label.font_size = 30
		role_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		role_label.modulate = Color(0.88, 0.94, 0.82)
		ally.add_child(role_label)
		add_child(ally)
		allied_survivors.append({"body": ally, "role": spec["role"], "home_offset": spec["offset"], "state": "FOLLOW", "scavenge_timer": 6.0, "heal_timer": 8.0, "combat_timer": 0.0, "constructor_timer": 12.0, "community_scavenge_timer": 20.0})

func _update_allied_survivors(delta: float) -> void:
	if not is_instance_valid(player):
		return
	for index in range(allied_survivors.size()):
		var data: Dictionary = allied_survivors[index]
		var ally := data["body"] as CharacterBody3D
		if not is_instance_valid(ally):
			continue
		var offset: Vector3 = data["home_offset"]
		var desired := player.global_position + player.global_transform.basis * offset
		var distance := Vector2(ally.global_position.x - player.global_position.x, ally.global_position.z - player.global_position.z).length()
		var target := desired
		var movement_distance := distance
		if str(data["role"]) == "CONSTRUTOR":
			var base_position := shelter_root.global_position if is_instance_valid(shelter_root) else Vector3(0, _height_at(0, -8), -8)
			target = base_position + Vector3(4.5, 0, 0)
			movement_distance = Vector2(ally.global_position.x - target.x, ally.global_position.z - target.z).length()
		var nearest_enemy: Dictionary = {}
		var nearest_distance := 999.0
		for enemy_data in enemies:
			if not enemy_data["alive"]:
				continue
			var enemy := enemy_data["node"] as Node3D
			if is_instance_valid(enemy):
				var enemy_distance := ally.global_position.distance_to(enemy.global_position)
				if enemy_distance < nearest_distance:
					nearest_distance = enemy_distance
					nearest_enemy = enemy_data
		if str(data["role"]) == "PATRULHEIRO" and not nearest_enemy.is_empty() and nearest_distance < 8.0:
			var threat := nearest_enemy["node"] as Node3D
			target = threat.global_position - (threat.global_position - ally.global_position).normalized() * 2.0
			data["state"] = "DEFEND"
			data["combat_timer"] = float(data["combat_timer"]) - delta
			if nearest_distance < 2.5 and float(data["combat_timer"]) <= 0.0:
				nearest_enemy["health"] = float(nearest_enemy["health"]) - 18.0
				data["combat_timer"] = 1.25
				if float(nearest_enemy["health"]) <= 0.0:
					nearest_enemy["alive"] = false
					_award_infected_kill()
					threat.queue_free()
		else:
			data["state"] = "FOLLOW"
		if movement_distance > (1.8 if str(data["role"]) == "CONSTRUTOR" else 2.4):
			var move_dir := Vector3(target.x - ally.global_position.x, 0, target.z - ally.global_position.z).normalized()
			move_dir = _steer_around_obstacles(ally.global_position, ally.global_position + move_dir * 3.0)
			ally.velocity.x = move_dir.x * 4.2
			ally.velocity.z = move_dir.z * 4.2
			if move_dir.length() > 0.1:
				ally.rotation.y = lerp_angle(ally.rotation.y, atan2(-move_dir.x, -move_dir.z), delta * 5.0)
		else:
			ally.velocity.x = move_toward(ally.velocity.x, 0.0, 16.0 * delta)
			ally.velocity.z = move_toward(ally.velocity.z, 0.0, 16.0 * delta)
		if not ally.is_on_floor():
			ally.velocity.y -= 19.0 * delta
		else:
			ally.velocity.y = 0.0
		ally.move_and_slide()
		data["scavenge_timer"] = maxf(0.0, float(data["scavenge_timer"]) - delta)
		if str(data["role"]) != "CONSTRUTOR" and float(data["scavenge_timer"]) <= 0.0 and distance < 24.0:
			for resource_index in range(resource_nodes.size()):
				var resource_data: Dictionary = resource_nodes[resource_index]
				var resource_node := resource_data["node"] as Node3D
				if is_instance_valid(resource_node) and ally.global_position.distance_to(resource_node.global_position) < 2.0:
					var amount := int(resource_data["amount"])
					match str(resource_data["kind"]):
						"wood": wood += amount
						"scrap": scrap += amount
						"food": food += amount
					resource_node.queue_free()
					resource_nodes.remove_at(resource_index)
					data["scavenge_timer"] = 9.0
					_save_profile()
					break
		if str(data["role"]) == "CONSTRUTOR":
			data["constructor_timer"] = maxf(0.0, float(data["constructor_timer"]) - delta)
			data["community_scavenge_timer"] = maxf(0.0, float(data["community_scavenge_timer"]) - delta)
			if movement_distance < 3.0 and float(data["community_scavenge_timer"]) <= 0.0:
				_community_scavenge_from_base()
				data["community_scavenge_timer"] = 24.0
			if movement_distance < 3.0 and float(data["constructor_timer"]) <= 0.0:
				_try_community_construction(ally)
				data["constructor_timer"] = 35.0
		if str(data["role"]) == "MÉDICA":
			data["heal_timer"] = maxf(0.0, float(data["heal_timer"]) - delta)
			if player_health < 90.0 and food > 0 and float(data["heal_timer"]) <= 0.0 and player.global_position.distance_to(ally.global_position) < 7.0:
				food -= 1
				player_health = minf(100.0, player_health + 12.0)
				data["heal_timer"] = 18.0
				_save_profile()
		allied_survivors[index] = data
	if is_instance_valid(resource_label):
		resource_label.text = "MADEIRA %d  |  SUCATA %d  |  COMIDA %d  |  ALIADOS %d" % [wood, scrap, food, allied_survivors.size()]
func _trigger_game_over() -> void:
	if game_over:
		return
	game_over = true
	game_over_label.visible = true
	restart_button.visible = true
	status_label.text = "FIM DE JOGO"

func _apply_crouch_pose() -> void:
	if not is_instance_valid(player):
		return
	var visual := player.get_node_or_null("SurvivorVisual") as Node3D
	if is_instance_valid(visual):
		visual.scale = Vector3(player_visual_base_scale.x, player_visual_base_scale.y * (0.72 if crouch_enabled else 1.0), player_visual_base_scale.z)
	var collision := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if is_instance_valid(collision) and collision.shape is CapsuleShape3D:
		var capsule := collision.shape as CapsuleShape3D
		capsule.height = 1.38 if crouch_enabled else 1.85
		collision.position.y = capsule.height * 0.5
	if is_instance_valid(camera_pivot):
		camera_pivot.position.y = 1.05 if crouch_enabled else 1.55
	if is_instance_valid(camera):
		camera.position.y = 1.75 if crouch_enabled else 2.15

func _toggle_crouch() -> void:
	crouch_enabled = not crouch_enabled
	_apply_crouch_pose()
	if crouch_enabled:
		sprint_enabled = false
		if is_instance_valid(sprint_button):
			sprint_button.text = "CORRER: OFF"
	if is_instance_valid(crouch_button):
		crouch_button.text = "AGACHAR: ON" if crouch_enabled else "AGACHAR: OFF"
	if is_instance_valid(status_label):
		status_label.text = "MODO FURTIVO ATIVADO" if crouch_enabled else "MODO FURTIVO DESATIVADO"

func _toggle_sprint() -> void:
	if crouch_enabled:
		crouch_enabled = false
		_apply_crouch_pose()
		if is_instance_valid(crouch_button):
			crouch_button.text = "AGACHAR: OFF"
	sprint_enabled = not sprint_enabled
	if is_instance_valid(sprint_button):
		sprint_button.text = "CORRER: ON" if sprint_enabled else "CORRER: OFF"

func _physics_process(delta: float) -> void:
	gunshot_noise_timer = maxf(0.0, gunshot_noise_timer - delta)
	movement_noise_timer = maxf(0.0, movement_noise_timer - delta)
	footstep_noise_cooldown = maxf(0.0, footstep_noise_cooldown - delta)
	_update_camera_feedback(delta)
	if collect_cooldown > 0.0:
		collect_cooldown = maxf(0.0, collect_cooldown - delta)
	if rifle_reloading:
		rifle_reload_timer = maxf(0.0, rifle_reload_timer - delta)
		if rifle_reload_timer <= 0.0:
			var needed := 30 - rifle_ammo
			var loaded := mini(needed, rifle_reserve)
			rifle_ammo += loaded
			rifle_reserve -= loaded
			rifle_reloading = false
			if is_instance_valid(ammo_label):
				ammo_label.text = "MUNIÇÃO %02d / %03d" % [rifle_ammo, rifle_reserve]
			_save_profile()
			if is_instance_valid(status_label):
				status_label.text = "RIFLE RECARREGADO"

	if fishing_cooldown > 0.0:
		fishing_cooldown = maxf(0.0, fishing_cooldown - delta)
	if dodge_cooldown > 0.0:
		dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	if not is_instance_valid(player) or game_over:
		return
	_update_day_night(delta)
	_update_wave_director(delta)
	_update_allied_survivors(delta)
	_update_shelter_support(delta)
	_update_wildlife(delta)
	if boat_active:
		_update_boat(delta)
		_update_infected(delta)
		_update_hostile_factions(delta)
		if health_bar:
			health_bar.value = player_health
		return
	if vehicle_active:
		_update_vehicle(delta)
		_update_infected(delta)
		_update_hostile_factions(delta)
		if player_health <= 0.0:
			_trigger_game_over()
		if health_bar:
			health_bar.value = player_health
		if status_label and player_health > 0.0:
			status_label.text = "O ÚLTIMO REFÚGIO  |  VIDA %d%%  |  INFECTADOS %d  |  HOSTIS %d" % [int(player_health), _alive_enemy_count(), _alive_hostile_count()]
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
	var moving := direction.length() > 0.05
	if moving and footstep_noise_cooldown <= 0.0:
		movement_noise_position = player.global_position
		movement_noise_radius = 7.0 if crouch_enabled else 24.0 if sprint_enabled else 13.0
		movement_noise_timer = 1.15
		footstep_noise_cooldown = 0.72 if crouch_enabled else 0.34 if sprint_enabled else 0.58
	if dodge_requested:
		if dodge_cooldown <= 0.0 and stamina >= 22.0:
			dodge_direction = direction if moving else -player.global_transform.basis.z
			dodge_direction.y = 0.0
			dodge_direction = dodge_direction.normalized()
			dodge_timer = 0.42
			dodge_cooldown = 1.15
			stamina -= 22.0
			player.rotation.y = atan2(-dodge_direction.x, -dodge_direction.z)
		else:
			status_label.text = "ESQUIVA INDISPONÍVEL: RECUPERE ENERGIA"
	dodge_requested = false
	var sprinting := sprint_enabled and not crouch_enabled and moving and stamina > 0.0 and dodge_timer <= 0.0
	if sprinting:
		stamina = maxf(0.0, stamina - 24.0 * delta)
	elif dodge_timer <= 0.0:
		stamina = minf(100.0, stamina + (13.0 if moving else 21.0) * delta)
	if stamina <= 0.0 and sprint_enabled:
		sprint_enabled = false
		if is_instance_valid(sprint_button):
			sprint_button.text = "CORRER: OFF"
	var movement_speed := PLAYER_SPEED * (1.65 if sprinting else (0.52 if crouch_enabled else 1.0))
	if dodge_timer > 0.0:
		dodge_timer = maxf(0.0, dodge_timer - delta)
		player.velocity.x = dodge_direction.x * 14.0
		player.velocity.z = dodge_direction.z * 14.0
	elif moving:
		player.velocity.x = direction.x * movement_speed
		player.velocity.z = direction.z * movement_speed
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), delta * 9.0)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, PLAYER_SPEED * 5.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, PLAYER_SPEED * 5.0 * delta)
	if is_instance_valid(camera):
		var target_fov := 80.0 if sprinting or dodge_timer > 0.0 else 74.0
		camera.fov = lerpf(camera.fov, target_fov, delta * 4.0)
	if not player.is_on_floor():
		player.velocity.y -= 19.0 * delta
	elif jump_requested or Input.is_action_just_pressed("jump"):
		player.velocity.y = JUMP_VELOCITY
	attack_requested = attack_requested or Input.is_action_just_pressed("attack")
	_update_infected(delta)
	_update_hostile_factions(delta)
	if player_health <= 0.0:
		_trigger_game_over()
	if attack_requested:
		status_label.text = "O ÚLTIMO REFÚGIO  |  ATAQUE"
		_attack_feedback_time = 0.45
	attack_requested = false
	jump_requested = false
	player.move_and_slide()
	if player_attack_anim_time > 0.0:
		player_attack_anim_time = maxf(0.0, player_attack_anim_time - delta)
	else:
		if Vector2(player.velocity.x, player.velocity.z).length() > 0.35:
			_play_best_animation(player_animation, ["run", "walk", "move"])
		else:
			_play_best_animation(player_animation, ["idle", "breath", "stand"])
	var ground_y := _height_at(player.global_position.x, player.global_position.z)
	if player.global_position.y < ground_y - 3.0:
		player.global_position.y = ground_y + 1.0
		player.velocity = Vector3.ZERO
	if health_bar:
		health_bar.value = player_health
	if stamina_bar:
		stamina_bar.value = stamina
	if status_label and player_health > 0.0 and _attack_feedback_time <= 0.0:
		status_label.text = "O ÚLTIMO REFÚGIO  |  VIDA %d%%  |  INFECTADOS %d" % [int(player_health), _alive_enemy_count()]
	if _attack_feedback_time > 0.0:
		_attack_feedback_time -= delta
		if _attack_feedback_time <= 0.0 and is_instance_valid(status_label):
			status_label.text = "O ÚLTIMO REFÚGIO  |  PROTÓTIPO GODOT 4"
