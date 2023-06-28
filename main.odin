package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"

import op "OrigamiPlatform"
import or "OrigamiRenderer"

WIDTH :: 800
HEIGHT :: 600

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

    setup_window_callbacks(window)

	renderer: or.Renderer = {}
	defer or.deinit_renderer(&renderer)
	if or.init_renderer(&renderer) != .Success do return 1

	for !op.window_should_close(window) {


		free_all(context.temp_allocator)
	}

	return 0
}

setup_window_callbacks :: proc(window: ^op.Window) {
	op.window_set_on_resize_callback(window, proc(window: ^op.Window, width, height: u16) {
		log.debug("Window resized to ", width, "x", height)
	})

	op.window_set_on_close_callback(window, proc(window: ^op.Window) {
		log.debug("Window closed")
	})
}