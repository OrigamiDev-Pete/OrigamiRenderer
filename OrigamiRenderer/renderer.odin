package OrigamiRenderer

import vk "vendor:vulkan"

Renderer :: struct {
    vk_instance: vk.Instance
}

Render_API :: enum {
    Vulkan,
    // OpenGL,
    // D3D11,
    // D3D12,
    // Metal,
    // WebGL,
    // WGPU,
}

Error :: enum {
    Success,
    Cannot_Create_Instance
}

@(private)
render_api : Render_API = .Vulkan

set_render_api :: proc(api: Render_API) {
    render_api = api
}

init_renderer :: proc(renderer: ^Renderer) {
    switch render_api {
        case .Vulkan:
            _vk_init_renderer(renderer)
    }
}

render :: proc(renderer: ^Renderer) {
    switch render_api {
        case .Vulkan:
            _vk_render(renderer)
    }
}

deinit_renderer :: proc(renderer: ^Renderer) {
    switch render_api {
        case .Vulkan:
            _vk_deinit_renderer(renderer)
    }
}
