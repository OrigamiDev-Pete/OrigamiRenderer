package OrigamiRenderer

Render_Packet :: struct {
    sort_key: u64,
    command: Render_Command
}

Render_Command :: union {
    Command_Bind_Texture,
    Command_Clear,
    Command_Draw,
    Command_Set_Shader,
    Command_Set_View_Port,
}

Command_Bind_Texture :: struct {
    slot: u32,
    texture: Texture_Handle
}

Command_Clear :: struct {
    colour: Colour4,
    depth: f32,
    stencil: f32
}

Command_Draw :: struct {
    mesh: Mesh_Handle
}

Command_Set_Shader :: struct {
    shader: Shader_Handle
}

Command_Set_View_Port :: struct {
    x, y, w, h: i32
}

