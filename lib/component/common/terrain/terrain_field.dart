import 'dart:ui' show Offset, Rect;

import 'package:flame/components.dart';

/// 地下などの変形可能地形に対する走査クエリ・掘削 API。
abstract class TerrainField {
  /// [worldAabb] が未掘削の岩などで塞がれている場合 true。
  bool isBlocked(Rect worldAabb);

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

/// セーブ・描画用の掘削スタンプ。
class CarveStamp {
  final double x;
  final double y;
  final double radius;

  const CarveStamp({
    required this.x,
    required this.y,
    required this.radius,
  });

  factory CarveStamp.fromJson(Map<String, dynamic> json) => CarveStamp(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        radius: (json['r'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'r': radius};

  Vector2 get center => Vector2(x, y);
}
