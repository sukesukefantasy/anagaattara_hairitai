import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../scene/abstract_outdoor_scene.dart';
import '../building/building_data.dart';
import 'light_emitter.dart';
import 'light_emitter_spec.dart';
import 'light_profile.dart';

/// burst 中だけ有効な動的 [LightEmitter]（Ground の dynamic punch 用）。
final class TransientShootingStarLight implements LightEmitter {
  TransientShootingStarLight();

  Vector2 _worldCenter = Vector2.zero();
  LightEmitterSpec _spec = LightEmitterSpec.shootingStar;
  bool _active = false;

  void sync({
    required Vector2 worldCenter,
    required LightEmitterSpec spec,
  }) {
    _worldCenter.setFrom(worldCenter);
    _spec = spec;
    _active = true;
  }

  void deactivate() {
    _active = false;
  }

  @override
  Vector2 get worldCenter => _worldCenter;

  @override
  LightProfile get profile => _spec.profile;

  @override
  Color get color => _spec.color;

  @override
  double get radiusScale => 1.0;

  @override
  bool get usesGlobalRadiusPulse => false;

  @override
  double get warmTintStrength => _spec.warmTintStrength;

  @override
  bool get isActive => _active;
}

/// シート burst アニメに同期する流れ星ライトの座標計算。
abstract final class ShootingStarLightSync {
  ShootingStarLightSync._();

  /// burst 進行 0..1（playStartFrame=0、playEndFrame=1）。
  static double? burstProgress({
    required BackgroundSheetAnimation anim,
    required bool playingBurst,
    required int frameIndex,
  }) {
    if (!playingBurst) {
      return null;
    }
    final span = anim.playEndFrame - anim.playStartFrame;
    if (span <= 0) {
      return 0.0;
    }
    return ((frameIndex - anim.playStartFrame) / span).clamp(0.0, 1.0);
  }

  /// 流れ星のワールド座標（Ground 走査用）。
  static Vector2? worldCenter({
    required MyGame game,
    required BackgroundSheetLightSync sync,
    required BackgroundSheetAnimation anim,
    required bool playingBurst,
    required int frameIndex,
  }) {
    final progress = burstProgress(
      anim: anim,
      playingBurst: playingBurst,
      frameIndex: frameIndex,
    );
    if (progress == null) {
      return null;
    }

    final scene = game.sceneManager.currentScene;
    if (scene is! AbstractOutdoorScene) {
      return null;
    }
    final ground = scene.ground;
    if (ground == null || !ground.isMounted) {
      return null;
    }

    final x = sync.fromWorldX + (sync.toWorldX - sync.fromWorldX) * progress;
    final y = ground.position.y + ground.size.y * sync.groundYNormalized;
    return Vector2(x, y);
  }

  static void updateEmitter({
    required TransientShootingStarLight emitter,
    required MyGame game,
    required BackgroundSheetLightSync? sync,
    required BackgroundSheetAnimation? anim,
    required bool playingBurst,
    required int frameIndex,
  }) {
    if (sync == null || anim == null) {
      emitter.deactivate();
      return;
    }
    final center = worldCenter(
      game: game,
      sync: sync,
      anim: anim,
      playingBurst: playingBurst,
      frameIndex: frameIndex,
    );
    if (center == null) {
      emitter.deactivate();
      return;
    }
    emitter.sync(worldCenter: center, spec: sync.emitterSpec());
  }

  /// 遠景スプライト上の空フラッシュ中心（コンポーネント local）。
  static Offset? skyFlashLocalCenter({
    required MyGame game,
    required double componentWorldLeft,
    required double layerHeight,
    required double depthMeters,
    required BackgroundSheetLightSync sync,
    required BackgroundSheetAnimation anim,
    required bool playingBurst,
    required int frameIndex,
  }) {
    final progress = burstProgress(
      anim: anim,
      playingBurst: playingBurst,
      frameIndex: frameIndex,
    );
    if (progress == null) {
      return null;
    }

    final worldX =
        sync.fromWorldX + (sync.toWorldX - sync.fromWorldX) * progress;
    final pseudo3D = game.cameraController.outdoorPseudo3D;
    final localX =
        pseudo3D.projectedWorldX(worldX, depthMeters) - componentWorldLeft;
    final localY = layerHeight * sync.skyYNormalized;
    return Offset(localX, localY);
  }
}
