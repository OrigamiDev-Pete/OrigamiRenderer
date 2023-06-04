package main

import "core:fmt"
import "core:log"
import "core:mem"

import oriPlat "OrigamiPlatform"
import or "OrigamiRenderer"

main :: proc() {
    context.logger = log.create_console_logger()
    tracking_allocator: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking_allocator, context.allocator)
    context.allocator = mem.tracking_allocator(&tracking_allocator)

    run()

    for _, leak in tracking_allocator.allocation_map {
        log.errorf("%v leaked %v bytes\n", leak.location, leak.size)
    }
 }

 run :: proc() {
    window, err := oriPlat.create_window(800, 600, "Origami Renderer")
    if err != nil {
        fmt.println(err)
        return
    }
    defer oriPlat.destroy_window(window)

    oriPlat.window_set_on_resize_callback(window, proc (window: ^oriPlat.Window, width, height: u16) {
        log.debug("Window resized to ", width, "x", height)
    })

    oriPlat.window_set_on_close_callback(window, proc (window: ^oriPlat.Window) {
        log.debug("Window closed")
    })
    

    for !oriPlat.window_should_close(window) {
        

        free_all(context.temp_allocator)
    }

 }



