import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../main.dart';
import '../../player.dart';
import '../../common/collision/collision_family.dart';
import '../lighting/ambient_lighting_utils.dart';
import '../lighting/lighting_participation.dart';
import '../lighting/lighting_participant.dart';

abstract class Building extends PositionComponent
    with
        HasGameReference<MyGame>,
        CollisionCallbacks,
        HasCollisionFamily,
        LightingParticipant {
  @override
  CollisionFamily get collisionFamily => CollisionFamily.prop;
  final Vector2 initialPosition;
  // 建物の種類を識別するためのプロパティ
  final String type;
  // 建物から出る際のプレイヤーの目標位置

  Building({
    required Vector2 position,
    required this.type,
  })  : initialPosition = position.clone(),
        super(position: position);

  @override
  LightingParticipation get lightingParticipation =>
      LightingParticipation.full;

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      // TODO 当たり判定処理
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is Player) {
      // TODO 当たり判定処理
    }
  }

  void applyAmbientColorFilter(ColorFilter? filter) {
    AmbientLightingUtils.applyColorFilterToSprites(this, filter);
  }
} 