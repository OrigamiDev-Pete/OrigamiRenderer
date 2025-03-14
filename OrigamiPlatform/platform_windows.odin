#+build windows
#+private
package OrigamiPlatform

import "core:fmt"
import "base:runtime"
import "core:unicode/utf16"
import win32 "core:sys/windows"

origamiWindow: ^Win32_Window = nil

CLASS_NAME :: "Origami Window Class"

window_proc :: proc "stdcall" (hWnd: win32.HWND, msg: win32.UINT, wParam: win32.WPARAM, lParam: win32.LPARAM) -> win32.LRESULT {
    context = origamiWindow.odin_context^

    switch msg {
        case win32.WM_SIZE: {
            when ODIN_DEBUG {
                fmt.println("WM_SIZE")
            }
            width := win32.LOWORD(cast(win32.DWORD)lParam)
            height := win32.HIWORD(cast(win32.DWORD)lParam)
            if origamiWindow.callbacks.on_resize != nil {
                origamiWindow.callbacks.on_resize(cast(^Window) origamiWindow, width, height)
            }

            return 0
        }
        case win32.WM_CLOSE: {
            when ODIN_DEBUG {
                fmt.println("WM_CLOSE")
            }
            if origamiWindow.callbacks.on_close != nil do origamiWindow.callbacks.on_close(cast(^Window) origamiWindow)
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

_create_window :: proc(width, height: i32, title: string, x, y: i32) -> (^Window, Window_Error) {
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
    origamiWindow = auto_cast window

    hWnd := win32.CreateWindowW(wc.lpszClassName, &utf16_title[0], win32.WS_OVERLAPPEDWINDOW, x, y, width, height, nil, nil, wc.hInstance, nil)

    if hWnd == nil {
        return auto_cast window, .Failed
    }

    w := &window.(Win32_Window)
    w.window_handle = hWnd

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
    return cast(bool) should_quit
}

_get_window_size :: proc(window: Win32_Window) -> (int, int) {
    rect: win32.RECT
    win32.GetClientRect(window.window_handle, &rect)

    return  int(rect.right), int(rect.bottom)
}