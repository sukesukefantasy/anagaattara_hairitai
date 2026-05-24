import 'dart:math' show cos, sin;
import 'dart:ui' show Offset, Rect;

import 'package:flame/components.dart';

import 'dig_shape_template.dart';
import 'polygon_terrain_math.dart';

/// 地下などの変形可能地形に対する走査クエリ・掘削 API。
abstract class TerrainField {
  /// [worldAabb] が未掘削の岩などで塞がれている場合 true。
  bool isBlocked(Rect worldAabb);

  /// 横移動用の当たり。[moveSign] は移動方向（-1 / 1）。0 のときは [isBlocked]。
  bool isBlockedHorizontal(Rect worldAabb, {int moveSign = 0}) =>
      moveSign == 0 ? isBlocked(worldAabb) : isBlocked(worldAabb);

  /// 円形で掘削（通過可能領域を追加）。
  void carveCircle(Vector2 center, double radius);

  /// 線分に沿ってカプセル状に掘削。
  void carveCapsule(Vector2 a, Vector2 b, double radius);
}

extension TerrainFieldPassable on TerrainField {
  /// ワールド座標が通行可能か（岩で塞がれていない）。
  bool isPassable(Vector2 worldPoint) => !isBlocked(
        Rect.fromCenter(center: Offset(worldPoint.x, worldPoint.y), width: 2, height: 2),
      );
}

enum CarveStampKind { circle, polygon }

/// セーブ・描画用の掘削スタンプ。
class CarveStamp {
  final CarveStampKind kind;
  final double x;
  final double y;
  final double radius;
  final double angle;
  final double scale;
  final List<Vector2> verticesLocal;

  const CarveStamp.circle({
    required this.x,
    required this.y,
    required this.radius,
  })  : kind = CarveStampKind.circle,
        angle = 0,
        scale = 1,
        verticesLocal = const [];

  const CarveStamp.polygon({
    required this.x,
    required this.y,
    required this.angle,
    required this.scale,
    required this.verticesLocal,
  })  : kind = CarveStampKind.polygon,
        radius = 0;

  factory CarveStamp.fromJson(Map<String, dynamic> json) {
    final kindStr = json['k'] as String?;
    if (kindStr == 'poly') {
      final raw = json['v'] as List<dynamic>? ?? [];
      final verts = raw
          .map(
            (e) => Vector2(
              (e[0] as num).toDouble(),
              (e[1] as num).toDouble(),
            ),
          )
          .toList();
      return CarveStamp.polygon(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        angle: (json['a'] as num?)?.toDouble() ?? 0,
        scale: (json['s'] as num?)?.toDouble() ?? 1,
        verticesLocal: verts,
      );
    }
    return CarveStamp.circle(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      radius: (json['r'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    if (kind == CarveStampKind.polygon) {
      return {
        'k': 'poly',
        'x': x,
        'y': y,
        'a': angle,
        's': scale,
        'v': verticesLocal.map((v) => [v.x, v.y]).toList(),
      };
    }
    return {'x': x, 'y': y, 'r': radius};
  }

  Vector2 get center => Vector2(x, y);

  List<Vector2> worldVertices() {
    if (kind == CarveStampKind.circle) {
      return _circlePolygonVertices();
    }
    return PolygonTerrainMath.transformLocalVertices(
      verticesLocal,
      center,
      angle,
      scale,
    );
  }

  List<Vector2> _circlePolygonVertices() {
    const segments = 12;
    final verts = <Vector2>[];
    for (var i = 0; i < segments; i++) {
      final a = 2 * 3.141592653589793 * i / segments;
      verts.add(
        Vector2(x + cos(a) * radius, y + sin(a) * radius),
      );
    }
    return verts;
  }

  Rect get bounds {
    if (kind == CarveStampKind.circle) {
      return Rect.fromCircle(center: Offset(x, y), radius: radius);
    }
    final box = PolygonTerrainMath.boundingBox(worldVertices());
    return box;
  }

  /// テンプレートからポリゴンスタンプを生成。
  factory CarveStamp.fromTemplatePlacement({
    required DigShapeTemplate template,
    required Vector2 center,
    required double angleRad,
    required double passageRadius,
  }) {
    final scale = template.scaleToPassageRadius(passageRadius);
    return CarveStamp.polygon(
      x: center.x,
      y: center.y,
      angle: angleRad,
      scale: scale,
      verticesLocal: List<Vector2>.from(template.verticesLocal),
    );
  }
}
