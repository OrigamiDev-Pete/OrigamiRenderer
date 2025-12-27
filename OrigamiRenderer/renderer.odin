package OrigamiRenderer

import "core:mem"
import win32 "core:sys/windows"

API :: #config(RENDER_API, Renderer_API.OpenGL)

Colour3 :: [3]f32
Colour4 :: [4]f32

Mesh_Handle :: distinct u32
Shader_Handle :: distinct u32

INVALID_MESH :: Mesh_Handle(0)
INVALID_SHADER :: Shader_Handle(0)

Vertex :: struct {
    position: [3]f32,
    normal:   [3]f32,
    uv:       [2]f32
}

Mesh :: struct {
    vao: u32,
    vbo: u32,
    ibo: u32,
    index_count: i32
}

Renderer :: struct {
    window_info: Window_Info,
    command_allocator: mem.Allocator,
    command_arena: mem.Arena,
    command_queue: [dynamic]Render_Packet,
    shaders: [dynamic]u32,
    meshes: [dynamic]Mesh
}

Renderer_API :: enum u8 {
    OpenGL
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
    device_context: win32.HDC
}

Error :: enum {
    None
}

renderer: Renderer

init_renderer :: proc(window_info: Window_Info) -> (err: Error) {
    bytes := make([]u8, 1 * 1024 * 1024) // 1MB
    mem.arena_init(&renderer.command_arena, bytes)
    renderer.command_allocator = mem.arena_allocator(&renderer.command_arena)
    renderer.command_queue = make([dynamic]Render_Packet, renderer.command_allocator)
    renderer.window_info = window_info

    when API == .OpenGL {
        _gl_init_renderer()
    }

    return
}

deinit_renderer :: proc() {
    delete(renderer.command_arena.data)
    delete(renderer.shaders)
    delete(renderer.meshes)
}

begin_frame :: proc() {

}

end_frame :: proc() {
    // Sort by sort_key here //

    when API == .OpenGL {
        _gl_end_frame()
    }

    free_all(renderer.command_allocator)

    when ODIN_OS == .Windows {
        win32.SwapBuffers(renderer.window_info.(Win32_Window_Info).device_context)
    }
}

resize_viewport :: proc(window_info: Window_Info) {
    renderer.window_info = window_info
}

clear_screen :: proc(colour: Colour4) {
    cmd := Command_Clear { colour = colour, depth = 1.0 }
    append(&renderer.command_queue, Render_Packet { sort_key = 0, command = cmd })
}

load_shader :: proc(vertex_source, fragment_source: string) -> Shader_Handle {
    when API == .OpenGL {
        return _gl_load_shader(vertex_source, fragment_source)
    }
}

set_shader :: proc(shader: Shader_Handle) {
    cmd := Command_Set_Shader { shader }
    append(&renderer.command_queue, Render_Packet { sort_key = 0, command = cmd })
}

create_mesh :: proc(vertices: []Vertex, indices: []u32) -> Mesh_Handle {
    when API == .OpenGL {
        return _gl_create_mesh(vertices, indices)
    }
}

draw_mesh :: proc(mesh: Mesh_Handle) {
    cmd := Command_Draw { mesh }
    append(&renderer.command_queue, Render_Packet { sort_key = 0, command = cmd })
}