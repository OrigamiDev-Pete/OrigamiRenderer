package OrigamiRenderer

import "core:runtime"
import "core:math/linalg/glsl"

import vk "vendor:vulkan"
import win32 "core:sys/windows"

import "core:prof/spall"
spall_ctx: spall.Context
spall_buffer: spall.Buffer
spall_backing_buffer: []u8

TRACE :: #config(TRACE, false)
when TRACE {
    trace :: spall.SCOPED_EVENT
} else {
    trace :: proc(_: ^spall.Context, _: ^spall.Buffer, _: string) {}
}

Colour3 :: [3]f32
Colour4 :: [4]f32

Renderer_Base :: struct {
    window_info: Window_Info,
    clear_colour: Colour4,
    framebuffer_resized: bool,
    skip_render: bool,
    meshes: [dynamic]^Mesh,
    materials: [dynamic]^Material,
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
    Cannot_Load_Shader,
    Invalid_Renderer,
}

Error :: union #shared_nil {
    Renderer_Error,
    Vulkan_Error,
}

renderer: ^Renderer

@(private)
ctx: ^runtime.Context

create_renderer :: proc(type: Render_API) -> ^Renderer {
    trace(&spall_ctx, &spall_buffer, #procedure)
    switch type {
        case .Vulkan:
            renderer = new(Renderer)
            renderer^ = Vulkan_Renderer{}
            return renderer
        case:
            return renderer
    }
}

init_renderer :: proc(renderer: ^Renderer, window_info: Window_Info) -> (err: Error) {
    ctx = new_clone(context)

    when TRACE {
        spall_ctx = spall.context_create("renderer.spall")
        spall_backing_buffer = make([]u8, spall.BUFFER_DEFAULT_SIZE)
        spall_buffer = spall.buffer_create(spall_backing_buffer)
        spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
    }

    r := cast(^Renderer_Base) renderer
    r.clear_colour = { 0, 0, 0, 1.0 }

    switch r in renderer {
        case Vulkan_Renderer:
            return _vk_init_renderer(auto_cast renderer, window_info)
    }
    return
}

render :: proc(renderer: ^Renderer) -> (err: Error) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    switch r in renderer {
        case Vulkan_Renderer:
            return _vk_render(auto_cast renderer)
    }
    return
}

destroy_renderer :: proc(renderer: ^Renderer) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    defer free(ctx)
    switch r in renderer {
        case Vulkan_Renderer:
            _vk_destroy_renderer(auto_cast renderer)
    }

    r := cast(^Renderer_Base) renderer
    delete(r.meshes)
    delete(r.materials)

    free(renderer)

    when TRACE {
        spall.buffer_destroy(&spall_ctx, &spall_buffer)
        spall.context_destroy(&spall_ctx)
        delete(spall_backing_buffer)
    }
}

update_window_info_size :: proc(window_info: ^Window_Info) {
    trace(&spall_ctx, &spall_buffer, #procedure)
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