@tool
extends MeshLibrary

enum Tile { GROUND, GROUND_FOREST, GROUND_DESERT, OBSTACLE, WATER, CONTAINER, PIPE, PUMP }


static func build() -> MeshLibrary:
	var lib := MeshLibrary.new()
	_add_ground(lib)
	_add_ground_forest(lib)
	_add_ground_desert(lib)
	_add_obstacle(lib)
	_add_water(lib)
	_add_container(lib)
	_add_pipe(lib)
	_add_pump(lib)
	return lib


static func _add_ground(lib: MeshLibrary) -> void:
	var item := Tile.GROUND
	lib.create_item(item)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 0.2, 1)
	mesh.material = _mat(Color(0.35, 0.55, 0.35))
	lib.set_item_mesh(item, mesh)
	lib.set_item_mesh_transform(item, Transform3D(Basis(), Vector3(0, -0.1, 0)))
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 0.2, 1)
	lib.set_item_shapes(item, [shape, Transform3D(Basis(), Vector3(0, -0.1, 0))])


static func _add_ground_forest(lib: MeshLibrary) -> void:
	var item := Tile.GROUND_FOREST
	lib.create_item(item)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 0.2, 1)
	mesh.material = _mat(Color(0.2, 0.45, 0.15))
	lib.set_item_mesh(item, mesh)
	lib.set_item_mesh_transform(item, Transform3D(Basis(), Vector3(0, -0.1, 0)))
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 0.2, 1)
	lib.set_item_shapes(item, [shape, Transform3D(Basis(), Vector3(0, -0.1, 0))])


static func _add_ground_desert(lib: MeshLibrary) -> void:
	var item := Tile.GROUND_DESERT
	lib.create_item(item)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 0.2, 1)
	mesh.material = _mat(Color(0.76, 0.65, 0.42))
	lib.set_item_mesh(item, mesh)
	lib.set_item_mesh_transform(item, Transform3D(Basis(), Vector3(0, -0.1, 0)))
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 0.2, 1)
	lib.set_item_shapes(item, [shape, Transform3D(Basis(), Vector3(0, -0.1, 0))])


static func _add_obstacle(lib: MeshLibrary) -> void:
	var item := Tile.OBSTACLE
	lib.create_item(item)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 1, 1)
	mesh.material = _mat(Color(0.5, 0.5, 0.5))
	lib.set_item_mesh(item, mesh)
	lib.set_item_mesh_transform(item, Transform3D(Basis(), Vector3(0, -0.5, 0)))
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	lib.set_item_shapes(item, [shape, Transform3D(Basis(), Vector3(0, -0.5, 0))])


static func _add_water(lib: MeshLibrary) -> void:
	var item := Tile.WATER
	lib.create_item(item)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 0.1, 1)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.4, 0.9, 0.7)
	mesh.material = mat
	lib.set_item_mesh(item, mesh)
	lib.set_item_mesh_transform(item, Transform3D(Basis(), Vector3(0, -0.9, 0)))


static func _add_container(lib: MeshLibrary) -> void:
	var item := Tile.CONTAINER
	lib.create_item(item)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 1, 1)
	mesh.material = _mat(Color(0.8, 0.6, 0.1))
	lib.set_item_mesh(item, mesh)
	lib.set_item_mesh_transform(item, Transform3D(Basis(), Vector3(0, -0.5, 0)))
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	lib.set_item_shapes(item, [shape, Transform3D(Basis(), Vector3(0, -0.5, 0))])


static func _add_pipe(lib: MeshLibrary) -> void:
	var item := Tile.PIPE
	lib.create_item(item)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.4, 0.15, 0.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.6, 0.65)
	mat.metallic = 0.4
	mesh.material = mat
	lib.set_item_mesh(item, mesh)
	lib.set_item_mesh_transform(item, Transform3D(Basis(), Vector3(0, 0.075, 0)))


static func _add_pump(lib: MeshLibrary) -> void:
	var item := Tile.PUMP
	lib.create_item(item)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 0.2, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 0.6)
	mat.metallic = 0.4
	mesh.material = mat
	lib.set_item_mesh(item, mesh)
	lib.set_item_mesh_transform(item, Transform3D(Basis(), Vector3(0, 0.1, 0)))


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m
