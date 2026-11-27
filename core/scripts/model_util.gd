class_name ModelUtil
extends RefCounted
## Utilitários para modelos importados (GLB).


## Carrega um GLB como cena. Retorna null se o recurso não existir ou não tiver importado.
static func load_model(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	return scene.instantiate() as Node3D


## Escala o modelo para ter `target_height` e apoia a base em y=0.
## O nó precisa estar dentro da árvore (usa transforms globais).
static func fit_height(model: Node3D, target_height: float) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	var merged := AABB()
	var first := true
	var inv := model.global_transform.affine_inverse()
	for mi in meshes:
		if mi.mesh == null:
			continue
		var box := (inv * mi.global_transform) * mi.mesh.get_aabb()
		merged = box if first else merged.merge(box)
		first = false
	if first or merged.size.y < 0.001:
		return
	var s := target_height / merged.size.y
	model.scale = Vector3.ONE * s
	model.position.y = -merged.position.y * s


static func find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := find_anim(c)
		if found:
			return found
	return null


static func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)
