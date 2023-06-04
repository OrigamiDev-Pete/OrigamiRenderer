package OrigamiPlatform

import "core:runtime"

Window :: struct {
    x:      i32,
    y:      i32,
    width:  i32,
    height: i32,
    title:  string,

    callbacks: Window_Callbacks,
    odinContext: ^runtime.Context,

    // Platform Specific
    win32_handle: rawptr,
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
    _destroy_window(window)
}

window_should_close :: proc(window: ^Window) -> bool {
    return _window_should_close(window)
}

window_set_on_resize_callback :: proc(window: ^Window, callback: #type proc (window: ^Window, width, height: u16)) {
    window.callbacks.on_resize = callback
}

window_set_on_close_callback :: proc(window: ^Window, callback: #type proc (window: ^Window)) {
    window.callbacks.on_close = callback
}
