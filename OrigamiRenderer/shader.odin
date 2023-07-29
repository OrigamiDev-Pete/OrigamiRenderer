package OrigamiRenderer

import "core:os"

Shader_Base :: struct {
    hash: u32,
    code: []u8,
}

Shader :: union {
    Vulkan_Shader,
}

Program_Base :: struct {
    vertex_shader: Shader_Handle,
    fragment_shader: Shader_Handle,
}

Program :: union {
    Vulkan_Program,
}

Shader_Handle :: distinct Resource_Handle
Program_Handle :: distinct Resource_Handle

create_shader :: proc(code: []u8) -> (Shader_Handle, Error) {
    switch render_api {
        case .Vulkan:
            return _vk_create_shader(code)
    }
    return 0, .Cannot_Create_Shader_Module
}

destroy_shader :: proc(shader: ^Shader) {
    switch render_api {
        case .Vulkan:
            _vk_destroy_shader(auto_cast shader)
    }
}

load_shader :: proc(path: string) -> (Shader_Handle, Error) {
    code, ok := os.read_entire_file_from_filename(path)
    if !ok do return 0, .Cannot_Load_Shader

    return create_shader(code)
}