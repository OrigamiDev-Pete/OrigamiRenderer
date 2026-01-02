package main

VS_SOURCE :: `
#version 460 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in vec2 aUV;

out vec2 vUV;

layout(std140, binding = 0) uniform SceneState {
    mat4 view;
    mat4 proj;
    mat4 view_proj;
    vec3 camera_pos;
};

void main() {
    vUV = aUV;
    gl_Position = view_proj * vec4(aPos, 1.0);
}
`

FS_SOURCE :: `
#version 460 core

in vec2 vUV;

layout(binding = 0) uniform sampler2D albedoMap;

out vec4 FragColour;

void main() {
    // vec3 colour = float(gl_FrontFacing) * vec3(0.0, 0.0, 1.0) + float(!gl_FrontFacing) * vec3(1.0, 0.0, 0.0);
    vec4 colour = texture(albedoMap, vUV);
    FragColour = vec4(colour.rgb, 1.0);
}
`