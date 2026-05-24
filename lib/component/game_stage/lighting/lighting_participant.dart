import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../game/world_scale.dart';
import '../../../main.dart';
import '../../../scene/abstract_outdoor_scene.dart';
import 'camera_viewport_coords.dart';
import 'lighting_participation.dart';

/// [LightingParticipation] をコンポーネントに持たせる mixin。
mixin LightingParticipant on PositionComponent {
  LightingParticipation get lightingParticipation;

  /// プレイフィールドからの奥行き（m）。奥=正、手前=負。
  double get worldDepthMeters => WorldScale.playfieldDepthMeters;

  /// Z 奥行きに応じたローカル光 punch（0..1）。
  double get lightingPunchFactor =>
      WorldScale.lightingPunchForDepthMeters(worldDepthMeters);

  /// シェーダー relight 用（[lightingPunchFactor] のエイリアス）。
  double get lightingDepthMeters => lightingPunchFactor;
}

/// full 参加者の収集と viewport 変換。
abstract final class LightingParticipantBounds {
  LightingParticipantBounds._();

  static List<PositionComponent> collectFullParticipants(MyGame game) {
    if (game.sceneManager.currentScene is! AbstractOutdoorScene) {
      return const [];
    }

    final scene = game.sceneManager.currentScene as AbstractOutdoorScene;
    final participants = <PositionComponent>[];

    void consider(PositionComponent component) {
      if (!component.isMounted) {
        return;
      }
      participants.add(component);
    }

    void walk(Component node) {
      if (node is LightingParticipant &&
          node.lightingParticipation == LightingParticipation.full) {
        consider(node);
      }
      for (final child in node.children) {
        walk(child);
      }
    }

    walk(scene);

    for (final component in game.world.children) {
      if (component is! PositionComponent || !component.isMounted) {
        continue;
      }
      if (component is LightingParticipant &&
          component.lightingParticipation == LightingParticipation.full) {
        consider(component);
      }
    }

    return participants;
  }

  static Rect worldRectToViewportRect(CameraComponent camera, Rect world) {
    return CameraViewportCoords.worldRectToScreenRect(camera, world);
  }
}
