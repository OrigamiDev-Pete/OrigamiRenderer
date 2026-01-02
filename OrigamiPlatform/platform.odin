package OrigamiPlatform

import "base:runtime"
import win32 "core:sys/windows"

Window :: struct {
    x:         i32,
    y:         i32,
    width:     i32,
    height:    i32,
    frequency: i64,
    title:     string,

    using callbacks: Window_Callbacks,
    odin_context: ^runtime.Context,
    platform_data: union { Win32_Window }
}

Win32_Window :: struct {
    window_handle: win32.HWND,
    device_context: win32.HDC,
    render_context: win32.HGLRC
}

Window_Callbacks :: struct {
    on_resize: On_Resize_Callback,
    on_close:  On_Close_Callback,
    on_keydown: On_Key_Callback,
    on_character: On_Key_Callback
}

Key_Event :: struct {
    key_code: Key,
    shift_pressed: bool,
    control_pressed: bool,
    alt_pressed: bool,
    repeat: bool
}

Time_State :: struct {
    ticks_per_second: i64,
    last_counter:     i64, // Ticks at the start of the previous frame
    delta_time:       f64, // Time elapsed in seconds
}

Window_Error :: enum u8 {
    None,
    Failed,
    OS_Not_Supported,
}

Render_API :: enum {
    Vulkan,
    OpenGL,
    // D3D11,
    // D3D12,
    // Metal,
    // WebGL,
    // WebGPU,
}

Key :: Platform_Key

On_Resize_Callback :: #type proc (window: ^Window, width, height: u16)
On_Close_Callback :: #type proc (window: ^Window)
On_Key_Callback :: #type proc (window: ^Window, key_event: Key_Event)

start_time: i64

create_window :: proc(width, height: i32, title: string, x: i32 = 0, y: i32 = 0) -> (^Window, Window_Error) {
    return _create_window(width, height, title, x, y)
}

destroy_window :: proc(window: ^Window) {
    _destroy_window(auto_cast window)
}

get_time :: proc(window: Window) -> f64 {
    return _get_time(window);
}

window_should_close :: proc(window: ^Window) -> bool {
    return _window_should_close(auto_cast window)
}

get_window_size :: proc(window: Window) -> (int, int) {
    return _get_window_size(window)
}

window_set_on_resize_callback :: proc(window: ^Window, callback: On_Resize_Callback) {
    window.on_resize = callback
}

window_set_on_close_callback :: proc(window: ^Window, callback: On_Close_Callback) {
    window.on_close = callback
}

window_set_on_keydown_callback :: proc(window: ^Window, callback: On_Key_Callback) {
    window.on_keydown = callback
}

window_set_on_character_callback :: proc(window: ^Window, callback: On_Key_Callback) {
    window.on_character = callback
}
