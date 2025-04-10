#+private
package renderer

import "core:log"
import "core:fmt"
import "core:mem"

import "vendor:wgpu"

import m "pkg:core/math"
import "pkg:core/filesystem/loaded"
import "pkg:core/filesystem/loader"



meshes: map[string]Mesh

Mesh :: struct {
    name: ^string,
    primitives: []Primitive,
}

Primitive :: struct {
    vertices: []Vertex,
    indices: []u32,

    index_count: u32,
    instance_count: u32,
    first_index: u32,
    base_vertex: i32,
    first_instance: u32,

    vertex_buffer: wgpu.Buffer,
    index_buffer: wgpu.Buffer,

    material: Material,

}

Vertex :: struct {
    position: m.Vec4,
    normal: m.Vec3,
    uv: m.Vec2
}

get_mesh :: proc(name: string) -> (mesh: ^Mesh, exists: bool) {
    mesh, exists = &meshes[name]
    if !exists {
        gltf_mesh := loaded.get_mesh(name) or_return
        load_mesh(gltf_mesh) or_return
        mesh, exists = &meshes[name]
    }
    return mesh, exists
}

load_mesh :: proc(mesh: ^loader.Mesh) -> bool {
    if mesh.name in meshes {
        log.error("Mesh already loaded:", mesh.name)
        return false
    }

    new_mesh := Mesh {
        name = &mesh.name,
        primitives = make([]Primitive, len(mesh.primitives)),
    }

    for primitive, i in mesh.primitives {
        vertices := get_vertices(primitive) or_return
        indices := get_indices(primitive) or_return

        vertex_buffer := create_vertex_buffer(vertices) or_return
        index_buffer := create_index_buffer(indices) or_return

        if primitive.material == nil {
            log.error("Primitive has no material")
            return false
        }

        new_mesh.primitives[i] = Primitive {
            vertices = vertices,
            indices = indices,
            index_count = u32(len(indices)),
            instance_count = 1,
            first_index = 0,
            base_vertex = 0,
            first_instance = 0,
            vertex_buffer = vertex_buffer,
            index_buffer = index_buffer,
            material = materials[primitive.material.name],
        }
    }

    meshes[mesh.name] = new_mesh

    log.info("Loaded mesh:", mesh.name)
    return true
}

get_vertices :: proc(primitive: loader.Primitive) -> ([]Vertex, bool) {
    if primitive.attributes == nil {
        log.error("Primitive has no attributes")
        return nil, false
    }

    // Get position, normal, and uv accessors
    position_accessor, has_position := primitive.attributes["POSITION"]
    normal_accessor, has_normal := primitive.attributes["NORMAL"]
    texcoord_accessor, has_texcoord := primitive.attributes["TEXCOORD_0"]

    if !has_position {
        log.error("Primitive has no position attribute")
        return nil, false
    }

    // Create vertices array
    vertex_count := int(position_accessor.count)
    vertices := make([]Vertex, vertex_count)

    // Get position data
    if has_position {
        buffer_view := position_accessor.buffer_view
        if buffer_view == nil || buffer_view.buffer == nil {
            log.error("Position accessor has no buffer view or buffer")
            delete(vertices)
            return nil, false
        }

        buffer_data := buffer_view.buffer.data
        offset := position_accessor.offset + buffer_view.offset

        for i in 0..<vertex_count {
            // Calculate the offset for this vertex
            idx := offset + uint(i) * size_of(m.Vec3)
            if idx + size_of(m.Vec3) > uint(len(buffer_data)) {
                log.error("Position data out of bounds")
                delete(vertices)
                return nil, false
            }

            // Copy position data (Vec3) to vertex position (Vec4)
            pos: m.Vec3
            mem.copy(&pos, &buffer_data[idx], size_of(m.Vec3))
            vertices[i].position = m.Vec4{pos.x, pos.y, pos.z, 1.0}
        }
    }

    // Get normal data
    if has_normal {
        buffer_view := normal_accessor.buffer_view
        if buffer_view == nil || buffer_view.buffer == nil {
            log.error("Normal accessor has no buffer view or buffer")
            delete(vertices)
            return nil, false
        }

        buffer_data := buffer_view.buffer.data
        offset := normal_accessor.offset + buffer_view.offset

        for i in 0..<vertex_count {
            // Calculate the offset for this vertex
            idx := offset + uint(i) * size_of(m.Vec3)
            if idx + size_of(m.Vec3) > uint(len(buffer_data)) {
                log.error("Normal data out of bounds")
                delete(vertices)
                return nil, false
            }

            // Copy normal data
            mem.copy(&vertices[i].normal, &buffer_data[idx], size_of(m.Vec3))
        }
    } else {
        // Default normals if not provided
        for i in 0..<vertex_count {
            vertices[i].normal = m.Vec3{0, 1, 0} // Default up vector
        }
    }

    // Get UV data
    if has_texcoord {
        buffer_view := texcoord_accessor.buffer_view
        if buffer_view == nil || buffer_view.buffer == nil {
            log.error("Texcoord accessor has no buffer view or buffer")
            delete(vertices)
            return nil, false
        }

        buffer_data := buffer_view.buffer.data
        offset := texcoord_accessor.offset + buffer_view.offset

        for i in 0..<vertex_count {
            // Calculate the offset for this vertex
            idx := offset + uint(i) * size_of(m.Vec2)
            if idx + size_of(m.Vec2) > uint(len(buffer_data)) {
                log.error("Texcoord data out of bounds")
                delete(vertices)
                return nil, false
            }

            // Copy texcoord data
            mem.copy(&vertices[i].uv, &buffer_data[idx], size_of(m.Vec2))
        }
    } else {
        // Default UVs if not provided
        for i in 0..<vertex_count {
            vertices[i].uv = m.Vec2{0, 0} // Default UV
        }
    }

    return vertices, true
}

