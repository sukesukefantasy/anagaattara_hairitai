// Reserved for future fog effect. Not loaded at runtime.
#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_global_alpha;
uniform vec3 u_sky_color;

layout(location = 0) out vec4 outColor;

void main() {
    vec3 boost_color = vec3(0.0);
    if (u_global_alpha < 1.0) {
        float boost_factor = 1.0 - u_global_alpha;
        vec3 dark_sky = mix(u_sky_color, vec3(0.0), 0.35);
        boost_color = dark_sky * boost_factor * 0.015;
    }

    outColor = vec4(boost_color, 1.0);
}
