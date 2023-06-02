package main

import "core:fmt"

import op "OrigamiPlatform"
import or "OrigamiRenderer"

main :: proc() {
    window, err := op.create_window(800, 600, "OrigamiRenderer")
    if err != nil {
        fmt.println(err)
        return
    }
    fmt.println(window, err)
    // defer op.destroy_window(&window)
        // free_all(context.temp_allocator)
    fmt.println("here")

    for !op.window_should_close(&window) {
    }
 }



