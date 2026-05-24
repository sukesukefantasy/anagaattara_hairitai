import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'light_component.dart';
import 'light_emitter_spec.dart';
import 'light_profile.dart';
import 'light_source_entry.dart';

/// 光を発するオブジェクト（ランタン・建物ライト等）。
abstract interface class LightEmitter {
  Vector2 get worldCenter;
  LightProfile get profile;
  Color get color;

  /// 画面 px 半径への追加スケール（通常 1.0）。
  double get radiusScale;

  /// true のとき収集時に [LightingWorld.lanternRadiusPulseScale] を掛ける。
  bool get usesGlobalRadiusPulse;

  /// relight 暖色 plus の強さ。
  double get warmTintStrength;

  bool get isActive;
}

/// [LightSourceEntry] 用アダプタ。
final class LightSourceEntryEmitter implements LightEmitter {
  LightSourceEntryEmitter(this.entry);

  final LightSourceEntry entry;

  @override
  Vector2 get worldCenter => entry.worldCenter;

  @override
  LightProfile get profile => entry.profile;

  @override
  Color get color => entry.color;

  @override
  double get radiusScale => entry.radiusScale;

  @override
  bool get usesGlobalRadiusPulse => false;

  @override
  double get warmTintStrength => entry.warmTintStrength;

  @override
  bool get isActive => true;
}

extension LightSourceEntryEmitterX on LightSourceEntry {
  LightEmitter asEmitter() => LightSourceEntryEmitter(this);
}

/// [LightEmitterSpec] から [LightEmitter] を実装する共通 mixin。
mixin ConfiguredLightEmitter on PositionComponent implements LightEmitter {
  LightEmitterSpec get lightEmitterSpec;

  @override
  Color get color => lightEmitterSpec.color;

  @override
  LightProfile get profile => lightEmitterSpec.profile;

  @override
  double get warmTintStrength => lightEmitterSpec.warmTintStrength;

  @override
  bool get usesGlobalRadiusPulse => lightEmitterSpec.usesGlobalRadiusPulse;

  @override
  Vector2 get worldCenter => absoluteCenter;

  @override
  double get radiusScale => 1.0;

  @override
  bool get isActive => isMounted;
}

/// [LightComponent] 用（後方互換）。
mixin LightEmitterComponent on PositionComponent implements LightEmitter {
  Color get lightColor;
  LightProfile get profile;

  @override
  Color get color => lightColor;

  @override
  Vector2 get worldCenter;

  @override
  double get radiusScale => 1.0;

  @override
  bool get usesGlobalRadiusPulse => false;

  @override
  double get warmTintStrength => 0.2;

  @override
  bool get isActive => isMounted;
}

/// [LanternItem] 用（[ConfiguredLightEmitter] のエイリアス用途）。
mixin LanternLightEmitter on PositionComponent implements LightEmitter {
  LightEmitterSpec get lightEmitterSpec;

  @override
  Color get color => lightEmitterSpec.color;

  @override
  LightProfile get profile => lightEmitterSpec.profile;

  @override
  double get warmTintStrength => lightEmitterSpec.warmTintStrength;

  @override
  bool get usesGlobalRadiusPulse => lightEmitterSpec.usesGlobalRadiusPulse;

  @override
  Vector2 get worldCenter => absoluteCenter;

  @override
  double get radiusScale => 1.0;

  @override
  bool get isActive => isMounted;
}

/// 発光体コンポーネント自身の灯（オーバーレイ relight で手前に乗せない）。
const double kSelfLightWorldEpsilon = 2.0;

bool isSelfLightForParticipant(
  PositionComponent participant,
  Vector2 lightWorldCenter,
) {
  if (participant is! LightEmitter) {
    return false;
  }
  final emitter = participant as LightEmitter;
  return emitter.worldCenter.distanceTo(lightWorldCenter) <
      kSelfLightWorldEpsilon;
}

List<LightSourceEntry> lightsExcludingSelfParticipant(
  PositionComponent participant,
  List<LightSourceEntry> lights,
) {
  if (participant is! LightEmitter) {
    return lights;
  }
  return lights
      .where((l) => !isSelfLightForParticipant(participant, l.worldCenter))
      .toList();
}
