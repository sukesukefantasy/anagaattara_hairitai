import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import '../../../main.dart';
import '../../common/collision/collision_family.dart';
import '../../common/collision/family_rectangle_hitbox.dart';
import '../../item/item.dart';

class BreakableFurniture extends SpriteComponent
    with CollisionCallbacks, HasGameReference<MyGame> {
  final String itemName;
  int hitCount = 0;
  static const int maxHits = 3;

  BreakableFurniture({
    required this.itemName,
    required super.position,
    required super.size,
    required Sprite sprite,
  }) : super(sprite: sprite) {
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      FamilyRectangleHitbox(
        collisionFamily: CollisionFamily.prop,
        size: size,
        collisionType: CollisionType.passive,
        isSolid: true,
      ),
    );
    add(
      FamilyRectangleHitbox(
        collisionFamily: CollisionFamily.propItemStrike,
        size: size,
        collisionType: CollisionType.active,
        isSolid: false,
      ),
    );
  }

  void onHit() {
    hitCount++;
    
    // ヒット時の演出（少し揺れるなど）
    add(MoveEffect.by(Vector2(2, 0), EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 2)));

    if (hitCount >= maxHits) {
      _break();
    }
  }

  void _break() {
    final item = ItemFactory.createItemByName(itemName, position.clone());
    if (item != null) {
      game.world.add(item);
    }
    removeFromParent();
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Item && other.physicsBehavior.velocity.length > 50) {
      onHit();
    }
  }
}
