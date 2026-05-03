import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
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
    this.mass = 1.0, // デフォルトの質量
  });

  double get speed;
  double get attackStress;
  final double mass;

  // ノックバック用の速度
  final Vector2 _knockbackVelocity = Vector2.zero();

  // ターゲットマーカー用のコンポーネント
  CircleComponent? _targetMarker;

  /// ノックバックを適用する
  void applyKnockback(Vector2 impulse) {
    _knockbackVelocity.add(impulse / mass);
  }

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

    // ノックバックの適用
    if (!_knockbackVelocity.isZero()) {
      position += _knockbackVelocity * dt;
      // 摩擦による減衰
      _knockbackVelocity.multiply(Vector2.all(max(0, 1 - 5 * dt)));
      if (_knockbackVelocity.length < 5) {
        _knockbackVelocity.setZero();
      }
    }

    // Stage 2 でプレイヤーが近くにいる場合にマーカーを表示
    if (game.gameRuntimeState.currentOutdoorSceneId == 'outdoor_2') {
      final player = game.player;
      if (!player.isHiding) {
        final distance = (player.absolutePosition - absolutePosition).length;
        showTargetMarker(distance < 150);
      } else {
        showTargetMarker(false);
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
          game.missionManager.onAction(GameRuntimeState.routeViolence); // ルート進行
        }
        
        // アイテムの速度と質量に応じたノックバックを適用
        final impulse = item.physicsBehavior.velocity.clone()..multiply(Vector2.all(item.physicsBehavior.mass * 0.5));
        applyKnockback(impulse);

        // 当たった時の演出（赤く光るなど）
        _showHitEffect();
      }
    }
  }

  void hitByMelee(Vector2 impulse) {
    // 近接攻撃を受けた時の処理
    applyKnockback(impulse);
    _showHitEffect();
  }

  void dieAndDropItem() {
    // 即死 + アイテムドロップ
    _showHitEffect();
    
    // アイテムを生成（とりあえず通貨かランダムな宝石）
    final random = Random();
    final itemNames = ['通貨', 'クオーツ', 'エメラルド'];
    final dropItemName = itemNames[random.nextInt(itemNames.length)];
    
    final dropItem = ItemFactory.createItemByName(dropItemName, absolutePosition.clone());
    if (dropItem != null) {
      game.world.add(dropItem);
      dropItem.physicsBehavior.setEnabled(true);
      dropItem.physicsBehavior.velocity = Vector2(0, -100);
    }
    
    // 敵を消去
    removeFromParent();
    
    // Violenceスコアを加算
    game.missionManager.onAction(GameRuntimeState.routeViolence, 2.0);
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