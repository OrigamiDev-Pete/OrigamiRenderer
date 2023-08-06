package OrigamiRenderer

import "core:log"
import "core:mem"

import vk "vendor:vulkan"

Vulkan_Mesh :: struct {
    using base: Mesh_Base,
    vertex_buffer: vk.Buffer,
    vertex_buffer_memory: vk.DeviceMemory,
}

vk_vertex_attribute_format_map := [Vertex_Attribute_Type][]vk.Format {
    .Float32 = { .R32_SFLOAT, .R32G32_SFLOAT, .R32G32B32_SFLOAT, .R32G32B32A32_SFLOAT },
    .Float64 = { .R64_SFLOAT, .R64G64_SFLOAT, .R64G64B64_SFLOAT, .R64G64B64A64_SFLOAT },
    .Uint8   = { .R8_UINT, .R8G8_UINT, .R8G8B8_UINT, .R8G8B8A8_UINT },
    .Int8    = { .R8_SINT, .R8G8_SINT, .R8G8B8_SINT, .R8G8B8A8_SINT },
    .Uint16  = { .R16_UINT, .R16G16_UINT, .R16G16B16_UINT, .R16G16B16A16_UINT },
    .Int16   = { .R16_SINT, .R16G16_SINT, .R16G16B16_SINT, .R16G16B16A16_SINT },
    .Uint32  = { .R32_UINT, .R32G32_UINT, .R32G32B32_UINT, .R32G32B32A32_UINT },
    .Int32   = { .R32_SINT, .R32G32_SINT, .R32G32B32_SINT, .R32G32B32A32_SINT },
    .Uint64  = { .R64_UINT, .R64G64_UINT, .R64G64B64_UINT, .R64G64B64A64_UINT },
    .Int64   = { .R64_SINT, .R64G64_SINT, .R64G64B64_SINT, .R64G64B64A64_SINT },
}

_vk_create_mesh :: proc(r: ^Vulkan_Renderer, vertices: []Vertex, material: ^Vulkan_Material) -> (m: ^Vulkan_Mesh, err: Vulkan_Error) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    mesh := new(Mesh)
    mesh^ = Vulkan_Mesh {
        vertices = vertices,
        material = auto_cast material,
    }

    vk_mesh := &mesh.(Vulkan_Mesh)

    append(&r.meshes, mesh)

    buffer_info := vk.BufferCreateInfo {
        sType = .BUFFER_CREATE_INFO,
        size = cast(vk.DeviceSize) (size_of(Vertex) * len(vertices)),
        usage = { .VERTEX_BUFFER },
        sharingMode = .EXCLUSIVE,
    }

    if vk.CreateBuffer(r.device, &buffer_info, nil, &vk_mesh.vertex_buffer) != .SUCCESS {
        log.error("Failed to create vertex buffer.")
        return nil, .Cannot_Create_Buffer
    }

    memory_requirements: vk.MemoryRequirements
    vk.GetBufferMemoryRequirements(r.device, vk_mesh.vertex_buffer, &memory_requirements)

    memory_type_index := find_memory_type(r^, memory_requirements.memoryTypeBits, { .HOST_VISIBLE, .HOST_COHERENT }) or_return
    allocation_info := vk.MemoryAllocateInfo {
        sType = .MEMORY_ALLOCATE_INFO,
        allocationSize = memory_requirements.size,
        memoryTypeIndex = memory_type_index,
    }

    if vk.AllocateMemory(r.device, &allocation_info, nil, &vk_mesh.vertex_buffer_memory) != .SUCCESS {
        log.error("Failed to allocate vertex buffer memory.")
        return nil, .Cannot_Allocate_Memory
    }

    vk.BindBufferMemory(r.device, vk_mesh.vertex_buffer, vk_mesh.vertex_buffer_memory, 0)

    data: rawptr
    vk.MapMemory(r.device, vk_mesh.vertex_buffer_memory, 0, buffer_info.size, {}, &data)
    mem.copy(data, raw_data(vertices), len(vertices) * size_of(Vertex))
    vk.UnmapMemory(r.device, vk_mesh.vertex_buffer_memory)

    return auto_cast mesh, .None
}

_vk_destroy_mesh :: proc(mesh: ^Vulkan_Mesh, r: Vulkan_Renderer) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    vk.DestroyBuffer(r.device, mesh.vertex_buffer, nil)
    vk.FreeMemory(r.device, mesh.vertex_buffer_memory, nil)
    delete(mesh.vertices)
    free(mesh)
}