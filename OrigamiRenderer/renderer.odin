package OrigamiRenderer

import "core:runtime"
import vk "vendor:vulkan"

Renderer :: struct {
    vk: Vulkan_Properties,
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
    // Vulkan
    Cannot_Create_Instance,
    Validation_Layer_Not_Supported,
    Cannot_Create_Debug_Messenger,
    Cannot_Find_Vulkan_Device,

}

@(private)
render_api : Render_API = .Vulkan

@(private)
ctx: ^runtime.Context

set_render_api :: proc(api: Render_API) {
    render_api = api
}

init_renderer :: proc(renderer: ^Renderer) -> (err: Error) {
    ctx = new_clone(context)
    switch render_api {
        case .Vulkan:
            return _vk_init_renderer(renderer)
    }
    return
}

render :: proc(renderer: ^Renderer) {
    switch render_api {
        case .Vulkan:
            _vk_render(renderer)
    }
}

deinit_renderer :: proc(renderer: ^Renderer) {
    defer free(ctx)
    switch render_api {
        case .Vulkan:
            _vk_deinit_renderer(renderer)
    }
}
