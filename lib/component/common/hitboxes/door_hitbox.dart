import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import '../../player.dart';

class DoorHitbox extends PositionComponent with CollisionCallbacks {
  final VoidCallback onPlayerEnter;
  final VoidCallback onPlayerLeave;

  late final RectangleHitbox _hitbox;

  DoorHitbox({
    required Vector2 position,
    required Vector2 size,
    required this.onPlayerEnter,
    required this.onPlayerLeave,
  }) : super(position: position, size: size);

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
      onPlayerEnter();
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is Player) {
      onPlayerLeave();
    }
  }
} 