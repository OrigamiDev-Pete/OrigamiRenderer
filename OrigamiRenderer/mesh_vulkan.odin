package OrigamiRenderer

import vk "vendor:vulkan"

Vulkan_Mesh :: struct {
    using base: Mesh_Base,
    buffer: vk.Buffer,
}

vk_vertex_attribute_format_map := [Vertex_Attribute_Type][]vk.Format {
    .Float32 = { .R32_SFLOAT, .R32G32_SFLOAT, .R32G32_SFLOAT, .R32G32B32A32_SFLOAT },
    .Float64 = { .R64_SFLOAT, .R64G64_SFLOAT, .R64G64_SFLOAT, .R64G64B64A64_SFLOAT },
    .Uint8   = { .R8_UINT, .R8G8_UINT, .R8G8_UINT, .R8G8B8A8_UINT },
    .Int8    = { .R8_SINT, .R8G8_SINT, .R8G8_SINT, .R8G8B8A8_SINT },
    .Uint16  = { .R16_UINT, .R16G16_UINT, .R16G16_UINT, .R16G16B16A16_UINT },
    .Int16   = { .R16_SINT, .R16G16_SINT, .R16G16_SINT, .R16G16B16A16_SINT },
    .Uint32  = { .R32_UINT, .R32G32_UINT, .R32G32_UINT, .R32G32B32A32_UINT },
    .Int32   = { .R32_SINT, .R32G32_SINT, .R32G32_SINT, .R32G32B32A32_SINT },
    .Uint64  = { .R64_UINT, .R64G64_UINT, .R64G64_UINT, .R64G64B64A64_UINT },
    .Int64   = { .R64_SINT, .R64G64_SINT, .R64G64_SINT, .R64G64B64A64_SINT },
}

vk_create_mesh :: proc(r: ^Vulkan_Renderer, vertices: []Vertex, material: ^Material) -> (^Vulkan_Mesh, Vulkan_Error) {
    mesh := new(Mesh)
    mesh^ = Vulkan_Mesh {
        vertices = vertices,
        material = material,
    }

    append(&r.meshes, mesh)


    
    return auto_cast mesh, .None
}