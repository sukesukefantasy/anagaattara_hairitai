#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_ambient_darkness;
uniform float u_participant_depth_factor;
uniform float u_num_lights;

const int MAX_LIGHTS = 12;
uniform vec2 u_light_positions[MAX_LIGHTS];
uniform float u_light_inner_radii[MAX_LIGHTS];
uniform float u_light_mid_radii[MAX_LIGHTS];
uniform float u_light_outer_radii[MAX_LIGHTS];
uniform float u_light_inner_cuts[MAX_LIGHTS];
uniform float u_light_mid_cuts[MAX_LIGHTS];
uniform float u_light_outer_cuts[MAX_LIGHTS];
uniform vec3 u_light_colors[MAX_LIGHTS];

layout(location = 0) out vec4 outColor;

float computeRingCut(
    float dist,
    float rInner,
    float rMid,
    float rOuter,
    float cutInner,
    float cutMid,
    float cutOuter
) {
    if (dist >= rOuter) {
        return 0.0;
    }
    if (dist <= rInner) {
        return cutInner;
    }
    if (dist <= rMid) {
        float t = smoothstep(rInner, rMid, dist);
        return mix(cutInner, cutMid, t);
    }
    float t = smoothstep(rMid, rOuter, dist);
    return mix(cutMid, cutOuter, t);
}

void main() {
    vec2 frag_screen_pos = FlutterFragCoord().xy;

    float effective_darkness = u_ambient_darkness;
    float depth = clamp(u_participant_depth_factor, 0.0, 1.0);

    for (int i = 0; i < MAX_LIGHTS; ++i) {
        if (float(i) >= u_num_lights) {
            break;
        }

        vec2 light_screen_pos = u_light_positions[i];
        float rInner = u_light_inner_radii[i];
        float rMid = u_light_mid_radii[i];
        float rOuter = u_light_outer_radii[i];
        float cutInner = u_light_inner_cuts[i];
        float cutMid = u_light_mid_cuts[i];
        float cutOuter = u_light_outer_cuts[i];

        float dist = distance(frag_screen_pos, light_screen_pos);
        float ring_cut = computeRingCut(
            dist,
            rInner,
            rMid,
            rOuter,
            cutInner,
            cutMid,
            cutOuter
        );

        if (ring_cut <= 0.0) {
            continue;
        }

        float light_strength = ring_cut * 0.035 * depth;
        effective_darkness = max(0.0, effective_darkness - light_strength);
    }

    float relight = 0.0;
    if (u_ambient_darkness > 0.001) {
        relight = 1.0 - effective_darkness / u_ambient_darkness;
    }
    relight = clamp(relight, 0.0, 1.0);
    outColor = vec4(1.0, 1.0, 1.0, relight);
}
