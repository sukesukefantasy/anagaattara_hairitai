import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import '../../../main.dart';
import '../../item/item.dart';
import '../../../system/storage/game_runtime_state.dart';

enum DestructibleType {
  glass,    // 1回で壊れる
  street,   // 3回で壊れる (ポール、自販機など)
  wall,     // 50回で壊れる
}

class DestructibleObject extends SpriteComponent with HasGameReference<MyGame>, CollisionCallbacks {
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
    
    final state = game.gameRuntimeState;
    
    // outdoor_3 でのヒットカウント
    if (state.currentOutdoorSceneId == 'outdoor_3') {
      state.scrappedObjectCount++;
      if (state.scrappedObjectCount == 10) {
        _showMassCollectDialog();
      }
    }

    if (health <= 0) {
      _break();
    }
  }

  void _break() {
    if (isBroken) return;
    isBroken = true;

    // アイテムをドロップ（Efficiencyステージ以外、または特定条件下）
    final item = ItemFactory.createItemByName(itemName, position.clone());
    if (item != null) {
      game.world.add(item);
    }
    
    removeFromParent();
  }

  void _showMassCollectDialog() {
    game.windowManager.showDialog(
      [
        "「……街の構成データの断片を多数検知。これらを一括回収し、高密度エネルギーに変換しますか？」",
      ],
      options: ["はい", "いいえ"],
      onSelect: (index) {
        // どちらを選んでも「はい」として処理（ユーザーの要望）
        _performMassCollect();
      },
    );
  }

  void _performMassCollect() async {
    final state = game.gameRuntimeState;
    
    // 現在のシーンが屋外か屋内かに関わらず、全ての破壊可能オブジェクトのデータをリセット
    state.destructibleHealths.clear();
    state.scrappedObjectCount = 100; // 十分な数を設定

    // 高密度エネルギーキューブを付与
    final item = ItemFactory.createItemByName('高密度エネルギーキューブ', Vector2.zero());
    if (item != null) {
      game.player.itemBag.addItem(item);
    }

    // ミッション更新（ルート確定）
    game.routeManager.onAction(GameRuntimeState.routeEfficiency);
    
    // 平らなステージ3へ移動（再ロード）
    await game.sceneManager.loadScene('outdoor_3');

    game.windowManager.showDialog(
      [
        "「街の全てのデータを最適化し、平坦化しました。『高密度エネルギーキューブ』を生成。ロケットへの転送準備が完了しました。」",
      ],
    );
  }
}
