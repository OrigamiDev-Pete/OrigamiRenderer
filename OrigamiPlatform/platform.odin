package OrigamiPlatform

import "core:runtime"
import "core:fmt"

// @(private)
@(private)
Window_Base :: struct {
    x:      i32,
    y:      i32,
    width:  i32,
    height: i32,
    title:  string,

    using callbacks: Window_Callbacks,
    odin_context: ^runtime.Context,
}

Window :: union {
    Win32_Window,
}

@(private)
Window_Callbacks :: struct {
    on_resize: #type proc (window: ^Window, width, height: u16),
    on_close:  #type proc (window: ^Window),
}

Window_Error :: enum u8 {
    None,
    Failed,
    OS_Not_Supported,
}


create_window :: proc(width, height: i32, title: string, x: i32 = 0, y: i32 = 0) -> (^Window, Window_Error) {
    return _create_window(width, height, title, x, y)
}

destroy_window :: proc(window: ^Window) {
    _destroy_window(auto_cast window)
}

window_should_close :: proc(window: ^Window) -> bool {
    return _window_should_close(auto_cast window)
}

window_set_on_resize_callback :: proc(window: ^Window, callback: #type proc(window: ^Window, width, height: u16)) {
    switch w in window {
        case Win32_Window:
            w.on_resize = callback
    }
}

window_set_on_close_callback :: proc(window: ^Window, callback: #type proc(window: ^Window)) {
    switch w in window {
        case Win32_Window:
            w.on_close = callback
    }
}
