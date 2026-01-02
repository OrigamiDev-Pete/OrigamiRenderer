#+private
package OrigamiRenderer

import gl "vendor:OpenGL"
import "core:mem"
import "core:image"
import "core:math/linalg"
import "core:log"
import "core:strings"

_gl_init_renderer :: proc() {
    gl.Enable(gl.DEPTH_TEST)
    gl.Disable(gl.CULL_FACE)

    // Initialise scene UBO
    gl.CreateBuffers(1, &renderer.scene_ubo)
    gl.NamedBufferStorage(renderer.scene_ubo, size_of(Scene_State), nil, gl.DYNAMIC_STORAGE_BIT)
    
    // Bind the scene UBO to slot 0
    gl.BindBufferBase(gl.UNIFORM_BUFFER, 0, renderer.scene_ubo)
}

_gl_end_frame :: proc() {
    for packet in renderer.command_queue {
        switch cmd in packet.command {
            case Command_Bind_Texture:
                if cmd.texture != INVALID_TEXTURE {
                    index := int(cmd.texture) - 1
                    gl_texture_id := renderer.textures[index].id
                    gl.BindTextureUnit(cmd.slot, gl_texture_id)
                } else {
                    gl.BindTextureUnit(cmd.slot, 0)
                }

            case Command_Clear:
                gl.ClearColor(cmd.colour.r, cmd.colour.g, cmd.colour.b, cmd.colour.a)
                gl.ClearDepth(f64(cmd.depth))
                gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

            case Command_Draw:
                if cmd.mesh != INVALID_MESH {
                    index := int(cmd.mesh) - 1
                    if index < len(renderer.meshes) {
                        mesh := renderer.meshes[index]
                        gl.BindVertexArray(mesh.vao)
                        gl.DrawElements(gl.TRIANGLES, mesh.index_count, gl.UNSIGNED_INT, nil)
                        gl.BindVertexArray(0)
                    }
                }

            case Command_Set_Shader:
                if cmd.shader == INVALID_SHADER {
                    gl.UseProgram(0)
                } else {
                    index := int(cmd.shader) - 1
                    if index < len(renderer.shaders) {
                        gl_shader_handle := renderer.shaders[index]
                        gl.UseProgram(gl_shader_handle)
                    }
                }

            case Command_Set_View_Port:
                gl.Viewport(cmd.x, cmd.y, cmd.w, cmd.h)
        }
    }
}

_gl_update_scene_state :: proc() {
    renderer.scene_state.view_projection = linalg.matrix_mul(renderer.scene_state.projection, renderer.scene_state.view)
    gl.NamedBufferSubData(renderer.scene_ubo, 0, size_of(Scene_State), &renderer.scene_state)
}

_gl_load_shader :: proc(vertex_source, fragment_source: string) -> Shader_Handle {
    vertex_shader, vertex_shader_ok := _compile_shader(vertex_source, gl.VERTEX_SHADER)
    if !vertex_shader_ok do return INVALID_SHADER
    defer gl.DeleteShader(vertex_shader)

    fragment_shader, fragment_shader_ok := _compile_shader(fragment_source, gl.FRAGMENT_SHADER)
    if !fragment_shader_ok do return INVALID_SHADER
    defer gl.DeleteShader(fragment_shader)

    shader_program := gl.CreateProgram()
    gl.AttachShader(shader_program, vertex_shader)
    gl.AttachShader(shader_program, fragment_shader)
    gl.LinkProgram(shader_program)

    success: i32
    gl.GetProgramiv(shader_program, gl.LINK_STATUS, &success)
    if success == 0 {
        info_log_bytes: [512]u8
        info_log_length: i32
        gl.GetShaderInfoLog(shader_program, 512, &info_log_length, &info_log_bytes[0])
        log.error("ERROR::SHADER::LINKING_FAILED")
        info_log_string := strings.string_from_ptr(&info_log_bytes[0], int(info_log_length))
        log.error(info_log_string)
        return INVALID_SHADER
    }

    append(&renderer.shaders, shader_program)
    return Shader_Handle(len(renderer.shaders))
}

