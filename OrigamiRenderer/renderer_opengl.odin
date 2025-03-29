package OrigamiRenderer

import "core:dynlib"
import "core:log"

import gl "vendor:OpenGL"
import win32 "core:sys/windows"

import "core:prof/spall"

OpenGL_Renderer :: struct {
    using base: Renderer_Base,
}

OpenGL_Error :: enum {
    None,
    Cannot_Create_Shader_Object,
    Cannot_Compile_Shader
}

opengl_lib: dynlib.Library

_gl_init_renderer :: proc(r: ^OpenGL_Renderer, window_info: Window_Info) -> (err: Error) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    r.window_info = window_info

    ok: bool
    when ODIN_OS == .Windows {
        opengl_lib, ok = dynlib.load_library("opengl32.dll")
    }
    assert(ok, "Could not find opengl library")

    set_proc_address :: proc(p: rawptr, name: cstring) {
        when ODIN_OS == .Windows {
            win32.gl_set_proc_address(p, name)
        }
    }

    // Get OpenGL Procedures
    gl.load_up_to(4, 1, set_proc_address)

    gl.Viewport(0, 0, i32(window_info.?.width), i32(window_info.?.height))

    log.debug("Opengl 4.1 Renderer Initialised.")
    return
}

_gl_destroy_renderer :: proc(r: ^OpenGL_Renderer) {
    trace(&spall_ctx, &spall_buffer, #procedure)
}

_gl_render :: proc(r: ^OpenGL_Renderer) -> (err: Error) {
    trace(&spall_ctx, &spall_buffer, #procedure)

    spall._buffer_begin(&spall_ctx, &spall_buffer, "Render pre-Vsync")
    if (r.framebuffer_resized) {
        update_window_info_size(&r.window_info)
        gl.Viewport(0, 0, i32(r.window_info.?.width), i32(r.window_info.?.height))
    }

    gl.ClearColor(0.2, 0.3, 0.3, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT)
    spall._buffer_end(&spall_ctx, &spall_buffer)

    when ODIN_OS == .Windows {
        win32.SwapBuffers(r.window_info.(Win32_Window_Info).device_context)
    }
    return
}