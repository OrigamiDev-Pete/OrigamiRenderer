package main

import "core:fmt"

import op "OrigamiPlatform"
import or "OrigamiRenderer"

main :: proc() {
    window, err := op.create_window(800, 600, "Origami Renderer")
    if err != nil {
        fmt.println(err)
        return
    }
    // defer op.destroy_window(&window)

    for !op.window_should_close(&window) {
        free_all(context.temp_allocator)
    }
 }



