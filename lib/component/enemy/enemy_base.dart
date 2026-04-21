import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import '../../main.dart';
import '../player.dart';
import '../../system/storage/game_runtime_state.dart';

import 'package:flutter/material.dart';
import '../item/item.dart';

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

  // ターゲットマーカー用のコンポーネント
  CircleComponent? _targetMarker;

  void showTargetMarker(bool show) {
    if (show) {
      if (_targetMarker == null) {
        _targetMarker = CircleComponent(
          radius: 10,
          anchor: Anchor.center,
          position: Vector2(size.x / 2, -15), // 頭上に表示
          paint: Paint()
            ..color = Colors.red.withOpacity(0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        add(_targetMarker!);
      }
    } else {
      _targetMarker?.removeFromParent();
      _targetMarker = null;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Stage 2 でプレイヤーが近くにいる場合にマーカーを表示
    if (game.gameRuntimeState.currentOutdoorSceneId == 'outdoor_2') {
      final player = game.player;
      if (player != null) {
        final distance = (player.absolutePosition - absolutePosition).length;
        showTargetMarker(distance < 150);
      }
    } else {
      showTargetMarker(false);
    }
  }

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
    } else if (other is Item) {
      final item = other;
      // 投げられたアイテム（物理挙動が有効で速度がある程度あるもの）が当たった場合
      if (item.physicsBehavior.isEnabled && 
          item.physicsBehavior.velocity.length > 10) {
        debugPrint('Enemy hit by item: ${item.name} with velocity: ${item.physicsBehavior.velocity.length}');

        if (game.gameRuntimeState.currentOutdoorSceneId == 'outdoor_2') {
          game.routeManager.onAction(GameRuntimeState.routeViolence); // ルート進行
        }
        
        // 当たった時の演出（赤く光るなど）
        _showHitEffect();
      }
    }
  }

  void hitByMelee() {
    // 近接攻撃を受けた時の処理
    _showHitEffect();
  }

  void _showHitEffect() {
    debugPrint('Showing hit effect on enemy');
    final originalColor = paint.color;
    paint.colorFilter = const ColorFilter.mode(Colors.red, BlendMode.srcATop);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (isMounted) {
        paint.colorFilter = null;
        paint.color = originalColor;
      }
    });
  }
} 