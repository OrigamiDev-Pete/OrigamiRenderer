package OrigamiPlatform

Window :: struct {
    x:      i32,
    y:      i32,
    width:  i32,
    height: i32,
    title:  string,

    win32_handle: rawptr,
}

Window_Error :: enum u8 {
    None,
    Failed,
    OS_Not_Supported,
}


create_window :: proc(width, height: i32, title: string, x: i32 = 0, y: i32 = 0) -> (Window, Window_Error) {
    return _create_window(width, height, title, x, y)
}

destroy_window :: proc(window: ^Window) {
    _destroy_window(window)
}

window_should_close :: proc(window: ^Window) -> bool {
    return _window_should_close(window)
}

