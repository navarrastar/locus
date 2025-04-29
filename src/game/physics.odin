package game

import "core:container/small_array"
import "core:fmt"
import "core:log"

import m "../math"


X_AXIS :: m.Vec3{1, 0, 0}

Physics :: struct {
    layer: enum { LAYER_0, LAYER_1 }
}

Simplex :: small_array.Small_Array(4, m.Vec3)

// Using the GJK algorithm
phys_overlapping :: proc(e1, e2: ^Entity) -> (is_overlapping: bool) {
    (e1.physics.layer == e2.physics.layer) or_return
    
    shape1 := make([]Pos, e1.geometry.vertex_count)
	shape2 := make([]Pos, e2.geometry.vertex_count)

	defer delete(shape1)
	defer delete(shape2)

	e1.geometry.model_matrix = m.to_matrix(e1.transform)
	e2.geometry.model_matrix = m.to_matrix(e2.transform)

	phys_get_positions(e1.geometry, shape1)
	phys_get_positions(e2.geometry, shape2)

	support := _support(shape1, shape2, X_AXIS)

	simplex: Simplex
	small_array.push_front(&simplex, support)

	dir := -support

	for {
		support = _support(shape1, shape2, dir)
		if m.dot(support, dir) < 0 do return false

		small_array.push_front(&simplex, support)

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
	switch small_array.len(simplex^) {
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
	a := small_array.get(simplex^, 0)
	b := small_array.get(simplex^, 1)

	ab := b - a
	ao := -a

	if m.same_dir(ab, ao) {
		dir^ = m.cross(m.cross(ab, ao), ab)
	} else {
		small_array.clear(simplex)
		small_array.append_elems(simplex, a)
		dir^ = ao
	}

	return false
}

_check_triangle :: proc(simplex: ^Simplex, dir: ^m.Vec3) -> bool {
	a := small_array.get(simplex^, 0)
	b := small_array.get(simplex^, 1)
	c := small_array.get(simplex^, 2)

	ab := b - a
	ac := c - a
	ao := -a

	abc := m.cross(ab, ac)

	if m.same_dir(m.cross(abc, ac), ao) {
		if (m.same_dir(ac, ao)) {
			small_array.clear(simplex)
			small_array.append_elems(simplex, a, c)
			dir^ = m.cross(m.cross(ac, ao), ac)
		} else {
			small_array.clear(simplex)
			small_array.append_elems(simplex, a, b)
			return _check_line(simplex, dir)
		}
	} else {
		if m.same_dir(m.cross(ab, abc), ao) {
			small_array.clear(simplex)
			small_array.append_elems(simplex, a, b)
			return _check_line(simplex, dir)
		} else {
			if m.same_dir(abc, ao) {
				dir^ = abc
			} else {
				small_array.clear(simplex)
				small_array.append_elems(simplex, a, c, b)
				dir^ = -abc
			}
		}
	}
	return false
}

_check_tetrahedron :: proc(simplex: ^Simplex, dir: ^m.Vec3) -> bool {
	a := small_array.get(simplex^, 0)
	b := small_array.get(simplex^, 1)
	c := small_array.get(simplex^, 2)
	d := small_array.get(simplex^, 3)

	ab := b - a
	ac := c - a
	ad := d - a
	ao := -a

	abc := m.cross(ab, ac)
	acd := m.cross(ac, ad)
	adb := m.cross(ad, ab)

	if m.same_dir(abc, ao) {
		small_array.clear(simplex)
		small_array.append_elems(simplex, a, b, c)
		return _check_triangle(simplex, dir)
	}

	if m.same_dir(acd, ao) {
		small_array.clear(simplex)
		small_array.append_elems(simplex, a, c, d)
		return _check_triangle(simplex, dir)
	}

	if m.same_dir(adb, ao) {
		small_array.clear(simplex)
		small_array.append_elems(simplex, a, d, b)
		return _check_triangle(simplex, dir)
	}

	return true
}
