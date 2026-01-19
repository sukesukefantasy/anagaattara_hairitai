#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_darkness_alpha;

const int MAX_LIGHTS = 3;
uniform float u_num_lights;

uniform vec2 u_light_positions[MAX_LIGHTS]; // 画面座標
uniform float u_light_radii[MAX_LIGHTS];     // 画面スケールに合わせた半径
uniform vec4 u_light_colors[MAX_LIGHTS];
uniform float u_light_intensities[MAX_LIGHTS];
uniform float u_debug_mode; // デバッグモードのUniformを追加

layout(location = 0) out vec4 outColor;

void main() {
    // フラグメントの画面座標（ピクセル単位）
    vec2 frag_screen_pos = FlutterFragCoord().xy;

    float effective_darkness = u_darkness_alpha;
    vec3 debug_color_mix = vec3(0.0); // デバッグ用の色を混ぜるため

    for (int i = 0; i < MAX_LIGHTS; ++i) {
        if (float(i) >= u_num_lights) {
            break;
        }

        vec2 light_screen_pos = u_light_positions[i]; // ライトの画面座標
        float light_radius = u_light_radii[i];       // 画面スケールに合わせた半径
        float light_intensity = u_light_intensities[i];

        float dist = distance(frag_screen_pos, light_screen_pos);
        float light_falloff = 1.0 - smoothstep(0.0, light_radius * 1.0, dist);

        effective_darkness = max(0.0, effective_darkness - light_falloff * light_intensity * 100.0);
    }

    // デバッグモードの色を最終出力に反映
    outColor = vec4(0.0, 0.0, 0.0, effective_darkness);
}