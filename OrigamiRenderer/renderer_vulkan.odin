//+private
package OrigamiRenderer

import "core:dynlib"
import "core:log"
import "core:os"
import "core:runtime"
import "core:strings"
import vk "vendor:vulkan"
import win32 "core:sys/windows"

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
    device: vk.Device,
    graphics_queue: vk.Queue,
    present_queue: vk.Queue,
    surface: vk.SurfaceKHR,
    debug_messenger: vk.DebugUtilsMessengerEXT,
}

Vulkan_Error :: enum {
    None,
    Cannot_Create_Instance,
    Validation_Layer_Not_Supported,
    Cannot_Create_Debug_Messenger,
    Cannot_Find_Vulkan_Device,
    Cannot_Create_Logical_Device,
    Cannot_Create_Surface,
}

Queue_Family_Indices :: struct {
    graphics_family: Maybe(u32),
    present_family: Maybe(u32)
}

_vk_init_renderer :: proc(r: ^Vulkan_Renderer, window_info: Window_Info) -> (err: Error) {
    // Get global vulkan procedures
    get_instance_proc_address := load_vkGetInstanceProcAddr()
    vk.load_proc_addresses(get_instance_proc_address)

    create_instance(r) or_return
    // Get instance procedures
    vk.load_proc_addresses(r.instance)

    setup_debug_messenger(r)
    create_surface(r, window_info) or_return
    pick_physical_device(r) or_return
    create_logical_device(r) or_return


    return
}

_vk_deinit_renderer :: proc(using r: ^Vulkan_Renderer) {
    if enable_validation_layers {
        vk.DestroyDebugUtilsMessengerEXT(instance, debug_messenger, nil)
    }
    vk.DestroyDevice(device, nil)
    vk.DestroySurfaceKHR(instance, surface, nil)
    vk.DestroyInstance(instance, nil)
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

create_surface :: proc(r: ^Vulkan_Renderer, window_info: Window_Info) -> (err: Error) {
    when ODIN_OS == .Windows {
        using win32
        create_info := vk.Win32SurfaceCreateInfoKHR {
            sType = .WIN32_SURFACE_CREATE_INFO_KHR,
            hwnd = cast(HWND) window_info.(Win32_Window_Info).hwnd,
            hinstance = cast(HANDLE) GetModuleHandleA(nil)
        }

        if vk.CreateWin32SurfaceKHR(r.instance, &create_info, nil, &r.surface) != .SUCCESS {
            log.error("Could not create window surface.")
            return .Cannot_Create_Surface
        }
    }

    return
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
        if is_device_suitable(r, device) {
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

is_device_suitable :: proc(r: ^Vulkan_Renderer, device: vk.PhysicalDevice) -> bool {
    indices := find_queue_families(r, device)
    value, ok := indices.graphics_family.?
    return ok
}

find_queue_families :: proc(r: ^Vulkan_Renderer, device: vk.PhysicalDevice) -> Queue_Family_Indices {
    indices: Queue_Family_Indices

    queue_family_count: u32
    vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, nil)
    queue_families := make([]vk.QueueFamilyProperties, queue_family_count)
    defer delete(queue_families)

    vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, raw_data(queue_families))
    for queue_family, i in &queue_families {
        if .GRAPHICS in queue_family.queueFlags {
            indices.graphics_family = u32(i)
        }

        present_support : b32 = false
        vk.GetPhysicalDeviceSurfaceSupportKHR(device, u32(i), r.surface, &present_support)
        if present_support {
            indices.present_family = u32(i)
        }

        if queue_family_complete(indices) {
            break
        }
    }

    return indices
}

create_logical_device :: proc(r: ^Vulkan_Renderer) -> (err: Vulkan_Error) {
    indices := find_queue_families(r, r.physical_device)

    unique_queue_families := make(map[u32]struct{}, 0, context.temp_allocator)
    unique_queue_families[indices.graphics_family.?] = {}
    unique_queue_families[indices.present_family.?] = {}
    queue_create_infos := make([]vk.DeviceQueueCreateInfo, len(unique_queue_families), context.temp_allocator)
    defer free_all(context.temp_allocator)

    queue_priority : f32 = 1.0
    i := 0
    for queue_family, _ in unique_queue_families {
        queue_create_info := vk.DeviceQueueCreateInfo {
            sType = .DEVICE_QUEUE_CREATE_INFO,
            queueFamilyIndex = queue_family,
            queueCount = cast(u32) len(queue_create_infos),
            pQueuePriorities = &queue_priority
        }
        queue_create_infos[i] = queue_create_info
        i += 1
    }

    device_features: vk.PhysicalDeviceFeatures

    create_info := vk.DeviceCreateInfo {
        sType = .DEVICE_CREATE_INFO,
        queueCreateInfoCount = 1,
        pQueueCreateInfos = raw_data(queue_create_infos),
        pEnabledFeatures = &device_features
    }

    if enable_validation_layers {
        create_info.enabledLayerCount = cast(u32) len(validation_layers)
        create_info.ppEnabledLayerNames = raw_data(validation_layers)
    }

    if vk.CreateDevice(r.physical_device, &create_info, nil, &r.device) != .SUCCESS {
        log.error("Failed to create logical device.")
        return .Cannot_Create_Logical_Device
    }

    vk.GetDeviceQueue(r.device, indices.graphics_family.?, 0, &r.graphics_queue)
    vk.GetDeviceQueue(r.device, indices.present_family.?, 0, &r.present_queue)
    
    return
}


_vk_render :: proc(r: ^Vulkan_Renderer) {

}

setup_debug_messenger :: proc(r: ^Vulkan_Renderer) -> (err: Error) {
    if !enable_validation_layers do return

    create_info: vk.DebugUtilsMessengerCreateInfoEXT
    init_debug_messenger_create_info(&create_info)

    if vk.CreateDebugUtilsMessengerEXT(r.instance, &create_info, nil, &r.debug_messenger) != .SUCCESS {
        log.error("Failed to create debug messenger.")
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

queue_family_complete :: proc(queue_family: Queue_Family_Indices) -> bool {
    _, ok1 := queue_family.graphics_family.?
    _, ok2 := queue_family.present_family.?
    return ok1 && ok2
}