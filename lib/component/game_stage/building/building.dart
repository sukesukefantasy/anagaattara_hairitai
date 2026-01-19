import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../../../main.dart';
import '../../player.dart';

abstract class Building extends PositionComponent
    with HasGameReference<MyGame>, CollisionCallbacks {
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