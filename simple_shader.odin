package main

VS_SOURCE :: `
#version 460 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in vec2 aUV;

layout(std140, binding = 0) uniform SceneState {
    mat4 view;
    mat4 proj;
    mat4 view_proj;
    vec3 camera_pos;
};

void main() {
    gl_Position = view_proj * vec4(aPos, 1.0);
}
`

FS_SOURCE :: `
#version 460 core
out vec4 FragColour;

void main() {
    vec3 colour = float(gl_FrontFacing) * vec3(0.0, 0.0, 1.0) + float(!gl_FrontFacing) * vec3(1.0, 0.0, 0.0);
    FragColour = vec4(colour, 1.0);
}
`