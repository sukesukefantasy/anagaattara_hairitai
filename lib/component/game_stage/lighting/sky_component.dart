import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../depth_zoom_visual.dart';
import '../../../game/world_scale.dart';
import '../../../game_manager/time_service.dart';
import '../../../main.dart';
import '../../../scene/abstract_outdoor_scene.dart';
import 'ambient_lighting_utils.dart';
import 'day_night_schedule.dart';
import 'light_receiver.dart';
import 'lighting_participant.dart';
import 'lighting_participation.dart';
import 'sun_modulate_mask.dart';

class SkyComponent extends RectangleComponent
    with
        HasGameReference<MyGame>,
        LightingParticipant,
        LightReceiver,
        DepthZoomVisual {
  final TimeService timeService;

  Color get currentSkyColor => _currentSkyColor;
  Color _currentSkyColor = Colors.black;

  double get currentAmbientBrightness => _currentAmbientBrightness;
  double _currentAmbientBrightness = 0.0;

  SkyComponent({required this.timeService})
    : super(
        position: Vector2(WorldScale.extendedWorldLeft, 0),
        paint: Paint()..color = const Color(0xFF84CAFF),
        priority: 1,
      );

  @override
  LightingParticipation get lightingParticipation =>
      LightingParticipation.none;

  @override
  double get worldDepthMeters => WorldScale.skyDepthMeters;

  @override
  Vector2? get depthZoomFocusWorld => game.cameraController.depthZoomFocusWorld;

  Color get currentColor => paint.color;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    position = Vector2(
      WorldScale.extendedWorldLeft,
      game.initialGameCanvasSize.y,
    );
    size = Vector2(
      WorldScale.extendedWorldWidth,
      game.initialGameCanvasSize.y * 2,
    );
    anchor = Anchor.bottomLeft;
    scale.setValues(1, 1);
    _updateSkyBackgroundColor();
    if (isMounted) {
      game.cameraController.syncDepthZoom();
    }
  }

  @override
  void render(Canvas canvas) {
    paintWithDepthZoom(canvas, (Canvas layerCanvas) => super.render(layerCanvas));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updateSkyBackgroundColor();
  }

  void _updateSkyBackgroundColor() {
    final state = DayNightSchedule.evaluate(
      timeService.hour,
      timeService.minute,
    );

    _currentSkyColor = state.skyColor;
    _currentAmbientBrightness = state.ambientBrightness;

    final fillColor = _skyFillColor(state);
    if (paint.color != fillColor) {
      paint.color = fillColor;
    }
  }

  /// 空は saveLayer ベールを使わず塗り色に暗さを合成する（遠景帯の均一ベールと境目を揃える）。
  Color _skyFillColor(DayNightState state) {
    final darkness = state.ambientBrightness;
    if (darkness <= 0.001) {
      return state.skyColor;
    }

    final scene = game.sceneManager.currentScene;
    if (scene is AbstractOutdoorScene) {
      final sun = scene.lightingWorld.sunState;
      return SunModulateMask.modulateFillColor(
        base: state.skyColor,
        darkness: darkness,
        tintR: sun.tintR,
        tintG: sun.tintG,
        tintB: sun.tintB,
      );
    }

    final rgb = AmbientLightingUtils.ambientColorRgb(
      state.skyColor,
      hour: timeService.hour,
      minute: timeService.minute,
    );
    final tint = AmbientLightingUtils.overlayStrength;
    return SunModulateMask.modulateFillColor(
      base: state.skyColor,
      darkness: darkness,
      tintR: rgb.r * tint,
      tintG: rgb.g * tint,
      tintB: rgb.b * tint,
    );
  }

}
