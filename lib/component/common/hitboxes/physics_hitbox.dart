import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:anagaattara_hairitai/component/common/physics/physics_behavior.dart';
import 'package:anagaattara_hairitai/component/player.dart';
import 'package:anagaattara_hairitai/component/item/item.dart';
import 'package:anagaattara_hairitai/component/common/ground/ground.dart';
import 'package:anagaattara_hairitai/component/common/underground/underground.dart';
import 'package:anagaattara_hairitai/UI/game_ui.dart';
import 'package:flutter/material.dart';

class PhysicsHitbox extends RectangleHitbox with HasGameReference {
  double restitution; // 跳ね返り係数 (0.0: 跳ね返らない, 1.0: 完全に跳ね返る)
  double friction; // 摩擦係数 (0.0: 摩擦なし, 1.0: 完全に摩擦)
  bool _isColliding = false; // 衝突中かどうかを示すフラグ
  double? _collisionStartTime; // 衝突開始時刻
  static const double _stationaryThreshold = 1.2;
  bool _isStationary = false; // 停止状態かどうかを示すフラグ

  @override
  final PositionComponent parent;

  PhysicsHitbox({
    required this.parent,
    required super.size, // size を引数として追加
    super.collisionType = CollisionType.active, // 物理的な衝突のためにactiveに設定
    this.restitution = 0.3, // デフォルト値
    this.friction = 0.7, // デフォルト値
  }) : super(
         position: Vector2.zero(), // 親コンポーネントからの相対位置を0に設定
         anchor: Anchor.topLeft,
         angle: parent.angle,
         priority: parent.priority,
       );

  @override
  void update(double dt) {
    super.update(dt);

    if (_isColliding) {
      _collisionStartTime = _collisionStartTime ?? game.currentTime();

      if (parent is HasPhysicsBehavior) {
        final HasPhysicsBehavior physicsParent = parent as HasPhysicsBehavior;
        final physicsBehavior = physicsParent.physicsBehavior;
        if (physicsBehavior != null) {
          // velocity.xとvelocity.yが 0.2以下、且つ onCollision状態が1.5秒続いている
          if (physicsBehavior.velocity.x.abs() < 0.2 &&
              physicsBehavior.velocity.y.abs() < 0.2 &&
              game.currentTime() - _collisionStartTime! >=
                  _stationaryThreshold &&
              !_isStationary) {
            physicsBehavior.setVelocity(Vector2.zero()); // 速度をゼロにする
            physicsBehavior.setEnabled(false); // 物理挙動を無効にする
            _isStationary = true; // 停止状態に設定
          }
        }
      }
    } else {
      _collisionStartTime = null; // 衝突が終了したらタイマーをリセット
      _isStationary = false; // 停止状態をリセット
    }
  }

  void setRestitution(double value) {
    restitution = value.clamp(0.0, 1.0);
  }

  void setFriction(double value) {
    friction = value.clamp(0.0, 1.0);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, ShapeHitbox other) {
    super.onCollisionStart(intersectionPoints, other);
    _isColliding = true;
    _collisionStartTime = game.currentTime(); // 衝突開始時にタイマーをリセット

    // If a Player collides with this hitbox, and its parent is an Item, collect the item.
    if (other.parent is Player && parent is Item) {
      final Player player = other.parent as Player;
      final Item item = parent as Item;

      if (!item.isCollected) {
        item.collectItemByPlayer(player);
      } else {
        GameUI.setInteractAction(() {
          // 拾える状態にしてから収集する
          item.isCollected = false;
          // TODO: あとでアイテムに応じてアクションを設定する必要あり
          item.collectItemByPlayer(player);
          GameUI.setInteractAction(null, null);
        }, Icons.backpack_outlined);
      }
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, ShapeHitbox other) {
    super.onCollision(intersectionPoints, other); // 必ずsuperを呼び出す

    // If parent doesn't have PhysicsBehavior or its physics are disabled, skip active collision response
    if (parent is! HasPhysicsBehavior) return;
    final HasPhysicsBehavior physicsParent = parent as HasPhysicsBehavior;
    final physicsBehavior = physicsParent.physicsBehavior;

    if (physicsBehavior == null || !physicsBehavior.isEnabled) {
      return;
    }

    // GroundまたはUnderGroundのヒットボックスとの衝突の場合
    if (other.parent is Ground || other.parent is UnderGround) {
      if (_isStationary) {
        return;
      }
      if (physicsBehavior.velocity.y > 0) {
        // Falling downwards
        // Calculate overlap
        final itemBottom =
            parent.absolutePosition.y +
            parent.size.y /
                2; // Item has Anchor.center, so absolutePosition is center.
        final groundTop =
            other
                .absolutePosition
                .y; // RectangleHitbox by default has Anchor.topLeft, so absolutePosition is its top-left.
        final overlap = itemBottom - groundTop;

        if (overlap > 0) {
          // If there is actual penetration
          parent.position.y -= overlap; // Move item up out of penetration
        }

        // Apply restitution (bounce) only on the vertical component
        physicsBehavior.velocity.y = -physicsBehavior.velocity.y * restitution;

        // Apply friction on the horizontal component
        physicsBehavior.velocity.x *=
            (1 - friction); // Scale down horizontal velocity by friction

        // If vertical velocity is very small after bounce, zero it out to prevent jittering
        if (physicsBehavior.velocity.y.abs() < 5) {
          // A small threshold
          physicsBehavior.velocity.y = 0;
        }
      }
    } else if (parent is Item && other.parent is Item) {
      // アイテム同士の衝突は無視
      return;
    } else {
      // Generic collision response for other objects
      final collisionNormal =
          (intersectionPoints.first - parent.position).normalized();
      physicsBehavior.velocity.reflect(collisionNormal); // 反射
      physicsBehavior.velocity *= restitution; // 跳ね返り係数を適用
      physicsBehavior.velocity.x *= (1 - friction); // 横方向の摩擦を適用
    }
  }

  @override
  void onCollisionEnd(ShapeHitbox other) {
    super.onCollisionEnd(other);
    _isColliding = false;
    _collisionStartTime = null; // 衝突が終了したらタイマーをリセット
    _isStationary = false; // 停止状態をリセット

    // 衝突が終了し、物理挙動が停止状態から抜ける可能性があるため有効化を検討
    if (parent is HasPhysicsBehavior) {
      final HasPhysicsBehavior physicsParent = parent as HasPhysicsBehavior;
      final physicsBehavior = physicsParent.physicsBehavior;
      if (physicsBehavior != null && !physicsBehavior.isEnabled) {
        // physicsBehavior.isEnabled = true; // これは自動で行わない。アイテムが拾われた時などに手動で有効にする。
      }
    }
    if (other.parent is Player && parent is Item) {
      GameUI.setInteractAction(null, null);
    }
  }

  bool get isColliding => _isColliding;
}

// PhysicsBehaviorを持つコンポーネントであることを示すためのインターフェース
abstract class HasPhysicsBehavior {
  PhysicsBehavior? get physicsBehavior;
}
