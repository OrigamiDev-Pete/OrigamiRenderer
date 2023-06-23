//+private
package OrigamiRenderer

import "core:dynlib"
import "core:log"
import "core:os"
import vk "vendor:vulkan"

import op "../OrigamiPlatform"

_vk_init_renderer :: proc(r: ^Renderer) {
    // Get vulkan procedures
    _load_procedures()

    err := _create_instance(r)

}

_load_procedures :: proc() {
    vulkan_lib: dynlib.Library
    ok: bool
    when ODIN_OS == .Windows {
        vulkan_lib, ok = dynlib.load_library("vulkan-1.dll")
    } else when ODIN_OS == .Darwin {
        vulkan_lib, ok = dynlib.load_library("vulkan.dylib")
    } else {
        vulkan_lib, ok = dynlib.load_library("vulkan.so.1")
    }
    assert(ok, "Could not find vulkan-1.dll")

    context.user_ptr = &vulkan_lib
    vk.load_proc_addresses_custom(proc(p: rawptr, name: cstring) {
        vulkan_lib := cast(^dynlib.Library) context.user_ptr
        proc_address, found := dynlib.symbol_address(vulkan_lib^, string(name))
        if !found {
            log.warnf("Could not find address for procedure: %v", name)
        }
        // cast p from rawptr to ^rawptr so that we can assign its value
        (cast(^rawptr)p)^ = proc_address
    })
}

_create_instance :: proc(r: ^Renderer) -> (err: Error) {
    app_info : vk.ApplicationInfo = {
        sType = .APPLICATION_INFO,
        pApplicationName = "Origami Renderer",
        applicationVersion = vk.MAKE_VERSION(1, 0, 0),
        pEngineName = "Origami",
        engineVersion = vk.MAKE_VERSION(1, 0, 0),
        apiVersion = vk.API_VERSION_1_0
    }

    create_info : vk.InstanceCreateInfo = {
        sType = .INSTANCE_CREATE_INFO,
        pApplicationInfo = &app_info
    }

    platformExtensions := _getPlatformExtensions()
    defer delete(platformExtensions)

    // Cover the case where VK_ERROR_INCOMPATILBE_DRIVER might return when using MoltenVK
    requiredExtensions: [dynamic]cstring
    defer delete(requiredExtensions)
    for extension in platformExtensions {
        append(&requiredExtensions, extension)
    }

    append(&requiredExtensions, vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME)

    create_info.flags = { .ENUMERATE_PORTABILITY_KHR }
    create_info.enabledExtensionCount = cast(u32) len(requiredExtensions)
    create_info.ppEnabledExtensionNames = raw_data(requiredExtensions)
    create_info.enabledLayerCount = 0

    if vk.CreateInstance(&create_info, nil, &r.vk_instance) != .SUCCESS {
        log.error("Failed to create instance.")
        return .Cannot_Create_Instance
    }

    extensionsCount: u32
    vk.EnumerateInstanceExtensionProperties(nil, &extensionsCount, nil)

    extensions := make([]vk.ExtensionProperties, extensionsCount)
    defer delete(extensions)

    vk.EnumerateInstanceExtensionProperties(nil, &extensionsCount, raw_data(extensions))

    log.debug("Available extensions:")
    for extension in extensions {
        log.debugf("%s", extension.extensionName)
    }

    return
}

_getPlatformExtensions :: proc() -> []cstring {
    when ODIN_OS == .Windows {
        extensions := make([]cstring, 2)
        extensions[0] = "VK_KHR_surface"
        extensions[1] = "VK_KHR_win32_surface"
        return extensions
    }
}

_vk_render :: proc(r: ^Renderer) {

}

_vk_deinit_renderer :: proc(r: ^Renderer) {
    vk.DestroyInstance(r.vk_instance, nil)
}