import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import '../../../main.dart';
import '../../../system/storage/game_runtime_state.dart';
import '../../item/item.dart';
import '../../effect/residue_effect.dart';
import '../../effect/residue_pickup.dart';
import '../../common/physics/physics_step_obstacle.dart';
import '../../common/collision/collision_family.dart';

enum DestructibleType {
  glass,    // 1回で壊れる
  street,   // 3回で壊れる (ポール、自販機など)
  wall,     // 50回で壊れる
}

class DestructibleObject extends SpriteComponent
    with
        HasGameReference<MyGame>,
        CollisionCallbacks,
        PhysicsStepObstacleMixin,
        HasCollisionFamily {
  @override
  CollisionFamily get collisionFamily => CollisionFamily.prop;

  final DestructibleType type;
  final String itemName; // 破壊時にドロップするアイテム名
  final String uniqueId; // 永続化用のID
  int health;
  bool isBroken = false;

  DestructibleObject({
    required this.type,
    required this.itemName,
    required this.uniqueId,
    required super.position,
    required super.size,
    required Sprite sprite,
  }) : health = _getInitialHealth(type),
       super(sprite: sprite) {
    anchor = Anchor.bottomCenter;
  }

  static int _getInitialHealth(DestructibleType type) {
    switch (type) {
      case DestructibleType.glass: return 1;
      case DestructibleType.street: return 3;
      case DestructibleType.wall: return 50;
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.passive, isSolid: true));
    
    // 永続化データの適用
    final savedHealth = game.gameRuntimeState.destructibleHealths[uniqueId];
    if (savedHealth != null) {
      health = savedHealth;
      if (health <= 0) {
        isBroken = true;
        removeFromParent();
      }
    }
  }

  void onHit() {
    if (isBroken) return;
    
    health--;
    game.gameRuntimeState.destructibleHealths[uniqueId] = health;
    
    // ヒット演出（揺れる）
    add(MoveEffect.by(Vector2(2, 0), EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 2)));
    
    // 無機資源の残滓（黒破片）を少量漏出させる
    ResidueEffect.spawnInorganic(game, ResiduePickup.worldEmitOrigin(this), count: 2);

    if (health <= 0) {
      _break();
    }
  }

  void _break() {
    if (isBroken) return;
    isBroken = true;

    if (uniqueId == 'outdoor_true_finale_barrier') {
      final st = game.gameRuntimeState;
      st.trueSequencePhase = 4;
      st.registerMacroRouteCompleted(GameRuntimeState.macroRouteTrue);
      st.saveGame();
      game.windowManager.showDialog([
        '〔True〕',
        '父の断片と少女の回路が、同じ波形に重なった気がする。',
        '星の核が、設計の限界をさらした。',
      ]);
      removeFromParent();
      return;
    }

    // 破壊ポイントを加算
    if (type == DestructibleType.wall) {
      game.gameRuntimeState.destructionPointsInStage += 50;
      ResiduePickup.emitCargo(
        game,
        ResiduePickup.worldEmitOrigin(this),
        inorganic: 3,
      );
    } else {
      game.gameRuntimeState.destructionPointsInStage += 5;
      ResiduePickup.emitCargo(
        game,
        ResiduePickup.worldEmitOrigin(this),
        inorganic: 1,
      );
    }

    // アイテムをドロップ
    final item = ItemFactory.createItemByName(itemName, position.clone() - Vector2(0, size.y / 2));
    if (item != null) {
      game.world.add(item);
    }
    
    removeFromParent();
  }
}
