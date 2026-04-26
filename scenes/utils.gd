class_name Utils

static func collect_aabb(node: Node, parent_xform: Transform3D) -> AABB:
	var result := AABB()
	var first := true
	var local_xform := parent_xform
	if node is Node3D:
		local_xform = parent_xform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			var local_aabb: AABB = mi.mesh.get_aabb()
			var world_aabb: AABB = local_xform * local_aabb
			result = world_aabb
			first = false
	for child in node.get_children():
		var child_aabb := collect_aabb(child, local_xform)
		if child_aabb.size == Vector3.ZERO:
			continue
		if first:
			result = child_aabb
			first = false
		else:
			result = result.merge(child_aabb)
	return result

static func compute_visual_aabb(node: Node3D) -> AABB:
	var result: AABB
	var first := true
	if node is VisualInstance3D:
		var aabb: AABB = node.get_aabb()
		if aabb.size != Vector3.ZERO:
			result = aabb
			first = false
	for child in node.get_children():
		if child is Node3D:
			var child_aabb := compute_visual_aabb(child)
			if child_aabb.size == Vector3.ZERO:
				continue
			child_aabb = child.transform * child_aabb
			if first:
				result = child_aabb
				first = false
			else:
				result = result.merge(child_aabb)
	return result
