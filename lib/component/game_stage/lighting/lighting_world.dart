import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../game_manager/time_service.dart';
import '../../../main.dart';
import '../../../scene/abstract_outdoor_scene.dart';
import '../../item/lantern_item.dart';
import '../gamestage_component.dart';
import 'ambient_lighting_utils.dart';
import 'day_night_schedule.dart';
import 'light_emitter.dart';
import 'light_emitter_gather.dart';
import 'lighting_constants.dart';
import 'lighting_meter_fade.dart';
import 'lighting_participant.dart';
import 'lighting_participation.dart';
import 'sky_component.dart';

/// 太陽（時間帯）のグローバル光。
final class GlobalSunState {
  const GlobalSunState({
    required this.ambientBrightness,
    required this.skyColor,
    required this.tintR,
    required this.tintG,
    required this.tintB,
  });

  final double ambientBrightness;
  final Color skyColor;
  final double tintR;
  final double tintG;
  final double tintB;

  static const GlobalSunState none = GlobalSunState(
    ambientBrightness: 0,
    skyColor: Colors.black,
    tintR: 0,
    tintG: 0,
    tintB: 0,
  );
}

/// シーン単位の照明状態（Emitter 収集・太陽評価）。
final class LightingWorld {
  LightingWorld({
    required this.timeService,
  });

  final TimeService timeService;
  int _lanternPulseFrame = 0;

  GlobalSunState sunState = GlobalSunState.none;
  List<LightEmitter> localEmitters = const [];
  List<LightEmitter> transientDynamicEmitters = const [];

  void beginFrame() {
    _lanternPulseFrame =
        (_lanternPulseFrame + 1) % LanternItem.radiusPulsePeriodFrames;
  }

  double get lanternRadiusPulseScale {
    final phase = _lanternPulseFrame / LanternItem.radiusPulsePeriodFrames;
    final wave = math.sin(phase * math.pi * 2.0);
    return 1.0 + LanternItem.radiusPulseAmplitude * wave;
  }

  void updateFromGame(MyGame game) {
    if (!_isOutdoorScene(game)) {
      sunState = GlobalSunState.none;
      localEmitters = const [];
      transientDynamicEmitters = const [];
      return;
    }

    final scene = game.sceneManager.currentScene as AbstractOutdoorScene;
    final sky = scene.skyBackgroundComponent;

    if (sky == null) {
      sunState = GlobalSunState.none;
      localEmitters = const [];
      transientDynamicEmitters = const [];
      return;
    }

    if (game.player.inUnderGround) {
      final rgb = AmbientLightingUtils.ambientColorRgb(
        const Color(0xFF191970),
        hour: timeService.hour,
        minute: timeService.minute,
      );
      final tint = AmbientLightingUtils.overlayStrength;
      sunState = GlobalSunState(
        ambientBrightness: kUndergroundAmbientBrightness,
        skyColor: const Color(0xFF191970),
        tintR: rgb.r * tint,
        tintG: rgb.g * tint,
        tintB: rgb.b * tint,
      );
    } else {
      final rgb = AmbientLightingUtils.ambientColorRgb(
        sky.currentSkyColor,
        hour: timeService.hour,
        minute: timeService.minute,
      );
      final tint = AmbientLightingUtils.overlayStrength;
      sunState = GlobalSunState(
        ambientBrightness: sky.currentAmbientBrightness,
        skyColor: sky.currentSkyColor,
        tintR: rgb.r * tint,
        tintG: rgb.g * tint,
        tintB: rgb.b * tint,
      );
    }

    localEmitters = gatherLocalEmitters(
      game,
      lanternRadiusScale: lanternRadiusPulseScale,
    );
    transientDynamicEmitters = _gatherTransientDynamicEmitters(scene);
  }

  /// 環境（太陽）暗さ。viewport オーバーレイと同様に奥行き punch は使わない。
  /// [LightingParticipation.none] でも太陽暗化はかかる（ランタン relight のみ無効）。
  double sunDarknessFor({
    required LightingParticipation participation,
  }) {
    return sunState.ambientBrightness.clamp(0.0, 1.0);
  }

}

bool _isOutdoorScene(MyGame game) =>
    game.sceneManager.currentScene is AbstractOutdoorScene;

List<LightEmitter> _gatherTransientDynamicEmitters(AbstractOutdoorScene scene) {
  final emitters = <LightEmitter>[];
  for (final child in scene.children) {
    if (child is GameStageComponent && child.shootingStarLight.isActive) {
      emitters.add(child.shootingStarLight);
    }
  }
  return emitters;
}

List<LightEmitter> gatherLocalEmitters(
  MyGame game, {
  double lanternRadiusScale = 1.0,
}) {
  return LightEmitterGather.gatherActiveLights(
    game,
    globalRadiusPulseScale: lanternRadiusScale,
  ).map((e) => e.asEmitter()).toList();
}

double lightingReceiverDepthFactor({
  required LightingParticipant participant,
  required PositionComponent component,
  required List<LightEmitter> emitters,
}) {
  if (emitters.isEmpty) {
    return 0.0;
  }
  final punch = participant.lightingPunchFactor;
  if (punch < 0.01) {
    return 0.0;
  }

  final isSelfLantern = emitters.length == 1 &&
      emitters.single is LanternItem &&
      identical(component, emitters.single);

  final meterFade = isSelfLantern
      ? 1.0
      : LightingMeterFade.maxAmongLights(
          lights: emitters
              .map(
                (l) => (
                  worldCenter: l.worldCenter,
                  reachGameUnits: l.profile.outerRadius * l.radiusScale,
                ),
              )
              .toList(),
          participantWorldRect: component.toAbsoluteRect(),
        );

  return (punch * meterFade).clamp(0.0, 1.0);
}

/// [SkyComponent] 用: スケジュールから昼の基準空色のみ（暗さは render で付与）。
Color skyBaseColorForTime(TimeService timeService) {
  return DayNightSchedule.evaluate(
    timeService.hour,
    timeService.minute,
  ).skyColor;
}
