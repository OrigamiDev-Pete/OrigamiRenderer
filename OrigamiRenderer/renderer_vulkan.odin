//+private
package OrigamiRenderer

import "core:dynlib"
import "core:log"
import "core:os"
import "core:runtime"
import "core:strings"
import win32 "core:sys/windows"

import vk "vendor:vulkan"

validation_layers :: []cstring {
    "VK_LAYER_KHRONOS_validation",
}

device_extensions :: []cstring {
    vk.KHR_SWAPCHAIN_EXTENSION_NAME,
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

    swap_chain: vk.SwapchainKHR,
    swap_chain_images: []vk.Image,
    swap_chain_image_views: []vk.ImageView,
    swap_chain_image_format: vk.Format,
    swap_chain_extent: vk.Extent2D,
    swap_chain_framebuffers: [dynamic]vk.Framebuffer,

    render_pass: vk.RenderPass,
    pipeline_layout: vk.PipelineLayout,
    graphics_pipeline: vk.Pipeline,

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
    Cannot_Create_Swap_Chain,
    Cannot_Create_Image_View,
    Cannot_Create_Shader_Module,
    Cannot_Create_Pipeline_Layout,
    Cannot_Create_Graphics_Pipeline,
    Cannot_Create_Render_Pass,
    Cannot_Create_Framebuffer,
}

Queue_Family_Indices :: struct {
    graphics_family: Maybe(u32),
    present_family: Maybe(u32),
}

Swap_Chain_Support_Details :: struct {
    capabilites: vk.SurfaceCapabilitiesKHR,
    formats: []vk.SurfaceFormatKHR,
    present_modes: []vk.PresentModeKHR,
}

_vk_init_renderer :: proc(r: ^Vulkan_Renderer, window_info: Window_Info) -> (err: Vulkan_Error) {
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
    create_swap_chain(r, window_info) or_return
    create_image_views(r) or_return
    create_render_pass(r) or_return
    create_graphics_pipeline(r) or_return
    create_framebuffers(r) or_return

    return
}

