package main

import "core:math"
import "core:math/linalg"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:slice"

import op "OrigamiPlatform"
import or "OrigamiRenderer"

import "core:prof/spall"

WIDTH :: 800
HEIGHT :: 600

vertices := []or.Vertex{
    // Position           // Normal       // UV
    {{-0.5, -0.5, 0.0},   {0, 0, 1},      {0, 0}}, // Bottom Left
    {{ 0.5, -0.5, 0.0},   {0, 0, 1},      {1, 0}}, // Bottom Right
    {{ 0.5,  0.5, 0.0},   {0, 0, 1},      {1, 1}}, // Top Right
    {{-0.5,  0.5, 0.0},   {0, 0, 1},      {0, 1}}, // Top Left
}

indices := []u32 {
    0, 1, 2, // First Triangle
    2, 3, 0, // Second Triangle
}

shader: or.Shader_Handle
mesh: or.Mesh_Handle

main :: proc() {
    context.logger = log.create_console_logger()
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)


	result := run()

	for _, leak in tracking_allocator.allocation_map {
		log.errorf("%v leaked %v bytes\n", leak.location, leak.size)
	}

	if result != 0 do os.exit(result)
}

run :: proc() -> int {
	window, err := op.create_window(WIDTH, HEIGHT, "Origami Renderer")
	if err != nil {
		log.errorf("Failed to create window: %v\n", err)
		return 1
	}
	defer op.destroy_window(window)

	window_info := get_platform_window_info(window^)
	if err := or.init_renderer(window_info); err != nil {
		log.error(err)
		return 1
	}
	defer or.deinit_renderer()

    setup_window_callbacks(window)

	shader = or.load_shader(VS_SOURCE, FS_SOURCE)
	mesh = or.create_mesh(vertices, indices)

	for !op.window_should_close(window) {
		render(window^)

		free_all(context.temp_allocator)
	}

	return 0
}

setup_window_callbacks :: proc(window: ^op.Window) {
	op.window_set_on_resize_callback(window, proc(window: ^op.Window, width, height: u16) {
		or.resize_viewport(get_platform_window_info(window^))
		render(window^)
		// log.debug("Window resized to ", width, "x", height)
		// or.trace(&or.spall_ctx, &or.spall_buffer, #procedure)
		// r := cast(^or.Renderer_Base) or.renderer
		// r.framebuffer_resized = true
		// or.render(or.renderer)
	})

	op.window_set_on_close_callback(window, proc(window: ^op.Window) {
		log.debug("Window closed")
	})

	op.window_set_on_keydown_callback(window, proc(window: ^op.Window, key_event: op.Key_Event) {
		log.debug(key_event.key_code)
	})
}

get_platform_window_info :: proc(window: op.Window) -> (info: or.Window_Info) {
	when ODIN_OS == .Windows {
		win32_info: or.Win32_Window_Info
		win32_info.hwnd = window.platform_data.(op.Win32_Window).window_handle
		win32_info.device_context = window.platform_data.(op.Win32_Window).device_context

		width, height := op.get_window_size(window)
		info.width = width
		info.height = height

		info.derived = win32_info
		return
	}
}

render :: proc(window: op.Window) {
	or.begin_frame()

	width := or.renderer.window_info.width
	height := or.renderer.window_info.height
	aspect_ratio := f32(width) / f32(height)
	fov := math.to_radians_f32(45.0)
	near: f32 = 0.1
	far: f32 = 100.0
	projection := linalg.matrix4_perspective_f32(fov, aspect_ratio, near, far)
	
	time := f32(op.get_time(window))
	radius: f32 = 3.0
	cam_x := math.sin(time) * radius
	cam_z := math.cos(time) * radius

	eye := [3]f32 { cam_x, 1.0, cam_z }
	center: [3]f32
	up := [3]f32 { 0, 1, 0 }

	view := linalg.matrix4_look_at_f32(eye, center, up)
	or.update_scene_state(eye, view, projection)


	or.clear_screen({ 1.0, 0.0, 1.0, 1.0 })
	or.set_shader(shader)
	or.draw_mesh(mesh)
	or.end_frame()
}