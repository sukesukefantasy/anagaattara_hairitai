import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flame/sprite.dart';
import '../../main.dart';
import '../player.dart';

abstract class EnemyBase extends SpriteAnimationComponent
    with CollisionCallbacks, HasGameReference<MyGame> {
  final Random random = Random();
  late double direction; // 進行方向: 1.0 (右) or -1.0 (左)

  EnemyBase({
    required super.position,
    required super.size,
    this.direction = -1.0, // デフォルトは左向き
    super.priority = 49,
  });

  double get speed;
  double get attackStress;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 進行方向に応じて画像を反転させる
    scale.x = direction == 1.0 ? -1.0 : 1.0;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      // 衝突処理はPlayerクラスで行うため、ここでは何もしない
    }
  }
} 