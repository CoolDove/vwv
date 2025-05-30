#version 440 core
out vec4 FragColor;

#include "dude"

layout(location = 0) in vec2 _uv;
layout(location = 1) in vec4 _color;

uniform sampler2D main_texture;

void main() {
    vec4 col = _color;
    col.a *= texture(main_texture, _uv).r;
    FragColor = col;
}
