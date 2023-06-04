//+build windows
//+private
package OrigamiPlatform

import "core:fmt"
import "core:runtime"
import "core:unicode/utf16"
import win32 "core:sys/windows"

origamiWindow: ^Window = nil

CLASS_NAME :: "Origami Window Class"

window_proc :: proc "stdcall" (hWnd: win32.HWND, msg: win32.UINT, wParam: win32.WPARAM, lParam: win32.LPARAM) -> win32.LRESULT {
    context = origamiWindow.odinContext^

    switch msg {
        case win32.WM_SIZE: {
            when ODIN_DEBUG {
                fmt.println("WM_SIZE")
            }
            width := win32.LOWORD(cast(win32.DWORD)lParam)
            height := win32.HIWORD(cast(win32.DWORD)lParam)
            if (origamiWindow.callbacks.on_resize != nil) {
                origamiWindow.callbacks.on_resize(origamiWindow, width, height)
            }

            return 0
        }
        case win32.WM_CLOSE: {
            when ODIN_DEBUG {
                fmt.println("WM_CLOSE")
            }
            if origamiWindow.callbacks.on_close != nil do origamiWindow.callbacks.on_close(origamiWindow)
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

    utf16_class_name: [len(CLASS_NAME)]u16
    utf16.encode_string(utf16_class_name[:], CLASS_NAME)


    wc: win32.WNDCLASSW
    wc.lpfnWndProc = window_proc
    wc.hInstance = cast(win32.HINSTANCE) win32.GetModuleHandleW(nil)
    wc.lpszClassName = &utf16_class_name[0]

    win32.RegisterClassW(&wc)

    utf16_title := make([]u16, len(title), context.temp_allocator)
    utf16.encode_string(utf16_title[:], title) 

    ctx := new_clone(context)
    window := new_clone(Window {
        width = width,
        height = height,
        title = title,
        x = x,
        y = y,
        callbacks = {},
        odinContext = ctx,
    })
    origamiWindow = window

    hWnd := win32.CreateWindowW(wc.lpszClassName, &utf16_title[0], win32.WS_OVERLAPPEDWINDOW, x, y, width, height, nil, nil, wc.hInstance, nil)

    if (hWnd == nil) {
        return window, .Failed
    }

    window.win32_handle = hWnd

    win32.ShowWindow(hWnd, win32.SW_SHOWDEFAULT)

    return window, .None
}

_destroy_window :: proc(window: ^Window) {
    free(window.odinContext)
    free(window)
}

_window_should_close :: proc(window: ^Window) -> bool {
    msg: win32.MSG
    should_quit := !win32.GetMessageW(&msg, nil, 0, 0)
    win32.TranslateMessage(&msg)
    win32.DispatchMessageW(&msg)
    return cast(bool) should_quit
}