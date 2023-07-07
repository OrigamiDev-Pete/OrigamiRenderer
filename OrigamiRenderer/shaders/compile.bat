@echo off

if not exist spirv mkdir spirv

glslangvalidator shader.vert -o spirv/vert.spv -V
glslangvalidator shader.frag -o spirv/frag.spv -V

if "%1" == "-debug" goto debug

goto exit

:debug
    if not exist spirv\\debug mkdir spirv\\debug
    if not exist temp mkdir temp
    glslangvalidator shader.vert -o temp/vert.spv -H > spirv/debug/vert.text
    glslangvalidator shader.frag -o temp/frag.spv -H > spirv/debug/frag.text
    rmdir temp /Q /S
    goto exit

:exit