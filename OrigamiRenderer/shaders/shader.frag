#version 450

layout (location = 0) in vec3 iColour;

layout (location = 0) out vec4 FragColour;

void main()
{
    FragColour = vec4(iColour, 1.0);
}