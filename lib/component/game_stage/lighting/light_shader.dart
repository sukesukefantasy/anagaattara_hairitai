import 'package:flame/components.dart';
import 'package:flame/experimental.dart'; // ShaderComponentをインポート
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import '../../../main.dart'; // MyGameをインポート
import 'light_component.dart'; // LightComponentをインポート
import '../../../game_manager/time_service.dart'; // TimeServiceをインポート
import '../../../scene/outdoor_scene.dart'; // OutdoorSceneをインポート
import '../../../scene/abstract_outdoor_scene.dart'; // AbstractOutdoorSceneをインポート

class LightingOverlayComponent extends RectangleComponent
    with HasGameReference<MyGame> {
  late final ui.FragmentShader _lightingShader; // lighting.frag用
  late final ui.FragmentShader _brightnessBoostShader; // brightness_boost.frag用

  final TimeService timeService; // 時間サービスを受け取る

  LightingOverlayComponent({required this.timeService, super.priority = 100}); // super parameter を使用

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    debugPrint('LightingOverlayComponent: onLoad - position: $position, size: $size, priority: $priority');

    // シェーダーをロード
    final lightingProgram = await ui.FragmentProgram.fromAsset(
      'assets/shaders/lighting.frag',
    );
    _lightingShader = lightingProgram.fragmentShader();

    final brightnessBoostProgram = await ui.FragmentProgram.fromAsset(
      'assets/shaders/brightness_boost.frag',
    );
    _brightnessBoostShader = brightnessBoostProgram.fragmentShader();

    // このコンポーネント自体のサイズと位置を設定
    // camera.viewportに追加されることを想定し、ゲームの現在のキャンバスサイズに設定
    size = game.size; // game.initialGameCanvasSize ではなく game.size を使用
    position = Vector2.zero();
    debugPrint('LightingOverlayComponent: size set to ${size}, position set to ${position}');
  }

  @override
  void update(double dt) {
    super.update(dt);

    // シェーダーにUniformsを設定
    _updateLightingShaderUniforms();
    _updateBrightnessBoostShaderUniforms();

    // RectangleComponentのpaintプロパティにシェーダーを設定して描画を委ねる
    paint.shader = _lightingShader;
  }

  void _updateLightingShaderUniforms() {
    final skyComponent =
        game.sceneManager.currentScene is AbstractOutdoorScene
            ? (game.sceneManager.currentScene as AbstractOutdoorScene)
                .skyBackgroundComponent
            : null;

    double newAmbientBrightness = 0.0;

    if (skyComponent != null) {
      newAmbientBrightness = skyComponent.currentAmbientBrightness;
    }

    double darknessAlpha = newAmbientBrightness;

    _lightingShader.setFloat(0, game.initialGameCanvasSize.x);
    _lightingShader.setFloat(1, game.initialGameCanvasSize.y);

    _lightingShader.setFloat(2, darknessAlpha);

    final lights =
        game.sceneManager.currentScene is AbstractOutdoorScene
            ? (game.sceneManager.currentScene as AbstractOutdoorScene).children
                .whereType<LightComponent>()
                .toList()
            : [];

    const int maxLights = 3;
    _lightingShader.setFloat(3, lights.length.clamp(0, maxLights).toDouble());

    const int lightPositionsBaseIndex = 4;
    const int lightRadiiBaseIndex = lightPositionsBaseIndex + maxLights * 2;
    const int lightColorsBaseIndex = lightRadiiBaseIndex + maxLights;
    const int lightIntensitiesBaseIndex = lightColorsBaseIndex + maxLights * 4;

    // デバッグモード用のUniformを追加 (1.0でデバッグON, 0.0でデバッグOFF)
    final double debugMode = 0.0; // デバッグOFFに戻す
    _lightingShader.setFloat(
      lightIntensitiesBaseIndex + maxLights,
      debugMode,
    ); // u_debug_mode

    for (int i = 0; i < maxLights; i++) {
      if (i < lights.length) {
        final light = lights[i];

        // ライトの位置をワールド座標から画面座標に変換
        final lightWorldCenter =
            light.position + light.size * 0.5; // ライトの中心のワールド座標

        // カメラの可視領域の左上ワールド座標とズームレベルを取得
        final visibleRect = game.camera.visibleWorldRect;
        final cameraZoom = game.camera.viewfinder.zoom;

        // ワールド座標から画面座標への手動変換
        // 画面座標 = (ワールド座標 - カメラ可視領域の左上ワールド座標) * ズーム
        final lightScreenPosition = Vector2(
          (lightWorldCenter.x - visibleRect.topLeft.dx) * cameraZoom,
          (lightWorldCenter.y - visibleRect.topLeft.dy) * cameraZoom,
        );

        // ライトの半径も現在のズームレベルに合わせて調整（画面ピクセル単位）
        final lightScreenRadius = light.lightRadius * cameraZoom;

        _lightingShader.setFloat(
          lightPositionsBaseIndex + i * 2 + 0,
          lightScreenPosition.x,
        );
        _lightingShader.setFloat(
          lightPositionsBaseIndex + i * 2 + 1,
          lightScreenPosition.y,
        );
        _lightingShader.setFloat(lightRadiiBaseIndex + i, lightScreenRadius);
        _lightingShader.setFloat(
          lightIntensitiesBaseIndex + i,
          light.lightIntensity,
        );
        _lightingShader.setFloat(lightColorsBaseIndex + i * 4 + 0, 0.0);
        _lightingShader.setFloat(lightColorsBaseIndex + i * 4 + 1, 0.0);
        _lightingShader.setFloat(lightColorsBaseIndex + i * 4 + 2, 0.0);
        _lightingShader.setFloat(lightColorsBaseIndex + i * 4 + 3, 0.0);

        /* debugPrint(
          '    Light $i (Darkness Shader): screen_pos=$lightScreenPosition, screen_radius=$lightScreenRadius, intensity=${light.lightIntensity}',
        ); */
      } else {
        _lightingShader.setFloat(lightPositionsBaseIndex + i * 2 + 0, 0.0);
        _lightingShader.setFloat(lightPositionsBaseIndex + i * 2 + 1, 0.0);
        _lightingShader.setFloat(lightRadiiBaseIndex + i, 0.0);
        _lightingShader.setFloat(lightIntensitiesBaseIndex + i, 0.0);
        _lightingShader.setFloat(lightColorsBaseIndex + i * 4 + 0, 0.0);
        _lightingShader.setFloat(lightColorsBaseIndex + i * 4 + 1, 0.0);
        _lightingShader.setFloat(lightColorsBaseIndex + i * 4 + 2, 0.0);
        _lightingShader.setFloat(lightColorsBaseIndex + i * 4 + 3, 0.0);
      }
    }
  }

  void _updateBrightnessBoostShaderUniforms() {
    //debugPrint('Updating Brightness Boost Shader Uniforms');
    final skyComponent =
        game.sceneManager.currentScene is AbstractOutdoorScene
            ? (game.sceneManager.currentScene as AbstractOutdoorScene)
                .skyBackgroundComponent
            : null;

    Color newSkyColor = Colors.black;
    double newAmbientBrightness = 0.0;

    if (skyComponent != null) {
      newSkyColor = skyComponent.currentSkyColor;
      newAmbientBrightness = skyComponent.currentAmbientBrightness;
    }

    final adjustedSkyColor = _desaturateColor(newSkyColor, 0.6);

    double ambientBrightnessBoostAlpha;
    if (newAmbientBrightness >= 0.5) {
      ambientBrightnessBoostAlpha = 1.0;
    } else {
      ambientBrightnessBoostAlpha =
          ui.lerpDouble(0.0, 1.0, newAmbientBrightness / 0.5)!;
    }

    _brightnessBoostShader.setFloat(0, game.initialGameCanvasSize.x);
    _brightnessBoostShader.setFloat(1, game.initialGameCanvasSize.y);

    _brightnessBoostShader.setFloat(2, ambientBrightnessBoostAlpha);

    _brightnessBoostShader.setFloat(3, adjustedSkyColor.red / 255.0);
    _brightnessBoostShader.setFloat(4, adjustedSkyColor.green / 255.0);
    _brightnessBoostShader.setFloat(5, adjustedSkyColor.blue / 255.0);
  }

  Color _desaturateColor(Color color, double factor) {
    final double r = color.red / 255.0;
    final double g = color.green / 255.0;
    final double b = color.blue / 255.0;

    final double gray = 0.299 * r + 0.587 * g + 0.114 * b;

    final double newR = r + (gray - r) * factor;
    final double newG = g + (gray - g) * factor;
    final double newB = b + (gray - b) * factor;

    return Color.fromARGB(
      color.alpha,
      (newR * 255).round().clamp(0, 255),
      (newG * 255).round().clamp(0, 255),
      (newB * 255).round().clamp(0, 255),
    );
  }

  @override
  void render(Canvas canvas) {
    if (!isLoaded) return;

    // darknessOverlayシェーダーを適用
    canvas.drawRect(size.toRect(), paint);

    // brightnessBoostShaderを適用 (一時的にコメントアウト)
    /*
    final brightnessPaint = Paint()
      ..shader = _brightnessBoostShader
      ..blendMode = BlendMode.screen; 
    canvas.drawRect(size.toRect(), brightnessPaint); 
    */
  }
}
