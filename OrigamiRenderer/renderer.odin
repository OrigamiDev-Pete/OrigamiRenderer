package OrigamiRenderer

import "core:runtime"
import vk "vendor:vulkan"
import win32 "core:sys/windows"

Colour3 :: [3]f32
Colour4 :: [4]f32

Renderer_Base :: struct {
    window_info: Window_Info,
    clear_colour: Colour4,
    framebuffer_resized: bool,
    skip_render: bool,
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
    // WebGPU,
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

vulkan_renderer :: proc() -> Vulkan_Renderer {
    return Vulkan_Renderer {}
}

init_renderer :: proc(renderer: ^Renderer, window_info: Window_Info) -> (err: Error) {
    ctx = new_clone(context)

    r := cast(^Renderer_Base) renderer
    r.clear_colour = { 0, 0, 0, 1.0 }

    switch render_api {
        case .Vulkan:
            return _vk_init_renderer(auto_cast renderer, window_info)
    }
    return
}

render :: proc(renderer: ^Renderer) -> (err: Error) {
    switch render_api {
        case .Vulkan:
            return _vk_render(auto_cast renderer)
    }
    return
}

deinit_renderer :: proc(renderer: ^Renderer) {
    defer free(ctx)
    switch render_api {
        case .Vulkan:
            _vk_deinit_renderer(auto_cast renderer)
    }
}

update_window_info_size :: proc(window_info: ^Window_Info) {
    when ODIN_OS == .Windows {
        rect: win32.RECT
        wi, ok := &window_info.(Win32_Window_Info)
        if ok {
            win32.GetClientRect(wi.hwnd, &rect)
            wi.width = cast(int) rect.right
            wi.height = cast(int) rect.bottom
        }
    }
}