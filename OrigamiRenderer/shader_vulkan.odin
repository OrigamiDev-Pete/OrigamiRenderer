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
}

Vulkan_Material :: struct {
    using base: Material_Base,
    pipeline_layout: vk.PipelineLayout,
    pipeline: vk.Pipeline,
}

_vk_create_shader :: proc(r: ^Vulkan_Renderer, code: []u8) -> (^Vulkan_Shader, Vulkan_Error) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    module, error := vk_create_shader_module(r^, code)
    defer when !ODIN_DEBUG do delete(code)
    if error != nil do return nil, .Cannot_Create_Shader_Module

    shader := new(Shader)
    shader^ = Vulkan_Shader { 
        code = code,
        module = module,
    }

    return auto_cast shader, .None
}

_vk_destroy_shader :: proc(r: Vulkan_Renderer, shader: ^Vulkan_Shader) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    when ODIN_DEBUG {
        delete(shader.code)
    }
    vk.DestroyShaderModule(r.device, shader.module, nil)
    free(shader)
}

vk_create_shader_module :: proc(r: Vulkan_Renderer, code: []u8) -> (vk.ShaderModule, Vulkan_Error) {
    trace(&spall_ctx, &spall_buffer, #procedure)
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

_vk_create_program :: proc(r: ^Vulkan_Renderer, vertex_shader, fragment_shader: ^Vulkan_Shader) -> (^Vulkan_Program, Vulkan_Error) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    program := new(Program)

    program^ = Vulkan_Program{
        vertex_shader = auto_cast vertex_shader,
        fragment_shader = auto_cast fragment_shader,
    }

    return auto_cast program, .None
}

_vk_destroy_program :: proc(program: ^Vulkan_Program, r: Vulkan_Renderer, ) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    _vk_destroy_shader(r, auto_cast program.vertex_shader)
    _vk_destroy_shader(r, auto_cast program.fragment_shader)
    free(program)
}

_vk_create_material :: proc(r: ^Vulkan_Renderer, program: ^Vulkan_Program, vertex_layout: Vertex_Layout = default_vertex_layout) -> (^Vulkan_Material, Vulkan_Error) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    material := new(Material)

    material^ = Vulkan_Material {
        program = auto_cast program
    }
    m := &material.(Vulkan_Material)

    vert_shader_stage_info := vk.PipelineShaderStageCreateInfo {
        sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage = { .VERTEX },
        module = program.vertex_shader.(Vulkan_Shader).module,
        pName = "main",
    }

    frag_shader_stage_info := vk.PipelineShaderStageCreateInfo {
        sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage = { .FRAGMENT },
        module = program.fragment_shader.(Vulkan_Shader).module,
        pName = "main",
    }

    shader_stages := []vk.PipelineShaderStageCreateInfo { vert_shader_stage_info, frag_shader_stage_info }

    vertex_binding_description, vertex_attribute_descriptions := vk_get_vertex_input_descriptions(vertex_layout)

    vertex_input_info := vk.PipelineVertexInputStateCreateInfo {
        sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        vertexBindingDescriptionCount = 1,
        pVertexBindingDescriptions = &vertex_binding_description,
        vertexAttributeDescriptionCount = cast(u32) len(vertex_attribute_descriptions),
        pVertexAttributeDescriptions = raw_data(vertex_attribute_descriptions), // Optional
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

    if vk.CreatePipelineLayout(r.device, &pipeline_layout_info, nil, &m.pipeline_layout) != .SUCCESS {
        log.error("Failed to create pipeline layout.")
        return nil, .Cannot_Create_Pipeline_Layout
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
        layout = m.pipeline_layout,
        renderPass = r.render_pass,
        subpass = 0,
        basePipelineHandle = vk.Pipeline{}, // Optional
        basePipelineIndex = -1, // Optional
    }

    if vk.CreateGraphicsPipelines(r.device, vk.PipelineCache{}, 1, &pipeline_info, nil, &m.pipeline) != .SUCCESS {
        log.error("Failed to create graphics pipeline.")
        return nil, .Cannot_Create_Graphics_Pipeline
    }

    append(&r.materials, material)

    return auto_cast material, .None
}

_vk_destroy_material :: proc(material: ^Vulkan_Material, r: Vulkan_Renderer) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    vk.DestroyPipeline(r.device, material.pipeline, nil)
    vk.DestroyPipelineLayout(r.device, material.pipeline_layout, nil)
    _vk_destroy_program(auto_cast material.program, r)
    free(material)
}

vk_get_vertex_input_descriptions :: proc(vertex_layout: Vertex_Layout) -> (vk.VertexInputBindingDescription, []vk.VertexInputAttributeDescription) {
    trace(&spall_ctx, &spall_buffer, #procedure)
    attribute_descriptions := make([]vk.VertexInputAttributeDescription, len(vertex_layout.attributes), context.temp_allocator)
    stride: u32
    offset: u32
    for attribute, i in vertex_layout.attributes {
        attribute_size := cast(u32) get_vertex_attribute_type_size(attribute.type) * cast(u32) attribute.number
        stride += attribute_size

        attribute_descriptions[i].binding = 0
        attribute_descriptions[i].location = cast(u32) i
        attribute_descriptions[i].format = vk_get_vertex_format(attribute.type, attribute.number - 1)
        attribute_descriptions[i].offset = offset
        offset += attribute_size
    }

    binding_description := vk.VertexInputBindingDescription {
        binding = 0,
        stride = stride,
        inputRate = .VERTEX,
    }

    return binding_description, attribute_descriptions
}

vk_get_vertex_format :: proc(type: Vertex_Attribute_Type, number: u8) -> vk.Format {
    trace(&spall_ctx, &spall_buffer, #procedure)
    return vk_vertex_attribute_format_map[type][number]
}