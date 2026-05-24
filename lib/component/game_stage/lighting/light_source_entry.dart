import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'light_profile.dart';

/// シェーダーへ渡す1光源分のデータ。
class LightSourceEntry {
  final Vector2 worldCenter;
  final LightProfile profile;
  final Color color;

  /// 画面 px 半径への追加スケール（ランタン明滅など）。
  final double radiusScale;

  /// relight 暖色 plus の強さ。
  final double warmTintStrength;

  const LightSourceEntry({
    required this.worldCenter,
    required this.profile,
    this.color = const Color.fromARGB(255, 255, 255, 200),
    this.radiusScale = 1.0,
    this.warmTintStrength = 0.2,
  });
}
