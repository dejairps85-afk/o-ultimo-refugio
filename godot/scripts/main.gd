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
var health_bar: ProgressBar
var enemies: Array = []
var environment_obstacles: Array[Dictionary] = []
var player_animation: AnimationPlayer
var player_health := 100.0
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
var accessory_visual: Node3D
var outfit_tint := Color.WHITE
var vehicle: CharacterBody3D
var vehicle_active := false
var vehicle_toggle_button: Button
var resource_label: Label
var wood := 0
var scrap := 0
var food := 0
var resource_nodes: Array[Dictionary] = []
var collect_requested := false
var collect_cooldown := 0.0
var built_structures: Array[Dictionary] = []
var allied_survivors: Array[Dictionary] = []
var shelter_level := 0
var shelter_root: Node3D
var shelter_heal_timer := 0.0
var shelter_label: Label

func _ready() -> void:
	rng.randomize()
	_setup_environment()
	_build_terrain()
	_scatter_environment()
	_build_player()
	_spawn_infected()
	_spawn_allied_survivors()
	_load_profile()
	_load_saved_buildings()
	_apply_player_customization()
	_build_vehicle()
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

func _make_material(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _scatter_environment() -> void:
	var tree_scene: PackedScene = load("res://assets/models/tree_small_02/tree_small_02_mobile.glb") if ResourceLoader.exists("res://assets/models/tree_small_02/tree_small_02_mobile.glb") else null
	var rock_scene: PackedScene = load("res://assets/models/rock_moss_set_01/rock_moss_set_01_mobile.glb") if ResourceLoader.exists("res://assets/models/rock_moss_set_01/rock_moss_set_01_mobile.glb") else null
	var fern_scene: PackedScene = load("res://assets/models/fern_02/fern_02_mobile.glb") if ResourceLoader.exists("res://assets/models/fern_02/fern_02_mobile.glb") else null
	var stump_scene: PackedScene = load("res://assets/models/tree_stump_01/tree_stump_01_mobile.glb") if ResourceLoader.exists("res://assets/models/tree_stump_01/tree_stump_01_mobile.glb") else null
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
		environment_obstacles.append({"position": Vector2(x, z), "radius": 1.45 * instance.scale.x})
		_add_tree_collision(instance)
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
		environment_obstacles.append({"position": Vector2(x, z), "radius": 1.0 * instance.scale.x})
		_add_rock_collision(instance)
		add_child(instance)
	for i in range(18):
		if stump_scene:
			var x := rng.randf_range(-92, 92)
			var z := rng.randf_range(-92, 92)
			if Vector2(x, z).length() > 13.0:
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

func _save_buildings() -> void:
	var config := ConfigFile.new()
	config.set_value("world", "barricades", built_structures)
	config.set_value("world", "shelter_level", shelter_level)
	config.save("user://survivor_world.cfg")

func _load_saved_buildings() -> void:
	var config := ConfigFile.new()
	if config.load("user://survivor_world.cfg") != OK:
		return
	built_structures = config.get_value("world", "barricades", [])
	shelter_level = int(config.get_value("world", "shelter_level", shelter_level))
	if shelter_level > 0:
		_build_shelter_visual()
	for data in built_structures:
		var barricade := StaticBody3D.new()
		barricade.name = "SavedBarricade"
		barricade.position = Vector3(float(data["x"]), _height_at(float(data["x"]), float(data["z"])), float(data["z"]))
		barricade.rotation.y = float(data["rotation"])
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
	camera.position = Vector3(0, 2.0, 6.5)
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
		enemies.append({"node": enemy, "anim": animator, "health": 100.0 * difficulty, "speed": rng.randf_range(1.0, 1.8) * minf(difficulty, 1.45), "attack_timer": rng.randf_range(0.4, 1.5), "alive": true})

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
		if distance > 1.55:
			var direction := _steer_around_obstacles(infected.global_position, player.global_position)
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
				player_health = maxf(0.0, player_health - 7.0)
				enemy_data["attack_timer"] = 1.25
				status_label.text = "ALERTA: VOCE FOI ATACADO"
		if infected.is_on_floor():
			infected.velocity.y = 0.0
		else:
			infected.velocity.y -= 19.0 * delta
		infected.move_and_slide()
	if player_attack_cooldown > 0.0:
		player_attack_cooldown -= delta
	if attack_requested and player_attack_cooldown <= 0.0:
		player_attack_cooldown = 0.65
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
				if float(enemy_data["health"]) <= 0.0:
					enemy_data["alive"] = false
					credits += 15
					mission_kills = mini(mission_goal, mission_kills + 1)
					if mission_kills >= mission_goal and not mission_reward_claimed:
						mission_reward_claimed = true
						credits += 100
						status_label.text = "CONTRATO CONCLUÍDO: +100 CRÉDITOS"
					_update_mission_hud()
					_save_profile()
					infected.queue_free()

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
	status_label.text = "O ÚLTIMO REFÚGIO  |  VIDA 100%  |  INFECTADOS %d" % _alive_enemy_count()
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
	resource_label.text = "MADEIRA %d  |  SUCATA %d  |  COMIDA %d" % [wood, scrap, food]
	resource_label.position = Vector2(22, 170)
	resource_label.add_theme_font_size_override("font_size", 14)
	resource_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.68))
	layer.add_child(resource_label)
	var collect_button := Button.new()
	collect_button.text = "COLETAR"
	collect_button.custom_minimum_size = Vector2(120, 44)
	collect_button.position = Vector2(22, 294)
	collect_button.pressed.connect(_collect_nearby_resource)
	layer.add_child(collect_button)
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
		shelter_level = int(config.get_value("profile", "shelter_level", 0))

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
	config.set_value("profile", "shelter_level", shelter_level)
	config.save("user://survivor_profile.cfg")
	if wallet_label:
		wallet_label.text = "CRÉDITOS: %d" % credits
	_update_mission_hud()
	if is_instance_valid(resource_label):
		resource_label.text = "MADEIRA %d  |  SUCATA %d  |  COMIDA %d" % [wood, scrap, food]

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
		{"id":"vehicle_none","category":"veículos","name":"A pé","description":"Deslocamento padrão","price":0,"kind":"vehicle"},
		{"id":"vehicle_pickup","category":"veículos","name":"Picape 4x4","description":"Picape 4x4 dirigível para explorar o mapa","price":900,"kind":"vehicle"},
		{"id":"vehicle_buggy","category":"veículos","name":"Buggy off-road","description":"Buggy off-road dirigível para explorar o mapa","price":1200,"kind":"vehicle"}
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

