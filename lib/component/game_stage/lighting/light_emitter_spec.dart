import 'package:flutter/material.dart';

import 'light_profile.dart';

/// 光源の見た目・届き方の定義。
///
/// 新しい光を足すときはこの spec を作り、[ConfiguredLightEmitter] を mixin する。
/// 例: ランタン [LanternItem.emitterSpec]、固定灯 [LightComponent.fromSpec]。
class LightEmitterSpec {
  const LightEmitterSpec({
    required this.color,
    required this.profile,
    this.warmTintStrength = 0.2,
    this.usesGlobalRadiusPulse = false,
  });

  final Color color;
  final LightProfile profile;

  /// relight の暖色 plus 加算強度（0..1 前後）。
  final double warmTintStrength;

  /// true のとき [LightingWorld.lanternRadiusPulseScale] を半径に掛ける（ランタン明滅）。
  final bool usesGlobalRadiusPulse;

  /// ランタン相当（オレンジ・中〜大半径・明滅あり）。
  static final lantern = LightEmitterSpec(
    color: const Color.fromARGB(255, 252, 81, 3),
    profile: LightProfile.fromBrightnessLevel(
      300,
      innerRadius: 50,
      midRadius: 200,
      outerRadius: 460,
    ),
    warmTintStrength: 0.2,
    usesGlobalRadiusPulse: true,
  );

  /// 流れ星 burst 用（冷白・大半径・明滅なし）。
  static final shootingStar = LightEmitterSpec(
    color: const Color.fromARGB(255, 253, 254, 255),
    profile: LightProfile.fromBrightnessLevel(
      1300,
      innerRadius: 70,
      midRadius: 210,
      outerRadius: 420,
    ),
    warmTintStrength: 0.05,
  );

  /// 建物・街灯向けの暖白（明滅なし）。
  static LightEmitterSpec warmWhite({
    int brightnessLevel = 600,
    double innerRadius = 120,
    double midRadius = 240,
    double outerRadius = 360,
    Color color = const Color.fromARGB(255, 255, 255, 200),
    double warmTintStrength = 0.15,
  }) {
    return LightEmitterSpec(
      color: color,
      profile: LightProfile.fromBrightnessLevel(
        brightnessLevel,
        innerRadius: innerRadius,
        midRadius: midRadius,
        outerRadius: outerRadius,
      ),
      warmTintStrength: warmTintStrength,
    );
  }
}
