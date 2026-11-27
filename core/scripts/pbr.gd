class_name PBR
extends RefCounted
## Materiais PBR triplanares (mundo), sem depender de UVs dos meshes.
## Se uma textura não existir, o material continua válido (cor sólida).

static func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## folder: pasta com os mapas; nomes dos arquivos variam entre os pacotes.
static func make(folder: String, albedo_file: String, normal_file: String, rough_file: String, fallback: Color, tile_meters: float, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 1.0
	mat.metallic = 0.0
	var albedo := _tex(folder + albedo_file)
	if albedo:
		mat.albedo_texture = albedo
	else:
		mat.albedo_color = fallback
	var normal := _tex(folder + normal_file)
	if normal:
		mat.normal_enabled = true
		mat.normal_texture = normal
		mat.normal_scale = 1.0
	var rough := _tex(folder + rough_file)
	if rough:
		mat.roughness_texture = rough
	# Triplanar em coordenadas de mundo: a textura não estica nem depende do tamanho do objeto.
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	var s := 1.0 / maxf(tile_meters, 0.1)
	mat.uv1_scale = Vector3(s, s, s)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


static func asphalt() -> StandardMaterial3D:
	return make("res://assets/textures/cinematic/Asphalt033/", "albedo.jpg", "normal.jpg", "roughness.jpg", Color(0.12, 0.12, 0.12), 3.0, Color(0.85, 0.85, 0.85))


static func concrete(tint: Color = Color.WHITE) -> StandardMaterial3D:
	return make("res://assets/textures/cinematic/Concrete012/", "albedo.jpg", "normal.jpg", "roughness.jpg", Color(0.45, 0.45, 0.43), 2.5, tint)


static func ground() -> StandardMaterial3D:
	return make("res://assets/textures/forest_ground_06/", "Diffuse_1k_jpg.jpg", "nor_gl_1k_jpg.jpg", "Rough_1k_jpg.jpg", Color(0.22, 0.27, 0.17), 4.0, Color(0.8, 0.82, 0.75))


static func flat(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat
