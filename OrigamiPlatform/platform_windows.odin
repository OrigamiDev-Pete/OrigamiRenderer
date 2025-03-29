#+build windows
#+private
package OrigamiPlatform

import "core:c"
import "core:fmt"
import "core:log"
import "base:runtime"
import "core:strings"
import "core:unicode/utf16"
import win32 "core:sys/windows"

import gl "vendor:OpenGL"

origami_window: ^Win32_Window = nil

CLASS_NAME :: "Origami Window Class"

window_proc :: proc "stdcall" (hWnd: win32.HWND, msg: win32.UINT, wParam: win32.WPARAM, lParam: win32.LPARAM) -> win32.LRESULT {
    context = origami_window.odin_context^

    switch msg {
        case win32.WM_SIZE: {
            when ODIN_DEBUG {
                fmt.println("WM_SIZE")
            }
            width := win32.LOWORD(cast(win32.DWORD)lParam)
            height := win32.HIWORD(cast(win32.DWORD)lParam)
            if origami_window.callbacks.on_resize != nil {
                origami_window.callbacks.on_resize(cast(^Window) origami_window, width, height)
            }

            return 0
        }
        case win32.WM_CLOSE: {
            when ODIN_DEBUG {
                fmt.println("WM_CLOSE")
            }
            if origami_window.callbacks.on_close != nil do origami_window.callbacks.on_close(cast(^Window) origami_window)
            win32.DestroyWindow(hWnd)
            return 0
        }
        case win32.WM_DESTROY: {
            when ODIN_DEBUG {
                fmt.println("WM_DESTROY")
            }
            win32.PostQuitMessage(0)
            return 0
        }
        case: {
            return win32.DefWindowProcW(hWnd, msg, wParam, lParam)
        }
    }
}

_create_window :: proc(width, height: i32, title: string, x, y: i32, should_create_context := true) -> (^Window, Window_Error) {
    // Register the window class.
    class_name := win32.L(CLASS_NAME)

    wc: win32.WNDCLASSW
    wc.style = win32.CS_HREDRAW | win32.CS_VREDRAW | win32.CS_OWNDC
    wc.lpfnWndProc = window_proc
    wc.hInstance = cast(win32.HINSTANCE) win32.GetModuleHandleW(nil)
    wc.lpszClassName = &class_name[0]
    wc.hCursor = win32.LoadCursorW(nil, cast([^]u16)&win32.IDC_ARROW)

    win32.RegisterClassW(&wc)

    utf16_title := make([]u16, len(title), context.temp_allocator)
    utf16.encode_string(utf16_title[:], title) 

    ctx := new_clone(context)
    window := new(Window)
    window^ = Win32_Window {
        width = width,
        height = height,
        title = title,
        x = x,
        y = y,
        callbacks = {},
        odin_context = ctx,
    }
    origami_window = auto_cast window

    hWnd := win32.CreateWindowW(wc.lpszClassName, &utf16_title[0], win32.WS_OVERLAPPEDWINDOW, x, y, width, height, nil, nil, wc.hInstance, nil)

    if hWnd == nil {
        return auto_cast window, .Failed
    }

    w := &window.(Win32_Window)
    w.window_handle = hWnd

    if should_create_context do create_context()

    win32.ShowWindow(hWnd, win32.SW_SHOWDEFAULT)

    return auto_cast window, .None
}

_destroy_window :: proc(window: ^Win32_Window) {
    free(window.odin_context)
    free(window)
}

_window_should_close :: proc(window: ^Win32_Window) -> bool {
    should_quit := false
    msg: win32.MSG
    for win32.PeekMessageW(&msg, nil, 0, 0, win32.PM_REMOVE) {
        should_quit = msg.message == win32.WM_QUIT
        win32.TranslateMessage(&msg)
        win32.DispatchMessageW(&msg)
    }
    return should_quit
}

_get_window_size :: proc(window: Win32_Window) -> (int, int) {
    rect: win32.RECT
    win32.GetClientRect(window.window_handle, &rect)

    return  int(rect.right), int(rect.bottom)
}

create_context :: proc() -> (err: Window_Error) {
    // Create dummy context to load OpenGL 

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

    device_context := win32.GetDC(origami_window.window_handle)

    pixel_format := win32.ChoosePixelFormat(device_context, &pixel_format_descriptor)
    win32.SetPixelFormat(device_context, pixel_format, &pixel_format_descriptor)

    render_context := win32.wglCreateContext(device_context)
    if render_context == nil {
        log.error("Could not create dummy render context")
        return
    }
    win32.wglMakeCurrent(device_context, render_context)

    gl.load_1_0(win32.gl_set_proc_address)
    // win32.gl_set_proc_address(&gl.impl_GetError, "glGetError")
    // win32.gl_set_proc_address(&gl.impl_GetIntegerv, "glGetIntegerv")
    version: i32
    gl.GetIntegerv(gl.MAJOR_VERSION, &version)

    // If we only acquire a 1.0 context we need to create a newer context directly.
    if (version <= 1) {
        win32.gl_set_proc_address(&win32.wglGetExtensionsStringARB, "wglGetExtensionsStringARB")
        available_extensions_string := win32.wglGetExtensionsStringARB(device_context)

        available_extensions := strings.split(string(available_extensions_string), " ")
        defer delete(available_extensions)
        for extension in available_extensions {
            switch extension {
                case "WGL_ARB_create_context":
                    win32.gl_set_proc_address(&win32.wglCreateContextAttribsARB, "wglCreateContextAttribsARB")
                case "WGL_EXT_swap_control":
                    win32.gl_set_proc_address(&win32.wglSwapIntervalEXT, "wglSwapIntervalEXT")
                case "WGL_ARB_pixel_format":
                    win32.gl_set_proc_address(&win32.wglChoosePixelFormatARB, "wglChoosePixelFormatARB")

            }
        }

        pixel_attribute_list := []c.int{
            win32.WGL_DRAW_TO_WINDOW_ARB, 1,
            win32.WGL_SUPPORT_OPENGL_ARB, 1,
            win32.WGL_DOUBLE_BUFFER_ARB, 1,
            win32.WGL_PIXEL_TYPE_ARB, win32.WGL_TYPE_RGBA_ARB,
            win32.WGL_COLOR_BITS_ARB, 32,
            win32.WGL_DEPTH_BITS_ARB, 24,
            win32.WGL_STENCIL_BITS_ARB, 8,
            0 // End
        }

        pixel_format: c.int = ---
        number_of_formats: win32.DWORD = ---
        if !win32.wglChoosePixelFormatARB(
            device_context,
            raw_data(pixel_attribute_list),
            nil,
            1,
            &pixel_format,
            &number_of_formats) {
                log.error("Could not choose a pixel format.")
                return .Failed
            }

        if !win32.SetPixelFormat(device_context, pixel_format, &pixel_format_descriptor) {
                log.error("Could not set the pixel format")
                return .Failed
        }

        context_attribute_list := []c.int {
            win32.WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
            win32.WGL_CONTEXT_MINOR_VERSION_ARB, 1,
            0 // End
        }

        // Delete the dummy context
        win32.wglDeleteContext(render_context)

        render_context := win32.wglCreateContextAttribsARB(device_context, nil, raw_data(context_attribute_list))
        if !win32.wglMakeCurrent(device_context, render_context) {
            log.error("Could not make render context current.")
            return .Failed
        }
    }


    origami_window.device_context = device_context
    origami_window.render_context = render_context

    return
}