import 'dart:ui' show Offset, Rect;

import 'package:flame/components.dart';

/// ギザ岩盤での横・縦衝突用サンプル点（頭・天井は判定しない）。
abstract final class TerrainCollisionSamples {
  static const double _probeSize = 4;

  /// 横移動の壁判定：腰〜胴（足元は下り坂の床を壁と誤認しやすいので含めない）。
  static Iterable<Vector2> horizontalWallProbePoints(Rect aabb) sync* {
    final midY = aabb.top + aabb.height * 0.58;
    final lowY = aabb.top + aabb.height * 0.74;
    for (final x in [
      aabb.left + aabb.width * 0.18,
      aabb.center.dx,
      aabb.right - aabb.width * 0.18,
    ]) {
      yield Vector2(x, midY);
      yield Vector2(x, lowY);
    }
  }

  /// 落下・下向き移動：足元バンドのみ。
  static Iterable<Vector2> verticalDownProbePoints(Rect aabb) sync* {
    final footY = aabb.bottom - 2;
    yield Vector2(aabb.center.dx, footY);
    yield Vector2(aabb.left + aabb.width * 0.22, footY);
    yield Vector2(aabb.right - aabb.width * 0.22, footY);
    yield Vector2(aabb.center.dx, aabb.bottom - aabb.height * 0.12);
  }

  /// 上昇・頭めり込み判定：頭頂バンドのみ（胴・足のめり込みは許容）。
  static Iterable<Vector2> headProbePoints(Rect aabb) sync* {
    final headY = aabb.top + 2;
    yield Vector2(aabb.left + aabb.width * 0.2, headY);
    yield Vector2(aabb.center.dx, headY);
    yield Vector2(aabb.right - aabb.width * 0.2, headY);
  }

  /// 通行可能判定用：AABB 四隅＋中心（[StampTerrainField.isBlocked] と同一）。
  static Iterable<Vector2> cornerAndCenterProbePoints(Rect aabb) sync* {
    yield Vector2(aabb.left, aabb.top);
    yield Vector2(aabb.right, aabb.top);
    yield Vector2(aabb.left, aabb.bottom);
    yield Vector2(aabb.right, aabb.bottom);
    yield Vector2(aabb.center.dx, aabb.center.dy);
  }

  static bool isHeadBlocked(Rect aabb, bool Function(Rect probe) blocked) {
    for (final p in headProbePoints(aabb)) {
      if (blocked(probeRect(p))) return true;
    }
    return false;
  }

  static Rect probeRect(Vector2 center) => Rect.fromCenter(
        center: Offset(center.x, center.y),
        width: _probeSize,
        height: _probeSize,
      );
}