func _build_vehicle() -> void:
	if is_instance_valid(vehicle):
		vehicle.queue_free()
	vehicle_active = false
	var vehicle_id := str(equipped_items.get("vehicle", "vehicle_none"))
	if vehicle_id == "vehicle_none":
		return
	vehicle = CharacterBody3D.new()
	vehicle.name = "PlayerVehicle"
	vehicle.position = Vector3(0, _height_at(0, -7) + 0.55, -7)
	vehicle.floor_snap_length = 0.45
	var collision := CollisionShape3D.new()
	var body_shape := BoxShape3D.new()
	body_shape.size = Vector3(1.9, 0.85, 3.4)
	collision.shape = body_shape
	collision.position.y = 0.62
	vehicle.add_child(collision)
	var chassis := MeshInstance3D.new()
	var chassis_mesh := BoxMesh.new()
	chassis_mesh.size = Vector3(1.95, 0.62, 3.5)
	chassis.mesh = chassis_mesh
	chassis.position.y = 0.62
	chassis.material_override = _make_material(Color(0.16, 0.24, 0.19), 0.55)
	vehicle.add_child(chassis)
	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.58, 0.82, 1.65)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0, 1.28, -0.18)
	cabin.material_override = _make_material(Color(0.10, 0.15, 0.14), 0.35)
	vehicle.add_child(cabin)
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.39
			wheel_mesh.bottom_radius = 0.39
			wheel_mesh.height = 0.24
			wheel.mesh = wheel_mesh
			wheel.position = Vector3(x_side * 1.0, 0.42, z_side * 1.12)
			wheel.rotation.z = PI * 0.5
			wheel.material_override = _make_material(Color(0.035, 0.04, 0.035), 0.95)
			vehicle.add_child(wheel)
	add_child(vehicle)
	if vehicle_toggle_button:
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
	var steering := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _touch_move.length() > 0.08:
		steering = _touch_move
	var forward := -vehicle.global_transform.basis.z
	var speed := 13.0 if str(equipped_items.get("vehicle", "")) == "vehicle_pickup" else 16.0
	vehicle.velocity.x = forward.x * -steering.y * speed
	vehicle.velocity.z = forward.z * -steering.y * speed
	if absf(steering.x) > 0.08 and absf(steering.y) > 0.08:
		vehicle.rotation.y -= steering.x * delta * 1.8 * signf(-steering.y)
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
		_collect_nearby_resource()
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
		{"name": "RAUL • PATRULHEIRO", "role": "PATRULHEIRO", "color": Color(0.22, 0.38, 0.25), "offset": Vector3(-2.8, 0, 2.2)}
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
		allied_survivors.append({"body": ally, "role": spec["role"], "home_offset": spec["offset"], "state": "FOLLOW", "scavenge_timer": 6.0, "heal_timer": 8.0, "combat_timer": 0.0})

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
		if distance > 2.4:
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
		if float(data["scavenge_timer"]) <= 0.0 and distance < 24.0:
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

func _physics_process(delta: float) -> void:
	if collect_cooldown > 0.0:
		collect_cooldown = maxf(0.0, collect_cooldown - delta)
	if not is_instance_valid(player) or game_over:
		return
	_update_wave_director(delta)
	_update_allied_survivors(delta)
	_update_shelter_support(delta)
	if vehicle_active:
		_update_vehicle(delta)
		_update_infected(delta)
		if player_health <= 0.0:
			_trigger_game_over()
		if health_bar:
			health_bar.value = player_health
		if status_label and player_health > 0.0:
			status_label.text = "O ÚLTIMO REFÚGIO  |  VIDA %d%%  |  INFECTADOS %d" % [int(player_health), _alive_enemy_count()]
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
	attack_requested = attack_requested or Input.is_action_just_pressed("attack")
	_update_infected(delta)
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
	if status_label and player_health > 0.0 and _attack_feedback_time <= 0.0:
		status_label.text = "O ÚLTIMO REFÚGIO  |  VIDA %d%%  |  INFECTADOS %d" % [int(player_health), _alive_enemy_count()]
	if _attack_feedback_time > 0.0:
		_attack_feedback_time -= delta
		if _attack_feedback_time <= 0.0 and is_instance_valid(status_label):
			status_label.text = "O ÚLTIMO REFÚGIO  |  PROTÓTIPO GODOT 4"
