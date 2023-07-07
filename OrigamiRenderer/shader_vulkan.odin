//+private
package OrigamiRenderer

import "core:log"

import vk "vendor:vulkan"

Vulkan_Shader :: struct {

}

Vulkan_Program :: struct {

}

_vk_create_shader :: proc() -> ^Shader {
    shader := new(Shader)
    shader^ = Vulkan_Program{}
    return shader
}

vk_create_shader_module :: proc(r: Vulkan_Renderer, code: []u8) -> (vk.ShaderModule, Vulkan_Error) {
    create_info := vk.ShaderModuleCreateInfo {
        sType = .SHADER_MODULE_CREATE_INFO,
        codeSize = len(code),
        pCode = cast(^u32) raw_data(code),
    }

    shader_module: vk.ShaderModule
    if vk.CreateShaderModule(r.device, &create_info, nil, &shader_module) != .SUCCESS {
        log.error("Failed to create shader module.")
        return shader_module, .Cannot_Create_Shader_Module
    }

    return shader_module, .None
}