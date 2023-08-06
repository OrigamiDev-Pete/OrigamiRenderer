package OrigamiRenderer

import "core:math/linalg"

Vec2 :: linalg.Vector2f32
Vec3 :: linalg.Vector3f32
Vec4 :: linalg.Vector4f32

Mesh_Base :: struct {
    vertices: []Vertex,
    material: ^Material,
}

Mesh :: union {
    Vulkan_Mesh,
}

Vertex :: struct {
    position: Vec2,
    colour: Vec3,
}

Vertex_Attribute_Kind :: enum {
    Position,
    Normal,
    Uv,
    Colour,
    Custom,
}

Vertex_Attribute_Type :: enum {
    Float32,
    Float64,
    Uint8,
    Int8,
    Uint16,
    Int16,
    Uint32,
    Int32,
    Uint64,
    Int64,
}

vertex_attribute_type_size := [Vertex_Attribute_Type]u8 {
    .Float32 = size_of(f32),
    .Float64 = size_of(f64),
    .Uint8   = size_of(u8),
    .Int8    = size_of(i8),
    .Uint16  = size_of(u16),
    .Int16   = size_of(i16),
    .Uint32  = size_of(u32),
    .Int32   = size_of(i32),
    .Uint64  = size_of(u64),
    .Int64   = size_of(i64),
}

Vertex_Layout :: struct {
    attributes: []struct {
        kind: Vertex_Attribute_Kind,
        type: Vertex_Attribute_Type,
        number: u8,
    },
}

default_vertex_layout :: Vertex_Layout{
    {
        { .Position, .Float32, 3 },
        { .Normal,   .Float32, 3 },
        { .Uv,       .Float32, 2 },
        { .Colour,   .Float32, 3 },
    },
}

get_vertex_attribute_type_size :: proc(type: Vertex_Attribute_Type) -> int {
    return cast(int) vertex_attribute_type_size[type]
}

create_mesh :: proc(renderer: ^Renderer, vertices: []Vertex, material: ^Material = nil) -> (^Mesh, Error) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    if material == nil {
        // get default material
    }

    switch r in renderer {
        case Vulkan_Renderer:
            mesh, err := _vk_create_mesh(auto_cast &r, vertices, auto_cast material)
            return auto_cast mesh, err
        case:
            return nil, .Invalid_Renderer
    }
}

destroy_mesh :: proc(mesh: ^Mesh, renderer: Renderer) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    switch r in renderer {
        case Vulkan_Renderer:
            _vk_destroy_mesh(auto_cast mesh, renderer.(Vulkan_Renderer))
    }
}