//+private
package OrigamiRenderer

import "core:dynlib"
import "core:log"
import "core:os"
import "core:runtime"
import "core:strings"
import vk "vendor:vulkan"

validation_layers :: []cstring {
    "VK_LAYER_KHRONOS_validation"
}

when ODIN_DEBUG {
    enable_validation_layers :: true
} else {
    enable_validation_layers :: false
}

Vulkan_Renderer :: struct {
    using base: Renderer_Base,
    instance: vk.Instance,
    physical_device: vk.PhysicalDevice,
    debug_messenger: vk.DebugUtilsMessengerEXT,
}

Vulkan_Error :: enum {
    None,
    Cannot_Create_Instance,
    Validation_Layer_Not_Supported,
    Cannot_Create_Debug_Messenger,
    Cannot_Find_Vulkan_Device,
}

Queue_Family_Indices :: struct {
    graphics_family: Maybe(int)
}

_vk_init_renderer :: proc(r: ^Vulkan_Renderer) -> (err: Error) {
    // Get global vulkan procedures
    get_instance_proc_address := load_vkGetInstanceProcAddr()
    vk.load_proc_addresses(get_instance_proc_address)

    create_instance(r) or_return
    // Get instance procedures
    vk.load_proc_addresses(r.instance)

    pick_physical_device(r) or_return

    setup_debug_messenger(r)

    return
}

_vk_deinit_renderer :: proc(r: ^Vulkan_Renderer) {
    if enable_validation_layers {
        vk.DestroyDebugUtilsMessengerEXT(r.instance, r.debug_messenger, nil)
    }
    vk.DestroyInstance(r.instance, nil)
}

load_vkGetInstanceProcAddr :: proc() -> rawptr {
    vulkan_lib: dynlib.Library
    ok: bool
    when ODIN_OS == .Windows {
        vulkan_lib, ok = dynlib.load_library("vulkan-1.dll")
    } else when ODIN_OS == .Darwin {
        vulkan_lib, ok = dynlib.load_library("vulkan.dylib")
    } else {
        vulkan_lib, ok = dynlib.load_library("vulkan.so.1")
    }
    assert(ok, "Could not find vulkan library")

    proc_address, found := dynlib.symbol_address(vulkan_lib, "vkGetInstanceProcAddr")
    assert(found, "Could not find vkGetInstanceProcAddr")

    return proc_address
}

create_instance :: proc(r: ^Vulkan_Renderer) -> (err: Error) {
    if enable_validation_layers && !check_validation_layer_support() {
        log.error("Validation layers requested, but not available")
        return .Validation_Layer_Not_Supported
    }

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

    debug_create_info: vk.DebugUtilsMessengerCreateInfoEXT
    if enable_validation_layers {
        create_info.enabledLayerCount = cast(u32) len(validation_layers)
        create_info.ppEnabledLayerNames = raw_data(validation_layers)

        init_debug_messenger_create_info(&debug_create_info)

        create_info.pNext = &debug_create_info
    }

    required_extensions := get_required_extensions()
    defer delete(required_extensions)

    // Cover the case where VK_ERROR_INCOMPATILBE_DRIVER might return when using MoltenVK
    when ODIN_OS == .Darwin {
        append(&required_extensions, vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME)
        create_info.flags = { .ENUMERATE_PORTABILITY_KHR }
    }

    create_info.enabledExtensionCount = cast(u32) len(required_extensions)
    create_info.ppEnabledExtensionNames = raw_data(required_extensions)

    if vk.CreateInstance(&create_info, nil, &r.instance) != .SUCCESS {
        log.error("Failed to create instance.")
        return .Cannot_Create_Instance
    }

    extensionsCount: u32
    vk.EnumerateInstanceExtensionProperties(nil, &extensionsCount, nil)

    extensions := make([]vk.ExtensionProperties, extensionsCount)
    defer delete(extensions)

    vk.EnumerateInstanceExtensionProperties(nil, &extensionsCount, raw_data(extensions))

    // log.debug("Available extensions:")
    // for extension in extensions {
    //     log.debugf("%s", extension.extensionName)
    // }

    return
}

