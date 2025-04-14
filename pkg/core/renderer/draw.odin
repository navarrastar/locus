#+private
package renderer

import "core:fmt"
import "core:mem"
import "core:log"

import "pkg:game"
import m "pkg:core/math"
import "pkg:core/window"
import geo "pkg:core/geometry"



draw_render_data :: proc (using rd: ^RenderData) {
    for mesh in  meshes {
        draw(mesh)
    }
    for triangle in triangles {
        draw(triangle)
    }
    for pyramid in pyramids {
        draw(pyramid)
    }
    for rectangle in rectangles {
        draw(rectangle)
    }
    for cube in cubes {
        draw(cube)
    }
    for circle in circles {
        draw(circle)
    }
    for sphere in spheres {
        draw(sphere)
    }
    for capsule in capsules {
        draw(capsule)
    }
    for cylinder in cylinders {
        draw(cylinder)
    }
}

draw :: proc{ 
    draw_mesh, 
    draw_triangle, 
    draw_pyramid, 
    draw_rectangle, 
    draw_cube, 
    draw_circle, 
    draw_sphere, 
    draw_capsule, 
    draw_cylinder,
}

draw_mesh :: proc(geo.Mesh) {

}

draw_triangle :: proc(geo.Triangle) {

}

draw_pyramid :: proc(geo.Pyramid) {

}

draw_rectangle :: proc(geo.Rectangle) {

}

draw_cube :: proc(geo.Cube) {

}

draw_circle :: proc(geo.Circle) {

}

draw_sphere :: proc(geo.Sphere) {

}

draw_capsule :: proc(geo.Capsule) {

}

draw_cylinder :: proc(geo.Cylinder) {

}
