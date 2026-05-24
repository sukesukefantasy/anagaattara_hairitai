import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:anagaattara_hairitai/component/common/collision/collision_family.dart';
import 'package:anagaattara_hairitai/component/common/physics/physics_behavior.dart';
import 'package:anagaattara_hairitai/component/player.dart';
import 'package:anagaattara_hairitai/component/item/item.dart';
import 'package:anagaattara_hairitai/UI/game_ui.dart';
import 'package:flutter/material.dart';
import 'package:anagaattara_hairitai/component/common/hitboxes/interact_hitbox.dart';

class PhysicsHitbox extends RectangleHitbox
    with HasGameReference
    implements HitboxCollisionTag {
  /// 積み上げ静止判定用の微小速度閾値（px/s）。
  static const double itemMicroVelocityThreshold = 8.0;

  double restitution; // 跳ね返り係数 (0.0: 跳ね返らない, 1.0: 完全に跳ね返る)
  double friction; // 摩擦係数 (0.0: 摩擦なし, 1.0: 完全に摩擦)
  bool _isColliding = false; // 衝突中かどうかを示すフラグ
  int _collisionCount = 0;
  int _supportFromBelowCount = 0; // 真下のアイテムによる積み上げ支持
  double? _collisionStartTime; // 衝突開始時刻

  @override
  final PositionComponent parent;

  @override
  final CollisionFamily collisionFamily;

  PhysicsHitbox({
    required this.parent,
    required super.size, // size を引数として追加
    this.collisionFamily = CollisionFamily.item,
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
    } else {
      _collisionStartTime = null;
    }
  }

  void setRestitution(double value) {
    restitution = value.clamp(0.0, 1.0);
  }

  void setFriction(double value) {
    friction = value.clamp(0.0, 1.0);
  }

  bool _isOtherItem(ShapeHitbox other) {
    final p = other.parent;
    return p is Item && p != parent;
  }

  /// 相手の中心が自分より下（画面座標で y が大きい）なら、下からの支持とみなす。
  bool _isSupportFromBelow(Item other) {
    return other.absoluteCenter.y > parent.absoluteCenter.y + 1.0;
  }

  void _refreshParentStackSupport() {
    if (parent is Item) {
      (parent as Item).refreshStackSupportState();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, ShapeHitbox other) {
    super.onCollisionStart(intersectionPoints, other);
    _collisionCount++;
    _isColliding = true;
    if (_isOtherItem(other) && _isSupportFromBelow(other.parent! as Item)) {
      _supportFromBelowCount++;
    }
    _collisionStartTime = game.currentTime();

    // If a Player collides with this hitbox, and its parent is an Item, collect the item.
    if (parent is Item && other.parent is Player) {
      final Player player = other.parent as Player;
      final Item item = parent as Item;

      if (!item.isCollected) {
        item.collectItemByPlayer(player);
      } else {
        GameUI.setInteractAction(() {
          // 拾える状態にしてから収集する
          item.isCollected = false;
          // TODO: あとで配置アイテムのためにアクションを設定する必要あり
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

    // アイテム同士の衝突
    if (other.parent is Item) {
      // 衝突点の中心を計算
      final contactCenter =
          intersectionPoints.reduce((a, b) => a + b) /
          intersectionPoints.length.toDouble();
      final itemCenter = parent.absoluteCenter;
      final diff = contactCenter - itemCenter;

      // 横方向の衝突か縦方向の衝突かを判定
      if ((diff.x.abs() / parent.size.x) > (diff.y.abs() / parent.size.y)) {
        // 横方向の衝突: アイテム同士の場合はrestitutionを適用する
        physicsBehavior.velocity.x = -physicsBehavior.velocity.x * restitution;

        // めり込み防止
        final overlapX = (parent.size.x / 2) - diff.x.abs();
        if (overlapX > 0) {
          parent.position.x -= diff.x.sign * overlapX;
        }
      } else {
        // 縦方向の衝突 (アイテム同士)
        if (diff.y > 0 && physicsBehavior.velocity.y > 0) {
          // 下方向への衝突
          final overlap = (parent.size.y / 2) - diff.y.abs();
          if (overlap > 0) {
            parent.position.y -= overlap;
          }
          physicsBehavior.velocity.y =
              -physicsBehavior.velocity.y * restitution;
          physicsBehavior.velocity.x *= (1 - friction);
          if (physicsBehavior.velocity.y.abs() < 5) {
            physicsBehavior.velocity.y = 0;
          }
        } else if (diff.y < 0 && physicsBehavior.velocity.y < 0) {
          // 上方向への衝突
          physicsBehavior.velocity.y =
              -physicsBehavior.velocity.y * restitution;
          final overlap = (parent.size.y / 2) - diff.y.abs();
          if (overlap > 0) {
            parent.position.y += overlap;
          }
        }
      }
    } else if (other.parent is Player) {
      if (parent is Item) {
        return;
      }
    } else if (other.parent is InteractHitbox) {
      if (parent is Item) {
        return;
      }
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
    final lostSupportFromBelow =
        _isOtherItem(other) && _isSupportFromBelow(other.parent! as Item);
    if (lostSupportFromBelow) {
      _supportFromBelowCount = (_supportFromBelowCount - 1).clamp(0, 999);
      _refreshParentStackSupport();
    }
    _collisionCount = (_collisionCount - 1).clamp(0, 999);
    _isColliding = _collisionCount > 0;
    if (!_isColliding) {
      _collisionStartTime = null;
    }

    if (other.parent is Player && parent is Item) {
      GameUI.setInteractAction(null, null);
    }
  }

  @override
  bool get isColliding => _isColliding;

  /// 真下のアイテムに支えられている（プレイヤー接触・横接触のみでは false）。
  bool get hasSupportFromBelow => _supportFromBelowCount > 0;
}

// PhysicsBehaviorを持つコンポーネントであることを示すためのインターフェース
abstract class HasPhysicsBehavior {
  PhysicsBehavior? get physicsBehavior;
}
