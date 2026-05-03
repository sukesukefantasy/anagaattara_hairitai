import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/foundation.dart';
import '../../../main.dart';
import '../../item/item.dart';
import '../../../system/storage/game_runtime_state.dart';
import '../../../scene/abstract_outdoor_scene.dart';
import 'building.dart';
import 'station.dart';
import 'abandoned_rocket.dart';
import '../../npc/npc.dart';

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
    if (state.currentOutdoorSceneId == 'outdoor_3' && state.activeRouteId == null) {
      state.scrappedObjectCount++;
      // 属性アクションを通知（PIPの点滅とスコア加算）
      game.missionManager.onAction(GameRuntimeState.routeEfficiency, 1.0);
      
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
        // どちらを選んでも「はい」として一旦処理
        _performMassCollect();
      },
    );
  }

  void _performMassCollect() async {
    final state = game.gameRuntimeState;

    // 1. 状態を先に確定させる（最優先。これで直後のloadSceneが「平坦な世界」を作るようになる）
    state.activeRouteId = GameRuntimeState.routeEfficiency;
    state.attributeScores[GameRuntimeState.routeEfficiency] = 100.0;

    // 2. 現在のシーンのデータをリセットし、今の画面からも即座に消去を試みる
    state.destructibleHealths.clear();
    final currentScene = game.sceneManager.currentScene;
    if (currentScene is AbstractOutdoorScene) {
      currentScene.clearWorldObjects();
    }

    // 3. 属性確定処理を走らせる（アイテム付与などのため。既にactiveRouteIdはセット済みなので安全）
    await game.missionManager.onAction(GameRuntimeState.routeEfficiency, 0.0);
    
    // 4. 平らなステージ3へ移動（再ロード）
    final Vector2 currentPos = game.player.position.clone();
    await game.sceneManager.loadScene('outdoor_3', initialPlayerPosition: currentPos);

    // 5. ロードした「後」に、もし建物やオブジェクトが生成されてしまっていたら、直接 removeFromParent() で消す
    // ただし、AbandonedRocket と Station は明示的に残す
    final newScene = game.sceneManager.currentScene;
    if (newScene != null) {
      final targets = newScene.children.where((c) => 
        ((c is Building && c is! Station) || 
         (c is DestructibleObject) || 
         (c is Npc)) && c is! AbandonedRocket
      ).toList();
      
      for (var t in targets) {
        t.removeFromParent();
        debugPrint('Directly removed component: ${t.runtimeType}');
      }
    }

    // 6. ミッション表示を強制更新し、完了状態をUIに反映
    game.missionManager.refreshMissionText('outdoor_3');

    game.windowManager.showDialog(
      [
        "「街の全てのデータを最適化し、平坦化しました。『高出力電源』を生成。ロケットへの転送準備が完了しました。」",
      ],
    );
  }
}
