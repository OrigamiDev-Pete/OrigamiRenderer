package OrigamiRenderer

import "core:runtime"
import vk "vendor:vulkan"
import win32 "core:sys/windows"

@(private)
Renderer_Base :: struct {
    window_info: Window_Info,
}

Renderer :: union {
    Vulkan_Renderer,
}

Window_Info :: union {
    Win32_Window_Info,
}

@(private)
Window_Info_Base :: struct {
    width: int,
    height: int,
}

Win32_Window_Info :: struct {
    using base: Window_Info_Base,
    hwnd: win32.HWND,
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

Renderer_Error :: enum {
    None,
}

Error :: union #shared_nil {
    Renderer_Error,
    Vulkan_Error,
}

@(private)
render_api : Render_API = .Vulkan

@(private)
ctx: ^runtime.Context

set_render_api :: proc(api: Render_API) {
    render_api = api
}

init_renderer :: proc(renderer: ^Renderer, window_info: Window_Info) -> (err: Error) {
    ctx = new_clone(context)
    switch render_api {
        case .Vulkan:
            return _vk_init_renderer(auto_cast renderer, window_info)
    }
    return
}

render :: proc(renderer: ^Renderer) {
    switch render_api {
        case .Vulkan:
            _vk_render(auto_cast renderer)
    }
}

deinit_renderer :: proc(renderer: ^Renderer) {
    defer free(ctx)
    switch render_api {
        case .Vulkan:
            _vk_deinit_renderer(auto_cast renderer)
    }
}
