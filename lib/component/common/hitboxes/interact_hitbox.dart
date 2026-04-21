import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../player.dart';
import '../../../UI/game_ui.dart';

/// プレイヤーが接近した際にインタラクト（ボタン操作）を可能にするための共通ヒットボックス。
/// 
/// ドア、レジ、NPCなど、インタラクト可能なすべてのオブジェクトに使用できます。
class InteractHitbox extends PositionComponent with CollisionCallbacks {
  /// ボタンが押された際の処理
  final VoidCallback? onInteract;
  
  /// プレイヤーが範囲に入った際の追加処理（ドアのアニメーションなど）
  final VoidCallback? onPlayerEnter;
  
  /// プレイヤーが範囲から出た際の追加処理
  final VoidCallback? onPlayerLeave;
  
  /// 表示するアイコン
  final IconData? icon;

  late final RectangleHitbox _hitbox;

  InteractHitbox({
    required Vector2 position,
    required Vector2 size,
    this.onInteract,
    this.onPlayerEnter,
    this.onPlayerLeave,
    this.icon,
    Anchor? anchor,
  }) : super(position: position, size: size, anchor: anchor ?? Anchor.topLeft);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _hitbox = RectangleHitbox(
      collisionType: CollisionType.passive,
    );
    add(_hitbox);
  }

  set collisionType(CollisionType type) {
    _hitbox.collisionType = type;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      if (onInteract != null) {
        GameUI.setInteractAction(onInteract!, icon);
      }
      onPlayerEnter?.call();
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is Player) {
      if (onInteract != null) {
        // 現在設定されているアクションがこのHitboxのものかチェックしたいが、
        // 簡易化のため一旦そのまま null に設定する。
        // もし複数のHitboxが重なっている場合は、GameUI側で管理するのが望ましい。
        GameUI.setInteractAction(null, null);
      }
      onPlayerLeave?.call();
    }
  }
}
