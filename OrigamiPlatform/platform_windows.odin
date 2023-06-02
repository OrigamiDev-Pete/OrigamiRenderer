//+build windows
//+private
package OrigamiPlatform

import "core:fmt"
import "core:runtime"
import "core:unicode/utf16"
import win32 "core:sys/windows"

CLASS_NAME :: "Origami Window Class"

window_proc :: proc "stdcall" (hWnd: win32.HWND, msg: win32.UINT, wParam: win32.WPARAM, lParam: win32.LPARAM) -> win32.LRESULT {
    when ODIN_DEBUG {
        context = runtime.default_context()
    }
    switch msg {
        case win32.WM_CLOSE: {
            when ODIN_DEBUG {
                fmt.println("WM_CLOSE")
            }
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

_create_window :: proc(width, height: i32, title: string, x, y: i32) -> (Window, Window_Error) {
    // Register the window class.

    utf16_class_name: [len(CLASS_NAME)]u16
    utf16.encode_string(utf16_class_name[:], CLASS_NAME)

    wc: win32.WNDCLASSW
    wc.lpfnWndProc = window_proc
    wc.hInstance = cast(win32.HINSTANCE) win32.GetModuleHandleW(nil)
    wc.lpszClassName = &utf16_class_name[0]

    win32.RegisterClassW(&wc)

    utf16_title := make([]u16, len(title), context.temp_allocator)
    utf16.encode_string(utf16_title[:], title) 

    hWnd := win32.CreateWindowW(wc.lpszClassName, &utf16_title[0], win32.WS_OVERLAPPEDWINDOW, x, y, width, height, nil, nil, wc.hInstance, nil)

    if (hWnd == nil) {
        return {}, .Failed
    }

    win32.ShowWindow(hWnd, win32.SW_SHOWDEFAULT)

    window := Window {
        width = width,
        height = height,
        title = title,
        x = x,
        y = y,
        win32_handle = hWnd,
    }

    return window, .None
}

_destroy_window :: proc(window: ^Window) {
    // win32.DestroyWindow(cast(win32.HWND)window.win32_handle)
}

_window_should_close :: proc(window: ^Window) -> bool {
    msg: win32.MSG
    should_quit := !win32.GetMessageW(&msg, nil, 0, 0)
    win32.TranslateMessage(&msg)
    win32.DispatchMessageW(&msg)
    return cast(bool) should_quit
}