import 'dart:ui' show Rect;

import 'package:flame/components.dart';

import 'terrain_collision_samples.dart';
import 'terrain_field.dart';

/// 頭・胴・足の3プローブ組み合わせによる地形分類。
enum TerrainContactKind {
  open,
  floorLedge,
  ceiling,
  slopeCeiling,
  wall,
}

abstract final class BodyTerrainProbes {
  static const double aheadProbePx = 6.0;
  static const double torsoHeightFactor = 0.65;

  /// 移動 intent 方向の前方3点を分類する。
  static TerrainContactKind classifyAhead({
    required Rect aabb,
    required TerrainField terrain,
    required int intent,
    double aheadPx = aheadProbePx,
  }) {
    if (intent == 0) return TerrainContactKind.open;

    final aheadX = aabb.center.dx + intent * aheadPx;
    final foot = Vector2(aheadX, aabb.bottom - 2);
    final torso = Vector2(aheadX, aabb.top + aabb.height * torsoHeightFactor);
    final headPoints = TerrainCollisionSamples.headProbePoints(aabb);
    final headAhead = Vector2(aheadX, headPoints.first.y);

    final f = _blocked(terrain, foot);
    final t = _blocked(terrain, torso);
    final h = _blocked(terrain, headAhead);

    // wall > ceiling / slopeCeiling > floorLedge > open
    if (f && t && h) return TerrainContactKind.wall;
    if (h && !f) return TerrainContactKind.slopeCeiling;
    if (h && !t) return TerrainContactKind.ceiling;
    if (f && t && !h) return TerrainContactKind.floorLedge;
    if (f && !t && !h) return TerrainContactKind.floorLedge;
    return TerrainContactKind.open;
  }

  /// 横移動で壁として止めるべきか（前方が全面の岩）。
  static bool isWallAhead({
    required Rect aabb,
    required TerrainField terrain,
    required int intent,
  }) =>
      classifyAhead(aabb: aabb, terrain: terrain, intent: intent) ==
      TerrainContactKind.wall;

  /// 段差乗り上げ可能か（足+胴が岩、頭は空）。
  static bool isFloorLedgeAhead({
    required Rect aabb,
    required TerrainField terrain,
    required int intent,
  }) =>
      classifyAhead(aabb: aabb, terrain: terrain, intent: intent) ==
      TerrainContactKind.floorLedge;

  static bool _blocked(TerrainField terrain, Vector2 point) =>
      terrain.isBlocked(TerrainCollisionSamples.probeRect(point));
}
