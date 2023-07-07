package OrigamiRenderer

Shader :: union {
    Vulkan_Program,
}

create_shader :: proc() -> ^Shader {
    switch render_api {
        case .Vulkan:
            return _vk_create_shader()
    }
    return nil
}

destroy_shader :: proc(shader: ^Shader) {
    free(shader)
}