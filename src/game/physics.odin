package game

import sa "core:container/small_array"

import m "../math"


X_AXIS :: m.Vec3{1, 0, 0}

Physics :: struct {
	layer: enum u8 {
		None,
		Layer0,
		Layer1,
	},
	mask:  enum u8 {
		None,
		Mask0,
		Mask1,
	},
}

Simplex :: sa.Small_Array(4, m.Vec3)
CollidedWith :: sa.Small_Array(10, eID)

phys_check_collisions :: proc(in_base: ^EntityBase, ids: ^CollidedWith) {
	assert(in_base.phys.layer != .None)
	for &e in world.entities {
		base := cast(^EntityBase)&e
		if base.eid == in_base.eid do continue // skips checking for collision with itself

		if phys_overlapping(in_base, base) {
			sa.append(ids, base.eid)
		}
	}
}

// Using the GJK algorithm
phys_overlapping :: proc(e1, e2: ^EntityBase) -> (is_overlapping: bool) {
	(phys_collidable(e1, e2)) or_return

	shape1 := make([]Pos, e1.geom.vertex_count)
	shape2 := make([]Pos, e2.geom.vertex_count)

	defer delete(shape1)
	defer delete(shape2)

	e1.geom.model_matrix = m.to_matrix(e1.transform)
	e2.geom.model_matrix = m.to_matrix(e2.transform)

	phys_get_positions(e1.geom, shape1)
	phys_get_positions(e2.geom, shape2)

	support := _support(shape1, shape2, X_AXIS)

	simplex: Simplex
	sa.push_front(&simplex, support)

	dir := -support

	for {
		support = _support(shape1, shape2, dir)
		if m.dot(support, dir) < 0 do return false

		sa.push_front(&simplex, support)

		if _next_simplex(&simplex, &dir) do return true
	}
}


phys_get_positions :: proc(geom: Geometry, shape: []Pos) {
	assert(len(shape) == int(geom.vertex_count))

	for i in 0 ..< geom.vertex_count {
		vertex_start := i * geom.vertex_stride

		pos := m.Vec4 {
			geom.vertices[vertex_start],
			geom.vertices[vertex_start + 1],
			geom.vertices[vertex_start + 2],
			1,
		}

		transformed := geom.model_matrix * pos

		shape[i] = {transformed.x, transformed.y, transformed.z}
	}
}

phys_collidable :: proc(e1, e2: ^EntityBase) -> bool {
	(e1.phys.layer != .None) or_return
	(e2.phys.layer != .None) or_return
	(u8(e1.phys.layer) == u8(e2.phys.mask) || u8(e2.phys.layer) == u8(e1.phys.mask)) or_return

	return true
}

_furthest_vertex :: proc(shape: []Pos, dir: m.Vec3) -> (furthest_vertex: Pos) {
	furthest_distance := min(f32)
	for v in shape {
		distance := m.dot(v, dir)
		if distance > furthest_distance {
			furthest_distance = distance
			furthest_vertex = v
		}
	}
	return furthest_vertex
}

_support :: proc(shape1, shape2: []Pos, dir: m.Vec3) -> Pos {
	return _furthest_vertex(shape1, dir) - _furthest_vertex(shape2, -dir)
}

_next_simplex :: proc(simplex: ^Simplex, dir: ^m.Vec3) -> bool {
	switch sa.len(simplex^) {
	case 2:
		return _check_line(simplex, dir)
	case 3:
		return _check_triangle(simplex, dir)
	case 4:
		return _check_tetrahedron(simplex, dir)
	}
	panic("")
}

_check_line :: proc(simplex: ^Simplex, dir: ^m.Vec3) -> bool {
	a := sa.get(simplex^, 0)
	b := sa.get(simplex^, 1)

	ab := b - a
	ao := -a

	if m.same_dir(ab, ao) {
		dir^ = m.cross(m.cross(ab, ao), ab)
	} else {
		sa.clear(simplex)
		sa.append_elems(simplex, a)
		dir^ = ao
	}

	return false
}

_check_triangle :: proc(simplex: ^Simplex, dir: ^m.Vec3) -> bool {
	a := sa.get(simplex^, 0)
	b := sa.get(simplex^, 1)
	c := sa.get(simplex^, 2)

	ab := b - a
	ac := c - a
	ao := -a

	abc := m.cross(ab, ac)

	if m.same_dir(m.cross(abc, ac), ao) {
		if (m.same_dir(ac, ao)) {
			sa.clear(simplex)
			sa.append_elems(simplex, a, c)
			dir^ = m.cross(m.cross(ac, ao), ac)
		} else {
			sa.clear(simplex)
			sa.append_elems(simplex, a, b)
			return _check_line(simplex, dir)
		}
	} else {
		if m.same_dir(m.cross(ab, abc), ao) {
			sa.clear(simplex)
			sa.append_elems(simplex, a, b)
			return _check_line(simplex, dir)
		} else {
			if m.same_dir(abc, ao) {
				dir^ = abc
			} else {
				sa.clear(simplex)
				sa.append_elems(simplex, a, c, b)
				dir^ = -abc
			}
		}
	}
	return false
}

_check_tetrahedron :: proc(simplex: ^Simplex, dir: ^m.Vec3) -> bool {
	a := sa.get(simplex^, 0)
	b := sa.get(simplex^, 1)
	c := sa.get(simplex^, 2)
	d := sa.get(simplex^, 3)

	ab := b - a
	ac := c - a
	ad := d - a
	ao := -a

	abc := m.cross(ab, ac)
	acd := m.cross(ac, ad)
	adb := m.cross(ad, ab)

	if m.same_dir(abc, ao) {
		sa.clear(simplex)
		sa.append_elems(simplex, a, b, c)
		return _check_triangle(simplex, dir)
	}

	if m.same_dir(acd, ao) {
		sa.clear(simplex)
		sa.append_elems(simplex, a, c, d)
		return _check_triangle(simplex, dir)
	}

	if m.same_dir(adb, ao) {
		sa.clear(simplex)
		sa.append_elems(simplex, a, d, b)
		return _check_triangle(simplex, dir)
	}

	return true
}
