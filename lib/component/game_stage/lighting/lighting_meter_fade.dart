import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../game/world_scale.dart';

/// ライト中心と参加者のワールド水平距離（m）による減衰。
abstract final class LightingMeterFade {
  LightingMeterFade._();

  /// [rect] 上のライトに最も近い点（中心ではなく最近点）。
  static Vector2 closestPointOnRect(Rect rect, Vector2 point) {
    return Vector2(
      point.x.clamp(rect.left, rect.right),
      point.y.clamp(rect.top, rect.bottom),
    );
  }

  /// 有効到達距離（ゲーム単位）とワールド距離から 0..1 の fade を返す。
  static double compute({
    required Vector2 lightWorldCenter,
    required Vector2 participantWorldCenter,
    required double reachGameUnits,
  }) {
    if (reachGameUnits <= 0) {
      return 0.0;
    }
    final worldDistM = WorldScale.worldDistanceMeters(
      lightWorldCenter,
      participantWorldCenter,
    );
    final reachM = reachGameUnits / WorldScale.pixelsPerMeter;
    return (1.0 - (worldDistM / reachM).clamp(0.0, 1.0));
  }

  /// 参加者矩形の最近点で [meterFade] を求める（Ground 等の巨大 rect 用）。
  static double forParticipantRect({
    required Vector2 lightWorldCenter,
    required Rect participantWorldRect,
    required double reachGameUnits,
  }) {
    return compute(
      lightWorldCenter: lightWorldCenter,
      participantWorldCenter:
          closestPointOnRect(participantWorldRect, lightWorldCenter),
      reachGameUnits: reachGameUnits,
    );
  }

  /// 複数光源のうち、参加者に対して最も届く fade（最大値）を返す。
  static double maxAmongLights({
    required Iterable<({Vector2 worldCenter, double reachGameUnits})> lights,
    required Rect participantWorldRect,
  }) {
    var best = 0.0;
    for (final light in lights) {
      final fade = forParticipantRect(
        lightWorldCenter: light.worldCenter,
        participantWorldRect: participantWorldRect,
        reachGameUnits: light.reachGameUnits,
      );
      if (fade > best) {
        best = fade;
      }
    }
    return best;
  }
}