get_indices :: proc(primitive: loader.Primitive) -> ([]u32, bool) {
    if primitive.indices == nil {
        log.error("Primitive is nil")
        return nil, false
    }

    // Check if primitive has indices
    if primitive.indices == nil {
        log.error("Primitive has no indices")
        return nil, false
    }

    indices_accessor := primitive.indices
    buffer_view := indices_accessor.buffer_view

    if buffer_view == nil || buffer_view.buffer == nil {
        log.error("Indices accessor has no buffer view or buffer")
        return nil, false
    }

    buffer_data := buffer_view.buffer.data
    offset := indices_accessor.offset + buffer_view.offset
    index_count := int(indices_accessor.count)

    // Create indices array
    indices := make([]u32, index_count)

    // Copy indices based on component type
    #partial switch indices_accessor.component_type {
    case .r_8u:
        for i in 0..<index_count {
            idx := offset + uint(i) * 1
            if idx >= uint(len(buffer_data)) {
                log.error("Index data out of bounds")
                delete(indices)
                return nil, false
            }
            indices[i] = u32(buffer_data[idx])
        }
    case .r_16u:
        for i in 0..<index_count {
            idx := offset + uint(i) * 2
            if idx + 1 >= uint(len(buffer_data)) {
                log.error("Index data out of bounds")
                delete(indices)
                return nil, false
            }
            // Convert 2 bytes to u16, then to u32
            value: u16 = u16(buffer_data[idx]) | (u16(buffer_data[idx+1]) << 8)
            indices[i] = u32(value)
        }
    case .r_32u:
        for i in 0..<index_count {
            idx := offset + uint(i) * 4
            if idx + 3 >= uint(len(buffer_data)) {
                log.error("Index data out of bounds")
                delete(indices)
                return nil, false
            }
            // Convert 4 bytes to u32
            value: u32 = u32(buffer_data[idx]) |
                    (u32(buffer_data[idx+1]) << 8) |
                    (u32(buffer_data[idx+2]) << 16) |
                    (u32(buffer_data[idx+3]) << 24)
            indices[i] = value
        }
    case:
        log.error("Unsupported index component type:", indices_accessor.component_type)
        delete(indices)
        return nil, false
    }

    return indices, true
}

create_vertex_buffer :: proc(vertices: []Vertex) -> (wgpu.Buffer, bool) {
    if len(vertices) == 0 {
        log.error("No vertices to create buffer for")
        return {}, false
    }

    // Calculate buffer size
    buffer_size := len(vertices) * size_of(Vertex)

    // Create buffer descriptor
    buffer_desc := wgpu.BufferDescriptor {
        size = u64(buffer_size),
        usage = {.Vertex, .CopyDst},
        label = "Vertex Buffer",
    }

    // Create buffer
    buffer := wgpu.DeviceCreateBuffer(state.device, &buffer_desc)
    if buffer == nil {
        log.error("Failed to create vertex buffer")
        return {}, false
    }

    // Write vertex data to buffer
    wgpu.QueueWriteBuffer(state.queue, buffer, 0, &vertices[0], uint(buffer_size))

    return buffer, true
}

create_index_buffer :: proc(indices: []u32) -> (wgpu.Buffer, bool) {
    if len(indices) == 0 {
        log.error("No indices to create buffer for")
        return {}, false
    }

    // Calculate buffer size
    buffer_size := len(indices) * size_of(u32)

    // Create buffer descriptor
    buffer_desc := wgpu.BufferDescriptor {
        size = u64(buffer_size),
        usage = {.Index, .CopyDst},
        label = "Index Buffer",
    }

    // Create buffer
    buffer := wgpu.DeviceCreateBuffer(state.device, &buffer_desc)
    if buffer == nil {
        log.error("Failed to create index buffer")
        return {}, false
    }

    // Write index data to buffer
    wgpu.QueueWriteBuffer(state.queue, buffer, 0, &indices[0], uint(buffer_size))

    return buffer, true
}