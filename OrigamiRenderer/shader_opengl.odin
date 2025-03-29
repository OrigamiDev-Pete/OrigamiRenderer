#+private
package OrigamiRenderer

import "core:log"
import "core:strings"

import gl "vendor:OpenGL"

OpenGL_Shader :: struct {
    using base: Shader_Base,
    handle: u32
}

OpenGL_Program :: struct {
    using base: Program_Base,
    handle: u32
}

_gl_create_shader :: proc(r: ^OpenGL_Renderer, code: []u8, type: Shader_Type) -> (^OpenGL_Shader, OpenGL_Error) {
    gl_shader_type: u32 = ---
    switch type {
        case .Vertex:
            gl_shader_type = gl.VERTEX_SHADER
        case .Fragment:
            gl_shader_type = gl.FRAGMENT_SHADER
    }

    shader_handle := gl.CreateShader(gl_shader_type)
    if shader_handle == 0 do return nil, .Cannot_Create_Shader_Object

    shader_source_cstring := cstring(raw_data(code))
    source_length := []i32{i32(len(code))}
    gl.ShaderSource(shader_handle, 1, &shader_source_cstring, raw_data(source_length))
    gl.CompileShader(shader_handle)
    success: i32 = ---
    gl.GetShaderiv(shader_handle, gl.COMPILE_STATUS, &success)
    if success == 0 {
        info_log_bytes: [512]u8
        log_length: i32
        gl.GetShaderInfoLog(shader_handle, 512, &log_length, raw_data(info_log_bytes[:]))
        info_log := strings.string_from_ptr(&info_log_bytes[0], int(log_length))
        log.error(info_log)
        return nil, .Cannot_Compile_Shader
    }

    shader := new(Shader)
    shader^ = OpenGL_Shader {
        code = code,
        handle = shader_handle
    }

    return auto_cast shader, .None
}

_gl_destroy_shader :: proc(r: OpenGL_Renderer, shader: ^OpenGL_Shader) {
    gl.DeleteShader(shader.handle)
    when ODIN_DEBUG {
        delete(shader.code)
    }
    free(shader)
}

_gl_create_program :: proc(r: ^OpenGL_Renderer, vertex_shader, fragment_shader: ^OpenGL_Shader) -> (^OpenGL_Program, OpenGL_Error) {
    
    program_handle := gl.CreateProgram()
    gl.AttachShader(program_handle, vertex_shader.handle)
    gl.AttachShader(program_handle, fragment_shader.handle)
    gl.LinkProgram(program_handle)

    success: i32 = ---
    gl.GetProgramiv(program_handle, gl.LINK_STATUS, &success)
    if success == 0 {
        info_log_bytes: [512]u8
        log_length: i32
        gl.GetProgramInfoLog(program_handle, 512, &log_length, raw_data(info_log_bytes[:]))
        info_log := strings.string_from_ptr(&info_log_bytes[0], int(log_length))
        log.error(info_log)
        return nil, .Cannot_Compile_Shader
    }

    _gl_destroy_shader(r^, vertex_shader)
    _gl_destroy_shader(r^, fragment_shader)

    program := new(Program)
    program^ = OpenGL_Program {
        handle = program_handle
    }

    return auto_cast program, nil
}