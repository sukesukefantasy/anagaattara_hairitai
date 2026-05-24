import 'dart:ui' show Rect;

/// 地下に設置した水平床板（platform slab）。
class PlacedFloor {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const PlacedFloor({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory PlacedFloor.fromRect(Rect rect) => PlacedFloor(
        left: rect.left,
        top: rect.top,
        right: rect.right,
        bottom: rect.bottom,
      );

  factory PlacedFloor.fromJson(Map<String, dynamic> json) => PlacedFloor(
        left: (json['l'] as num).toDouble(),
        top: (json['t'] as num).toDouble(),
        right: (json['r'] as num).toDouble(),
        bottom: (json['b'] as num).toDouble(),
      );

  Rect get slabRect => Rect.fromLTRB(left, top, right, bottom);

  /// 歩行面の Y（上面）。
  double get surfaceY => top;

  Map<String, dynamic> toJson() => {
        'l': left,
        't': top,
        'r': right,
        'b': bottom,
      };
}
