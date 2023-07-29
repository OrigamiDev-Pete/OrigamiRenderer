//+private
package OrigamiRenderer

import "core:hash"
import "core:log"

import vk "vendor:vulkan"

Vulkan_Shader :: struct {
    using base: Shader_Base,
    module: vk.ShaderModule,
}

Vulkan_Program :: struct {
    using base: Program_Base,
    pipeline_layout: vk.PipelineLayout,
    pipeline: vk.Pipeline,
}

_vk_create_shader :: proc(code: []u8) -> (Shader_Handle, Vulkan_Error) {
    r := &renderer.(Vulkan_Renderer)
    module, error := vk_create_shader_module(r^, code)
    if error != nil do return 0, .Cannot_Create_Shader_Module

    handle, shader := resource_pool_allocate(&r.shaders)
    shader.code = code
    shader.module = module

    return auto_cast handle, .None
}

_vk_destroy_shader :: proc(shader: ^Vulkan_Shader) {
    delete(shader.code)
    r := renderer.(Vulkan_Renderer)
    vk.DestroyShaderModule(r.device, shader.module, nil)
    free(shader)
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

vk_create_program :: proc(vertex_handle, fragment_handle: Shader_Handle) -> (Program_Handle, Vulkan_Error) {
    r := &renderer.(Vulkan_Renderer)

    vertex_shader := resource_pool_get(&r.shaders, auto_cast vertex_handle)
    frag_shader := resource_pool_get(&r.shaders, auto_cast fragment_handle)

    program_handle, program := resource_pool_allocate(&r.programs)

    program.vertex_shader = vertex_handle
    program.fragment_shader = fragment_handle

    vert_shader_stage_info := vk.PipelineShaderStageCreateInfo {
        sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage = { .VERTEX },
        module = vertex_shader.module,
        pName = "main",
    }

    frag_shader_stage_info := vk.PipelineShaderStageCreateInfo {
        sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage = { .FRAGMENT },
        module = frag_shader.module,
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
        return 0, .Cannot_Create_Pipeline_Layout
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
        return 0, .Cannot_Create_Graphics_Pipeline
    }

    return 0, .None

}