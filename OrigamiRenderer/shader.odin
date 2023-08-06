package OrigamiRenderer

import "core:os"

Shader_Base :: struct {
    hash: u32,
    code: []u8,
}

/**
* Represents a stage of a Program
*/
Shader :: union {
    Vulkan_Shader,
}

Program_Base :: struct {
    vertex_shader: ^Shader,
    fragment_shader: ^Shader,
}

Program :: union {
    Vulkan_Program,
}

Material_Base :: struct {
    program: ^Program,
}

Material :: union {
    Vulkan_Material,
}

Shader_Handle :: Resource_Handle
Program_Handle :: Resource_Handle

create_shader :: proc(renderer: ^Renderer, code: []u8) -> (^Shader, Error) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    switch r in renderer {
        case Vulkan_Renderer:
            shader, err := _vk_create_shader(&r, code)
            return auto_cast shader, err
        case:
            return nil, .Invalid_Renderer
    }
}

destroy_shader :: proc(renderer: Renderer, shader: ^Shader) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    switch r in renderer {
        case Vulkan_Renderer:
            _vk_destroy_shader(r, auto_cast shader)
    }
}

load_shader :: proc(renderer: ^Renderer, path: string) -> (^Shader, Error) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    code, ok := os.read_entire_file_from_filename(path)
    if !ok do return nil, .Cannot_Load_Shader

    return create_shader(renderer, code)
}

create_program :: proc(renderer: ^Renderer, vertex_shader, fragment_shader: ^Shader) -> (^Program, Error) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    switch r in renderer {
        case Vulkan_Renderer:
            program, err := _vk_create_program(&r, auto_cast vertex_shader, auto_cast fragment_shader)
            return auto_cast program, err
        case:
            return nil, .Invalid_Renderer
    }
}

create_material :: proc(renderer: ^Renderer, program: ^Program, vertex_layout: Vertex_Layout = default_vertex_layout) -> (^Material, Error) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    switch r in renderer {
        case Vulkan_Renderer:
            material, err := _vk_create_material(&r, auto_cast program, vertex_layout)
            return auto_cast material, err
        case:
            return nil, .Invalid_Renderer
    }
}