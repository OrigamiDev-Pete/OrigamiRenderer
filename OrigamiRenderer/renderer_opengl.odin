package OrigamiRenderer

import "core:dynlib"
import "core:log"

import gl "vendor:OpenGL"
import win32 "core:sys/windows"

import "core:prof/spall"

OpenGL_Renderer :: struct {
    using base: Renderer_Base,
    device_context: win32.HDC
}

_gl_init_renderer :: proc(r: ^OpenGL_Renderer, window_info: Window_Info) -> (err: Error) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    r.window_info = window_info

    set_proc_address :: proc(p: rawptr, name: cstring) {
        opengl_lib: dynlib.Library
        ok: bool
        when ODIN_OS == .Windows {
            opengl_lib, ok = dynlib.load_library("opengl32.dll")
        }
        assert(ok, "Could not find opengl library")
        (^rawptr)(p)^ = dynlib.symbol_address(opengl_lib, string(name))
    }

    // Get OpenGL Procedures
    gl.load_up_to(4, 6, set_proc_address)

    create_context(r, window_info)

    gl.Viewport(0, 0, i32(window_info.?.width), i32(window_info.?.height))

    log.debug("Opengl 4.6 Renderer Initialised.")
    return
}

_gl_destroy_renderer :: proc(r: ^OpenGL_Renderer) {
    trace(&spall_ctx, &spall_buffer, #procedure)
}

_gl_render :: proc(r: ^OpenGL_Renderer) -> (err: Error) {
    trace(&spall_ctx, &spall_buffer, #procedure)

    if (r.framebuffer_resized) {
        update_window_info_size(&r.window_info)
        gl.Viewport(0, 0, i32(r.window_info.?.width), i32(r.window_info.?.height))
    }

    gl.ClearColor(0.2, 0.3, 0.3, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    win32.SwapBuffers(r.device_context)
    return
}

create_context :: proc(r: ^OpenGL_Renderer, window_info: Window_Info) -> (err: Error) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    when ODIN_OS == .Windows {
        pixel_format_descriptor := win32.PIXELFORMATDESCRIPTOR {
            nSize = size_of(win32.PIXELFORMATDESCRIPTOR),
            nVersion = 1,
            dwFlags = win32.PFD_DRAW_TO_WINDOW | win32.PFD_SUPPORT_OPENGL | win32.PFD_DOUBLEBUFFER,
            iPixelType = win32.PFD_TYPE_RGBA,
            cColorBits = 32,
            cDepthBits = 24,
            cStencilBits = 8,
            iLayerType = win32.PFD_MAIN_PLANE
        }

        device_context := win32.GetDC(window_info.(Win32_Window_Info).hwnd)

        pixel_format := win32.ChoosePixelFormat(device_context, &pixel_format_descriptor)
        win32.SetPixelFormat(device_context, pixel_format, &pixel_format_descriptor)

        render_context := win32.wglCreateContext(device_context)
        if render_context == nil {
            log.error("Could not create render context")
            return
        }
        win32.wglMakeCurrent(device_context, render_context)

        r.device_context = device_context
    }
    return
}