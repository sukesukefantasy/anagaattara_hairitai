import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import '../../../main.dart';
import '../../item/item.dart';
import '../../../UI/window_manager.dart';
import '../../../UI/windows/message_window.dart';

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
    add(RectangleHitbox(collisionType: CollisionType.passive, isSolid: true));
  }

  void onHit() {
    hitCount++;
    
    // ヒット時の演出（少し揺れるなど）
    add(MoveEffect.by(Vector2(2, 0), EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 2)));

    final state = game.gameRuntimeState;
    if (state.currentOutdoorSceneId == 'outdoor_3') {
      // 累計ヒット数のカウント
      state.hitCount++; // ここでは既存のhitCountを流用するか、新しく定義する
      // TODO: 専用の家具ヒットカウントをGameRuntimeStateに追加すべきか？
      // 一旦 scrappedObjectCount を流用
      state.scrappedObjectCount++;
      
      if (state.scrappedObjectCount == 13) {
        _triggerAllClear();
      }
    }

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

  void _triggerAllClear() {
    game.windowManager.showDialog(
      ["「……効率化パッチを適用。遺品整理を全自動化します。」"],
      onFinish: () {
        final furniture = game.world.children.whereType<BreakableFurniture>().toList();
        for (final f in furniture) {
          f._break();
        }
      },
    );
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Item && other.physicsBehavior.velocity.length > 50) {
      onHit();
    }
  }
}
