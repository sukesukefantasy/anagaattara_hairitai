import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../../main.dart';
import '../player.dart';

abstract class Vehicle extends PositionComponent
    with HasGameReference<MyGame>, CollisionCallbacks {
  final Vector2 initialPosition;

  Vehicle({required Vector2 position})
      : initialPosition = position.clone(),
        super(position: position);

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
} 