#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_global_alpha; // Day boost (0.0=max, 1.0=none)
uniform vec3 u_sky_color; // Optional: for subtle tinting of the boost

layout(location = 0) out vec4 outColor;

void main() {
    // Pure white ambient boost
    vec3 boost_color = vec3(0.0);
    if (u_global_alpha < 1.0) { 
        float boost_factor = 1.0 - u_global_alpha;
        boost_color = vec3(boost_factor * 0.08); // Pure white boost
    }
    
    // Output color for screen blend
    outColor = vec4(boost_color, 1.0); // Alpha should be 1.0 for screen blend to work
} 