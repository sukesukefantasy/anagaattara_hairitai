import 'package:flutter/material.dart';

import '../game_stage/lighting/lantern_strip_light_registry.dart';
import '../game_stage/lighting/light_emitter.dart';
import '../game_stage/lighting/light_emitter_spec.dart';
import '../game_stage/lighting/light_profile.dart';
import '../player.dart';
import 'item.dart';

/// 持ち運び・設置で3層ライトを発するランタン。
class LanternItem extends Item with ConfiguredLightEmitter {
  static const int brightnessLevel = 300;

  /// 新規光源の参考実装。形・色・強さは [LightEmitterSpec] で定義する。
  static final LightEmitterSpec emitterSpec = LightEmitterSpec.lantern;

  @override
  LightEmitterSpec get lightEmitterSpec => LanternItem.emitterSpec;

  static Color get lightColor => emitterSpec.color;

  static LightProfile get lightProfile => emitterSpec.profile;

  static double get defaultWarmTintStrength => emitterSpec.warmTintStrength;

  /// 光源半径の明滅周期（フレーム、1 往復）。
  static const int radiusPulsePeriodFrames = 15;

  /// 半径パルス振幅（1.0 ± この値）。
  static const double radiusPulseAmplitude = 0.01;

  LanternItem({
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
    super.mass,
  }) : super(type: ItemType.placeable);

  @override
  void onRemove() {
    LanternStripLightRegistry.instance.unregister(this);
    super.onRemove();
  }

  @override
  void onUse(Player player) {
    ItemFactory.tryStartPlaceablePlacement(player.game, this);
  }
}