get_platform_extensions :: proc() -> [dynamic]cstring {
    when ODIN_OS == .Windows {
        extensions := make([dynamic]cstring, 2)
        extensions[0] = "VK_KHR_surface"
        extensions[1] = "VK_KHR_win32_surface"
        return extensions
    }
}

get_required_extensions :: proc() -> [dynamic]cstring {
    extensions_count: u32
    extensions := get_platform_extensions()

    if enable_validation_layers {
        append(&extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)
    }

    return extensions
}

check_validation_layer_support :: proc() -> bool {
    layer_count: u32
    vk.EnumerateInstanceLayerProperties(&layer_count, nil)

    available_layers := make([]vk.LayerProperties, layer_count)
    defer delete(available_layers)
    vk.EnumerateInstanceLayerProperties(&layer_count, raw_data(available_layers))

    // log.debug("Available layers:")
    // for layer in available_layers {
    //     log.debugf("%s", layer.layerName)
    // }

    for layer_name in validation_layers {
        layer_found := false

        for layer_property in &available_layers {
            if strings.compare(string(layer_name), string(cstring(&layer_property.layerName[0]))) == 0 {
                layer_found = true
                break
            }
        }

        if !layer_found do return false 
    }

    return true
}

pick_physical_device :: proc(r: ^Vulkan_Renderer) -> (err: Error) {
    device_count: u32
    vk.EnumeratePhysicalDevices(r.instance, &device_count, nil)
    if device_count == 0 {
        log.error("Could not find GPUs with Vulkan support.")
        return .Cannot_Find_Vulkan_Device
    }

    devices := make([]vk.PhysicalDevice, device_count)
    defer delete(devices)
    vk.EnumeratePhysicalDevices(r.instance, &device_count, raw_data(devices))

    for device in &devices {
        if is_device_suitable(device) {
            r.physical_device = device
            break
        }
    }

    if r.physical_device == nil {
        log.error("Failed to find a suitable GPU.")
        return .Cannot_Find_Vulkan_Device
    }

    return
}

is_device_suitable :: proc(device: vk.PhysicalDevice) -> bool {
    indices := find_queue_families(device)
    value, ok := indices.graphics_family.?
    return ok
}

find_queue_families :: proc(device: vk.PhysicalDevice) -> Queue_Family_Indices {
    indices: Queue_Family_Indices

    queue_family_count: u32
    vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, nil)
    queue_families := make([]vk.QueueFamilyProperties, queue_family_count)
    defer delete(queue_families)
    vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, raw_data(queue_families))
    for queue_family, i in &queue_families {
        if .GRAPHICS in queue_family.queueFlags {
            indices.graphics_family = i
            break
        }
    }

    return indices
}



_vk_render :: proc(r: ^Vulkan_Renderer) {

}

setup_debug_messenger :: proc(r: ^Vulkan_Renderer) -> (err: Error) {
    if !enable_validation_layers do return

    create_info: vk.DebugUtilsMessengerCreateInfoEXT
    init_debug_messenger_create_info(&create_info)

    if vk.CreateDebugUtilsMessengerEXT(r.instance, &create_info, nil, &r.debug_messenger) != .SUCCESS {
        return .Cannot_Create_Debug_Messenger
    }

    return
}

debug_callback :: proc "system" (messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT, messageTypes: vk.DebugUtilsMessageTypeFlagsEXT, pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT, pUserData: rawptr) -> b32 {
    context = ctx^

    if .ERROR in messageSeverity {
        log.errorf("Validation layer: %s", pCallbackData.pMessage)
    } else if .WARNING in messageSeverity {
        log.warnf("Validation layer: %s", pCallbackData.pMessage)
    } else {
        log.debugf("Validation layer: %s", pCallbackData.pMessage)
    }

    return false
}

init_debug_messenger_create_info :: proc(info: ^vk.DebugUtilsMessengerCreateInfoEXT) {
    info.sType = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT
    info.messageSeverity = { .WARNING, .ERROR }
    info.messageType = { .GENERAL, .VALIDATION, .PERFORMANCE }
    info.pfnUserCallback = debug_callback
    // info.pUserData = ctx
}
