import 'dart:math';
import 'dart:ui' show Rect;

import 'package:flame/components.dart';

/// 地形スタンプ用のポリゴン幾何。
class PolygonTerrainMath {
  PolygonTerrainMath._();

  static bool containsPoint(List<Vector2> worldVerts, Vector2 p) {
    if (worldVerts.length < 3) return false;
    var inside = false;
    for (var i = 0, j = worldVerts.length - 1; i < worldVerts.length; j = i++) {
      final xi = worldVerts[i].x;
      final yi = worldVerts[i].y;
      final xj = worldVerts[j].x;
      final yj = worldVerts[j].y;
      final intersect = ((yi > p.y) != (yj > p.y)) &&
          (p.x <
              (xj - xi) * (p.y - yi) / (yj - yi + 1e-12) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  static Rect boundingBox(Iterable<Vector2> verts) {
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;
    for (final v in verts) {
      if (v.x < minX) minX = v.x;
      if (v.y < minY) minY = v.y;
      if (v.x > maxX) maxX = v.x;
      if (v.y > maxY) maxY = v.y;
    }
    if (minX == double.infinity) {
      return Rect.zero;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static Vector2 centroid(Iterable<Vector2> verts) {
    var sumX = 0.0;
    var sumY = 0.0;
    var n = 0;
    for (final v in verts) {
      sumX += v.x;
      sumY += v.y;
      n++;
    }
    if (n == 0) return Vector2.zero();
    return Vector2(sumX / n, sumY / n);
  }

  static double signedArea(List<Vector2> verts) {
    if (verts.length < 3) return 0;
    var area = 0.0;
    for (var i = 0; i < verts.length; i++) {
      final j = (i + 1) % verts.length;
      area += verts[i].x * verts[j].y - verts[j].x * verts[i].y;
    }
    return area * 0.5;
  }

  static bool segmentsIntersect(
    Vector2 a1,
    Vector2 a2,
    Vector2 b1,
    Vector2 b2,
  ) {
    double cross(Vector2 p, Vector2 q, Vector2 r) =>
        (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);

    final d1 = cross(a1, a2, b1);
    final d2 = cross(a1, a2, b2);
    final d3 = cross(b1, b2, a1);
    final d4 = cross(b1, b2, a2);
    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }
    return false;
  }

  static bool hasSelfIntersection(List<Vector2> verts) {
    final n = verts.length;
    if (n < 4) return false;
    for (var i = 0; i < n; i++) {
      final a1 = verts[i];
      final a2 = verts[(i + 1) % n];
      for (var j = i + 2; j < n; j++) {
        if (i == 0 && j == n - 1) continue;
        final b1 = verts[j];
        final b2 = verts[(j + 1) % n];
        if (segmentsIntersect(a1, a2, b1, b2)) return true;
      }
    }
    return false;
  }

  static List<Vector2> transformLocalVertices(
    List<Vector2> verticesLocal,
    Vector2 center,
    double angleRad,
    double scale,
  ) {
    final cosA = cos(angleRad);
    final sinA = sin(angleRad);
    return [
      for (final v in verticesLocal)
        Vector2(
          center.x + (v.x * cosA - v.y * sinA) * scale,
          center.y + (v.x * sinA + v.y * cosA) * scale,
        ),
    ];
  }

  static double maxRadiusFromOrigin(List<Vector2> verts) {
    var maxR = 0.0;
    for (final v in verts) {
      final r = v.length;
      if (r > maxR) maxR = r;
    }
    return maxR;
  }
}
