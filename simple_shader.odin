package main

VS_SOURCE :: `
#version 460 core
layout (location = 0) in vec3 aPos;

void main() {
    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
}
`

FS_SOURCE :: `
#version 460 core
out vec4 FragColour;

void main() {
    FragColour = vec4(1.0, 0.5, 0.2, 1.0);
}
`