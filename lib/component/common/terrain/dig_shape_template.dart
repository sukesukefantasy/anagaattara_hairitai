import 'dart:math';

import 'package:flame/components.dart';

import 'polygon_terrain_math.dart';

/// プレイヤーが保持する掘削断面の型（正規化頂点）。
class DigShapeTemplate {
  static const int maxVertices = 24;
  static const double minArea = 0.002;

  /// ワールドへ刻むときの回転（固定）。エディタ上の上＝ゲーム内の上（-Y）。
  static const double worldPlacementAngleRad = 0;

  /// プレイヤー定義型の掘削・通行スケール（外接半径・px）。
  /// 既定の円掘り（[circleFallback]）は [PhysicsBodyQueries.passageRadiusForBody] のまま。
  static const double customDigRadiusPx = 35;

  final List<Vector2> verticesLocal;
  final double approximateRadius;

  const DigShapeTemplate({
    required this.verticesLocal,
    required this.approximateRadius,
  });

  /// 通行半径に合わせるスケール係数。
  double scaleToPassageRadius(double passageRadius) {
    if (approximateRadius < 1e-6) return passageRadius;
    return passageRadius / approximateRadius;
  }

  List<Vector2> worldVerticesAt(
    Vector2 center,
    double angleRad,
    double passageRadius,
  ) {
    final scale = scaleToPassageRadius(passageRadius);
    return PolygonTerrainMath.transformLocalVertices(
      verticesLocal,
      center,
      angleRad,
      scale,
    );
  }

  /// 正多角形（外接半径 1・上向き）。4角は辺が水平になる向き。
  factory DigShapeTemplate.regularPolygon(int sides) {
    assert(sides >= 3 && sides <= maxVertices);
    final startAngle = sides == 4 ? -pi / 4 : -pi / 2;
    final verts = <Vector2>[];
    for (var i = 0; i < sides; i++) {
      final angle = startAngle + 2 * pi * i / sides;
      verts.add(Vector2(cos(angle), sin(angle)));
    }
    return DigShapeTemplate(
      verticesLocal: verts,
      approximateRadius: 1.0,
    );
  }

  /// エディタ用ビルトインプリセット。
  static List<DigShapePresetOption> get builtInPresets => [
        DigShapePresetOption(
          '10角',
          () => DigShapeTemplate.regularPolygon(10),
        ),
        DigShapePresetOption(
          '8角',
          () => DigShapeTemplate.regularPolygon(8),
        ),
        DigShapePresetOption(
          '6角',
          () => DigShapeTemplate.regularPolygon(6),
        ),
        DigShapePresetOption(
          '4角',
          () => DigShapeTemplate.regularPolygon(4),
        ),
      ];

  /// 12 分割の円近似（レガシー互換のデフォルト）。
  factory DigShapeTemplate.circleFallback([double radiusHint = 1.0]) {
    const segments = 12;
    final verts = <Vector2>[];
    for (var i = 0; i < segments; i++) {
      final angle = 2 * pi * i / segments;
      verts.add(Vector2(cos(angle), sin(angle)));
    }
    return DigShapeTemplate(
      verticesLocal: verts,
      approximateRadius: 1.0,
    );
  }

  factory DigShapeTemplate.fromJson(Map<String, dynamic> json) {
    final raw = json['v'] as List<dynamic>? ?? [];
    final verts = raw
        .map(
          (e) => Vector2(
            (e[0] as num).toDouble(),
            (e[1] as num).toDouble(),
          ),
        )
        .toList();
    return DigShapeTemplate(
      verticesLocal: verts,
      approximateRadius: (json['ar'] as num?)?.toDouble() ??
          PolygonTerrainMath.maxRadiusFromOrigin(verts),
    );
  }

  Map<String, dynamic> toJson() => {
        'v': verticesLocal.map((v) => [v.x, v.y]).toList(),
        'ar': approximateRadius,
      };

  /// エディタ上のドラッグ点列（0..1 正規化）から型を構築。
  static DigShapeTemplate? fromNormalizedDrawPoints(List<Vector2> points) {
    if (points.length < 3) return null;
    final resampled = _resampleDrawPoints(points);
    if (resampled.length < 3) return null;

    var minX = double.infinity;
    var maxX = -double.infinity;
    var minY = double.infinity;
    var maxY = -double.infinity;
    for (final p in resampled) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    final cx = (minX + maxX) * 0.5;
    final cy = (minY + maxY) * 0.5;
    final halfW = max((maxX - minX) * 0.5, 1e-4);
    final halfH = max((maxY - minY) * 0.5, 1e-4);
    final normScale = max(halfW, halfH);

    final local = resampled
        .map(
          (p) => Vector2((p.x - cx) / normScale, (p.y - cy) / normScale),
        )
        .toList();

    final area = PolygonTerrainMath.signedArea(local).abs();
    if (area < minArea) return null;
    if (PolygonTerrainMath.hasSelfIntersection(local)) return null;

    return DigShapeTemplate(
      verticesLocal: local,
      approximateRadius: PolygonTerrainMath.maxRadiusFromOrigin(local),
    );
  }

  static List<Vector2> _resampleDrawPoints(List<Vector2> points) {
    if (points.length <= maxVertices) return List<Vector2>.from(points);
    final out = <Vector2>[];
    final step = (points.length - 1) / (maxVertices - 1);
    for (var i = 0; i < maxVertices; i++) {
      final idx = (i * step).round().clamp(0, points.length - 1);
      out.add(points[idx]);
    }
    return out;
  }

  String? validate() {
    if (verticesLocal.length < 3) {
      return '頂点が少なすぎます（3点以上必要）';
    }
    if (verticesLocal.length > maxVertices) {
      return '頂点が多すぎます';
    }
    final area = PolygonTerrainMath.signedArea(verticesLocal).abs();
    if (area < minArea) {
      return '面積が小さすぎます';
    }
    if (PolygonTerrainMath.hasSelfIntersection(verticesLocal)) {
      return '線が交差しています。別の形を描いてください';
    }
    return null;
  }
}

/// エディタで選べる定型断面。
class DigShapePresetOption {
  final String label;
  final DigShapeTemplate Function() build;

  const DigShapePresetOption(this.label, this.build);
}
