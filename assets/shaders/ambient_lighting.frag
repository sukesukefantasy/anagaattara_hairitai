#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_darkness_alpha;
uniform vec3 u_ambient_color;

layout(location = 0) out vec4 outColor;

void main() {
    vec3 ambient_dark = mix(u_ambient_color, u_ambient_color * 0.45, u_darkness_alpha);
    outColor = vec4(ambient_dark * u_darkness_alpha, u_darkness_alpha);
}