_compile_shader :: proc(source: string, stage: u32) -> (u32, bool) {
    shader_id := gl.CreateShader(stage)

    source_c_string := strings.clone_to_cstring(source)
    defer delete(source_c_string)

    length := i32(len(source))
    gl.ShaderSource(shader_id, 1, &source_c_string, &length)
    gl.CompileShader(shader_id)

    success: i32
    gl.GetShaderiv(shader_id, gl.COMPILE_STATUS, &success)

    if success == 0 {
        info_log_bytes: [512]u8
        info_log_length: i32
        gl.GetShaderInfoLog(shader_id, 512, &info_log_length, &info_log_bytes[0])
        log.error("ERROR::SHADER::COMPILATION_FAILED")
        info_log_string := strings.string_from_ptr(&info_log_bytes[0], int(info_log_length))
        log.error(info_log_string)
        return 0, false
    }

    return shader_id, true
}

_gl_create_mesh :: proc(vertices: []Vertex, indices: []u32) -> Mesh_Handle {
    m: Mesh = {
        index_count = i32(len(indices))
    }

    gl.CreateBuffers(1, &m.vbo)
    gl.CreateBuffers(1, &m.ibo)

    gl.NamedBufferStorage(m.vbo, len(vertices) * size_of(Vertex), raw_data(vertices), 0)
    gl.NamedBufferStorage(m.ibo, len(indices) * size_of(u32), raw_data(indices), 0)

    gl.CreateVertexArrays(1, &m.vao)
    gl.VertexArrayVertexBuffer(m.vao, 0, m.vbo, 0, size_of(Vertex))
    gl.VertexArrayElementBuffer(m.vao, m.ibo)

    gl.EnableVertexArrayAttrib(m.vao, 0)
    gl.VertexArrayAttribFormat(m.vao, 0, 3, gl.FLOAT, false, 0)
    gl.VertexArrayAttribBinding(m.vao, 0, 0)
    gl.EnableVertexArrayAttrib(m.vao, 1)
    gl.VertexArrayAttribFormat(m.vao, 1, 3, gl.FLOAT, false, u32(offset_of(Vertex, normal)))
    gl.VertexArrayAttribBinding(m.vao, 1, 0)
    gl.EnableVertexArrayAttrib(m.vao, 2)
    gl.VertexArrayAttribFormat(m.vao, 2, 2, gl.FLOAT, false, u32(offset_of(Vertex, uv)))
    gl.VertexArrayAttribBinding(m.vao, 2, 0)

    append(&renderer.meshes, m)
    return Mesh_Handle(len(renderer.meshes))
}

_gl_create_texture :: proc(img: ^image.Image) -> Texture_Handle {
    width := i32(img.width)
    height := i32(img.height)
    internal_format := u32(gl.SRGB8_ALPHA8)
    data_format := u32(gl.RGBA)

    // Flip the buffer
    width_in_bytes := img.width * img.channels
    flipped_buffer := make([]byte, len(img.pixels.buf))
    target_y := 0
    for y := img.height - 1; y >= 0; y -= 1 {
        for x := 0; x < width_in_bytes; x += img.channels {
            flipped_buffer[target_y * width_in_bytes + x] = img.pixels.buf[y * width_in_bytes + x]
            flipped_buffer[target_y * width_in_bytes + x + 1] = img.pixels.buf[y * width_in_bytes + x + 1]
            flipped_buffer[target_y * width_in_bytes + x + 2] = img.pixels.buf[y * width_in_bytes + x + 2]
            if (img.channels == 4) {
                flipped_buffer[target_y * width_in_bytes + x + 3] = img.pixels.buf[y * width_in_bytes + x + 3]
            }
        }
        target_y += 1
    }
    defer delete(flipped_buffer)

    if img.channels == 3 {
        internal_format = gl.SRGB8
        data_format = gl.RGB
    }

    id: u32
    gl.CreateTextures(gl.TEXTURE_2D, 1, &id)

    // Mipmaps
    mipmap_levels := i32(1)

    gl.TextureParameteri(id, gl.TEXTURE_WRAP_S, gl.REPEAT)
    gl.TextureParameteri(id, gl.TEXTURE_WRAP_T, gl.REPEAT)
    gl.TextureParameteri(id, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TextureParameteri(id, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

    gl.TextureStorage2D(id, mipmap_levels, internal_format, width, height)

    gl.TextureSubImage2D(id, 0, 0, 0, width, height, data_format, gl.UNSIGNED_BYTE, raw_data(flipped_buffer))
    gl.GenerateTextureMipmap(id)

    texture := Texture {
        id = id,
        width = width,
        height = height,
        internal_format = internal_format,
        data_format = data_format,
    }

    append(&renderer.textures, texture)

    return Texture_Handle(len(renderer.textures))
}

_gl_destory_texure :: proc()