_vk_deinit_renderer :: proc(using r: ^Vulkan_Renderer) {
    if enable_validation_layers {
        vk.DestroyDebugUtilsMessengerEXT(instance, debug_messenger, nil)
    }

    for framebuffer in swap_chain_framebuffers {
        vk.DestroyFramebuffer(device, framebuffer, nil)
    }

    vk.DestroyPipeline(device, graphics_pipeline, nil)
    vk.DestroyPipelineLayout(device, pipeline_layout, nil)
    vk.DestroyRenderPass(device, render_pass, nil)
    vk.DestroySwapchainKHR(device, swap_chain, nil)
    for image_view in swap_chain_image_views {
        vk.DestroyImageView(device, image_view, nil)
    }

    vk.DestroyDevice(device, nil)
    vk.DestroySurfaceKHR(instance, surface, nil)
    vk.DestroyInstance(instance, nil)


    delete(r.swap_chain_images)
    delete(r.swap_chain_image_views)
    delete(r.swap_chain_framebuffers)
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

create_instance :: proc(r: ^Vulkan_Renderer) -> (err: Vulkan_Error) {
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
        apiVersion = vk.API_VERSION_1_0,
    }

    create_info : vk.InstanceCreateInfo = {
        sType = .INSTANCE_CREATE_INFO,
        pApplicationInfo = &app_info,
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

create_surface :: proc(r: ^Vulkan_Renderer, window_info: Window_Info) -> (err: Vulkan_Error) {
    when ODIN_OS == .Windows {
        using win32
        create_info := vk.Win32SurfaceCreateInfoKHR {
            sType = .WIN32_SURFACE_CREATE_INFO_KHR,
            hwnd = cast(HWND) window_info.(Win32_Window_Info).hwnd,
            hinstance = cast(HANDLE) GetModuleHandleA(nil),
        }

        if vk.CreateWin32SurfaceKHR(r.instance, &create_info, nil, &r.surface) != .SUCCESS {
            log.error("Could not create window surface.")
            return .Cannot_Create_Surface
        }
    }


    return
}

pick_physical_device :: proc(r: ^Vulkan_Renderer) -> (err: Vulkan_Error) {
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
        if is_device_suitable(r^, device) {
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

is_device_suitable :: proc(r: Vulkan_Renderer, device: vk.PhysicalDevice) -> bool {
    indices := find_queue_families(r, device)
    indices_complete := queue_family_complete(indices)

    extension_supported := check_device_extension_support(device)

    swap_chains_adequate := false
    if (extension_supported) {
        swap_chain_support := query_swap_chain_support(r, device)
        defer delete_swap_chain_support_details(swap_chain_support)
        swap_chains_adequate = len(swap_chain_support.formats) != 0 && len(swap_chain_support.present_modes) != 0
    }


    return indices_complete && extension_supported && swap_chains_adequate
}

check_device_extension_support :: proc(device: vk.PhysicalDevice) -> bool {
    extensions_count: u32
    vk.EnumerateDeviceExtensionProperties(device, nil, &extensions_count, nil)

    available_extensions := make([]vk.ExtensionProperties, extensions_count, context.temp_allocator)
    defer free_all(context.temp_allocator)
    vk.EnumerateDeviceExtensionProperties(device, nil, &extensions_count, raw_data(available_extensions))

    for extension_name in device_extensions {
        extension_found := false

        for extension in &available_extensions {
            if strings.compare(string(extension_name), string(cstring(&extension.extensionName[0]))) == 0 {
                extension_found = true
                break
            }
        }

        if !extension_found do return false
    }
    
    return true
}

check_validation_layer_support :: proc() -> bool {
    layer_count: u32
    vk.EnumerateInstanceLayerProperties(&layer_count, nil)

    available_layers := make([]vk.LayerProperties, layer_count, context.temp_allocator)
    defer free_all(context.temp_allocator)
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

find_queue_families :: proc(r: Vulkan_Renderer, device: vk.PhysicalDevice) -> Queue_Family_Indices {
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

query_swap_chain_support :: proc(r: Vulkan_Renderer, device: vk.PhysicalDevice) -> Swap_Chain_Support_Details {
    details: Swap_Chain_Support_Details

    vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(device, r.surface, &details.capabilites)

    format_count: u32
    vk.GetPhysicalDeviceSurfaceFormatsKHR(device, r.surface, &format_count, nil)

    if format_count != 0 {
        details.formats = make([]vk.SurfaceFormatKHR, format_count)
        vk.GetPhysicalDeviceSurfaceFormatsKHR(device, r.surface, &format_count, raw_data(details.formats))
    }

    present_mode_count: u32
    vk.GetPhysicalDeviceSurfacePresentModesKHR(device, r.surface, &present_mode_count, nil)

    if present_mode_count != 0 {
        details.present_modes = make([]vk.PresentModeKHR, present_mode_count)
        vk.GetPhysicalDeviceSurfacePresentModesKHR(device, r.surface, &present_mode_count, raw_data(details.present_modes))
    }

    return details
}

delete_swap_chain_support_details :: proc(details: Swap_Chain_Support_Details) {
    delete(details.formats)
    delete(details.present_modes)
}

choose_swap_chain_surface_format :: proc(available_formats: []vk.SurfaceFormatKHR) -> vk.SurfaceFormatKHR {
    for available_format in available_formats {
        if available_format.format == .B8G8R8_SRGB && available_format.colorSpace == .COLORSPACE_SRGB_NONLINEAR {
            return available_format
        }
    }

    return available_formats[0]
}

choose_swap_chain_present_mode :: proc(available_present_modes: []vk.PresentModeKHR) -> vk.PresentModeKHR {
    for available_present_mode in available_present_modes {
        if available_present_mode == .MAILBOX {
            return available_present_mode
        }
    }

    return .FIFO
}

choose_swap_extent :: proc(capabilities: vk.SurfaceCapabilitiesKHR, info: Window_Info) -> vk.Extent2D {
    if capabilities.currentExtent.width != max(u32) {
        return capabilities.currentExtent
    } else {
        actual_extent := vk.Extent2D {
            width = u32(info.?.width),
            height = u32(info.?.height),
        }

        actual_extent.width = clamp(actual_extent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width)
        actual_extent.height = clamp(actual_extent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height)
        
        return actual_extent
    }
}

create_logical_device :: proc(r: ^Vulkan_Renderer) -> (err: Vulkan_Error) {
    indices := find_queue_families(r^, r.physical_device)

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
            pQueuePriorities = &queue_priority,
        }
        queue_create_infos[i] = queue_create_info
        i += 1
    }

    device_features: vk.PhysicalDeviceFeatures

    create_info := vk.DeviceCreateInfo {
        sType = .DEVICE_CREATE_INFO,
        queueCreateInfoCount = 1,
        pQueueCreateInfos = raw_data(queue_create_infos),
        pEnabledFeatures = &device_features,
        enabledExtensionCount = cast(u32) len(device_extensions),
        ppEnabledExtensionNames = raw_data(device_extensions),
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

create_swap_chain :: proc(r: ^Vulkan_Renderer, window_info: Window_Info) -> (err: Vulkan_Error) {
    swap_chain_support := query_swap_chain_support(r^, r.physical_device)
    defer delete_swap_chain_support_details(swap_chain_support)

    surface_format := choose_swap_chain_surface_format(swap_chain_support.formats)
    present_mode := choose_swap_chain_present_mode(swap_chain_support.present_modes)
    extent := choose_swap_extent(swap_chain_support.capabilites, window_info)

    image_count := swap_chain_support.capabilites.minImageCount + 1
    if swap_chain_support.capabilites.maxImageCount > 0 && image_count > swap_chain_support.capabilites.maxImageCount {
        image_count = swap_chain_support.capabilites.maxImageCount
    }

    create_info := vk.SwapchainCreateInfoKHR {
        sType = .SWAPCHAIN_CREATE_INFO_KHR,
        surface = r.surface,
        minImageCount = image_count,
        imageFormat = surface_format.format,
        imageColorSpace = surface_format.colorSpace,
        imageExtent = extent,
        imageArrayLayers = 1,
        imageUsage = { .COLOR_ATTACHMENT },
        preTransform = swap_chain_support.capabilites.currentTransform,
        compositeAlpha = { .OPAQUE },
        presentMode = present_mode,
        clipped = true,
        oldSwapchain = vk.SwapchainKHR{},
    }

    indices := find_queue_families(r^, r.physical_device)
    queue_family_indices := []u32{ indices.graphics_family.?, indices.present_family.? }

    if indices.graphics_family.? != indices.present_family.? {
        create_info.imageSharingMode = .CONCURRENT
        create_info.queueFamilyIndexCount = 2
        create_info.pQueueFamilyIndices = raw_data(queue_family_indices)
    }

    if vk.CreateSwapchainKHR(r.device, &create_info, nil, &r.swap_chain) != .SUCCESS {
        log.error("Failed to create swap chain.")
        return .Cannot_Create_Swap_Chain
    }

    vk.GetSwapchainImagesKHR(r.device, r.swap_chain, &image_count, nil)
    r.swap_chain_images = make([]vk.Image, image_count)
    vk.GetSwapchainImagesKHR(r.device, r.swap_chain, &image_count, raw_data(r.swap_chain_images))

    r.swap_chain_image_format = surface_format.format
    r.swap_chain_extent = extent

    return
}

create_image_views :: proc(r: ^Vulkan_Renderer) -> (err: Vulkan_Error) {
    r.swap_chain_image_views = make([]vk.ImageView, len(r.swap_chain_images))

    for i in 0..<len(r.swap_chain_images) {
        create_info := vk.ImageViewCreateInfo {
            sType = .IMAGE_VIEW_CREATE_INFO,
            image = r.swap_chain_images[i],
            viewType = .D2,
            format = r.swap_chain_image_format,
        }
        create_info.components.r = .IDENTITY
        create_info.components.g = .IDENTITY
        create_info.components.b = .IDENTITY
        create_info.components.a = .IDENTITY

        create_info.subresourceRange.aspectMask = { .COLOR }
        create_info.subresourceRange.baseMipLevel = 0
        create_info.subresourceRange.levelCount = 1
        create_info.subresourceRange.baseArrayLayer = 0
        create_info.subresourceRange.layerCount = 1

        if vk.CreateImageView(r.device, &create_info, nil, &r.swap_chain_image_views[i]) != .SUCCESS {
            log.error("Failed to create image view.")
            return .Cannot_Create_Image_View
        }
    }

    return
}

create_render_pass :: proc(r: ^Vulkan_Renderer) -> (err: Vulkan_Error) {
    colour_attachment := vk.AttachmentDescription {
        format = r.swap_chain_image_format,
        samples = { ._1 },
        loadOp = .CLEAR,
        storeOp = .STORE,
        stencilLoadOp = .DONT_CARE,
        stencilStoreOp = .DONT_CARE,
        initialLayout = .UNDEFINED,
        finalLayout = .PRESENT_SRC_KHR,
    }

    colour_attachment_ref := vk.AttachmentReference {
        attachment = 0,
        layout = .COLOR_ATTACHMENT_OPTIMAL,
    }

    subpass := vk.SubpassDescription {
        pipelineBindPoint = .GRAPHICS,
        colorAttachmentCount = 1,
        pColorAttachments = &colour_attachment_ref,
    }

    render_pass_info := vk.RenderPassCreateInfo {
        sType = .RENDER_PASS_CREATE_INFO,
        attachmentCount = 1,
        pAttachments = &colour_attachment,
        subpassCount = 1,
        pSubpasses = &subpass,
    }

    if vk.CreateRenderPass(r.device, &render_pass_info, nil, &r.render_pass) != .SUCCESS {
        log.error("Failed to create render pass.")
        return .Cannot_Create_Render_Pass
    }

    return
}

create_graphics_pipeline :: proc(r: ^Vulkan_Renderer) -> (err: Vulkan_Error) {
    vert_shader_code, ok1 := os.read_entire_file_from_filename("origamiRenderer/shaders/spirv/vert.spv") 
    frag_shader_code, ok2 := os.read_entire_file_from_filename("origamiRenderer/shaders/spirv/frag.spv")
    defer delete(vert_shader_code)
    defer delete(frag_shader_code)

    vert_shader_module := vk_create_shader_module(r^, vert_shader_code) or_return
    frag_shader_module := vk_create_shader_module(r^, frag_shader_code) or_return
    defer vk.DestroyShaderModule(r.device, vert_shader_module, nil)
    defer vk.DestroyShaderModule(r.device, frag_shader_module, nil)

    vert_shader_stage_info := vk.PipelineShaderStageCreateInfo {
        sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage = { .VERTEX },
        module = vert_shader_module,
        pName = "main",
    }

    frag_shader_stage_info := vk.PipelineShaderStageCreateInfo {
        sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage = { .FRAGMENT },
        module = frag_shader_module,
        pName = "main",
    }

    shader_stages := []vk.PipelineShaderStageCreateInfo { vert_shader_stage_info, frag_shader_stage_info }

    vertex_input_info := vk.PipelineVertexInputStateCreateInfo {
        sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        vertexBindingDescriptionCount = 0,
        pVertexBindingDescriptions = nil, // Optional
        vertexAttributeDescriptionCount = 0,
        pVertexAttributeDescriptions = nil, // Optional
    }

    input_assembly := vk.PipelineInputAssemblyStateCreateInfo {
        sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        topology = .TRIANGLE_LIST,
        primitiveRestartEnable = false,
    }

    viewport := vk.Viewport {
        width = cast(f32) r.swap_chain_extent.width,
        height = cast(f32) r.swap_chain_extent.width,
        minDepth = 0,
        maxDepth = 1,
    }

    scissor := vk.Rect2D {
        offset = { x = 0, y = 0 },
        extent = r.swap_chain_extent,
    }

    dynamic_states := []vk.DynamicState { .VIEWPORT, .SCISSOR }

    dynamic_state := vk.PipelineDynamicStateCreateInfo {
        sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        dynamicStateCount = cast(u32) len(dynamic_states),
        pDynamicStates = raw_data(dynamic_states),
    }

    viewport_state := vk.PipelineViewportStateCreateInfo {
        sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        viewportCount = 1,
        scissorCount = 1,
    }

    rasterizer := vk.PipelineRasterizationStateCreateInfo {
        sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        depthClampEnable = false,
        rasterizerDiscardEnable = false,
        polygonMode = .FILL,
        lineWidth = 1,
        cullMode = { .BACK },
        frontFace = .CLOCKWISE,
        depthBiasEnable = false,
        depthBiasConstantFactor = 0, // Optional
        depthBiasClamp = 0, // Optional
        depthBiasSlopeFactor = 0, // Optional
    }

    multisampling := vk.PipelineMultisampleStateCreateInfo {
        sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        sampleShadingEnable = false,
        rasterizationSamples = { ._1 },
        minSampleShading = 1, // Optional
        pSampleMask = nil, // Optional
        alphaToCoverageEnable = false, // Optional
        alphaToOneEnable = false, // Optional
    }

    colour_blend_attachment := vk.PipelineColorBlendAttachmentState {
        colorWriteMask = { .R, .G, .B, .A },
        blendEnable = false,
        srcColorBlendFactor = .ONE, // Optional
        dstColorBlendFactor = .ZERO, // Optional
        colorBlendOp = .ADD, // Optional
        srcAlphaBlendFactor = .ONE, // Optional
        dstAlphaBlendFactor = .ZERO, // Optional
        alphaBlendOp = .ADD, // Optional
    }

    colour_blending := vk.PipelineColorBlendStateCreateInfo {
        sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        logicOpEnable = false,
        logicOp = .COPY, // Optional
        attachmentCount = 1,
        pAttachments = &colour_blend_attachment,
        blendConstants = { 0, 0, 0, 0 }, // Optional
    }

    pipeline_layout_info := vk.PipelineLayoutCreateInfo {
        sType = .PIPELINE_LAYOUT_CREATE_INFO,
        setLayoutCount = 0, // Optional
        pSetLayouts = nil, // Optional
        pushConstantRangeCount = 0, // Optional
        pPushConstantRanges = nil, // Optional
    }

    if vk.CreatePipelineLayout(r.device, &pipeline_layout_info, nil, &r.pipeline_layout) != .SUCCESS {
        log.error("Failed to create pipeline layout.")
        return .Cannot_Create_Pipeline_Layout
    }
    
    pipeline_info := vk.GraphicsPipelineCreateInfo {
        sType = .GRAPHICS_PIPELINE_CREATE_INFO,
        stageCount = 2,
        pStages = raw_data(shader_stages),
        pVertexInputState = &vertex_input_info,
        pInputAssemblyState = &input_assembly,
        pViewportState = &viewport_state,
        pRasterizationState = &rasterizer,
        pMultisampleState = &multisampling,
        pDepthStencilState = nil, // Optional
        pColorBlendState = &colour_blending,
        pDynamicState = &dynamic_state,
        layout = r.pipeline_layout,
        renderPass = r.render_pass,
        subpass = 0,
        basePipelineHandle = vk.Pipeline{}, // Optional
        basePipelineIndex = -1, // Optional
    }

    if vk.CreateGraphicsPipelines(r.device, vk.PipelineCache{}, 1, &pipeline_info, nil, &r.graphics_pipeline) != .SUCCESS {
        log.error("Failed to create graphics pipeline.")
        return .Cannot_Create_Graphics_Pipeline
    }

    return
}

create_framebuffers :: proc (r: ^Vulkan_Renderer) -> (err: Vulkan_Error) {
    resize(&r.swap_chain_framebuffers, len(r.swap_chain_image_views))

    for &attachment, i in r.swap_chain_image_views {
        framebuffer_info := vk.FramebufferCreateInfo {
            sType = .FRAMEBUFFER_CREATE_INFO,
            renderPass = r.render_pass,
            attachmentCount = 1,
            pAttachments = &attachment,
            width = r.swap_chain_extent.width,
            height = r.swap_chain_extent.height,
            layers = 1,
        }

        if vk.CreateFramebuffer(r.device, &framebuffer_info, nil, &r.swap_chain_framebuffers[i]) != .SUCCESS {
            log.error("Failed to create framebuffer.")
            return .Cannot_Create_Framebuffer
        }
    }

    return
}

_vk_render :: proc(r: ^Vulkan_Renderer) {

}

setup_debug_messenger :: proc(r: ^Vulkan_Renderer) -> (err: Vulkan_Error) {
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