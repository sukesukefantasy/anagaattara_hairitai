import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../../main.dart';
import '../common/hitboxes/interact_hitbox.dart';
import '../../../system/storage/game_runtime_state.dart';
import '../item/item.dart';

class Npc extends SpriteComponent with HasGameReference<MyGame> {
  final String name;
  final List<String> talkMessages;
  final String giftResponse;
  final String uniqueId; // 永続化用のID
  bool isSatisfied = false;

  late final SpriteComponent _speechBubble;
  bool _hasMission = true; // とりあえず全てのNPCがミッションを持っていると仮定

  Npc({
    required this.name,
    required this.talkMessages,
    required this.giftResponse,
    required this.uniqueId,
    required super.position,
    required super.size,
  }) {
    anchor = Anchor.bottomCenter;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 永続化データの適用
    if (game.gameRuntimeState.satisfiedNpcIds.contains(uniqueId)) {
      isSatisfied = true;
      _hasMission = false;
    }

    // 仮のスプライト（歩行エネミーのフレームなどを流用）
    sprite = await Sprite.load(
      'CITY_MEGA.png',
      srcPosition: Vector2(102, 162), // 適当なNPCっぽい位置
      srcSize: Vector2(21, 30),
    );

    // 吹き出しアイコン（簡易版としてSpriteで実装、必要に応じて画像を用意）
    _speechBubble = SpriteComponent(
      sprite: await Sprite.load('CITY_MEGA.png',
          srcPosition: Vector2(1381, 403), srcSize: Vector2(16, 16)), // 白い吹き出し
      position: Vector2(0, -size.y + 12),
      size: Vector2(16, 16),
      anchor: Anchor.bottomCenter,
      priority: 10, // 親（NPC）より前面に
    );
    add(_speechBubble);

    // インタラクト用のヒットボックスを追加
    add(InteractHitbox(
      position: Vector2(0, 0),
      size: size,
      onInteract: _onTalk,
      icon: Icons.chat,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 満足したNPCやミッションがない場合は吹き出しを消す
    _speechBubble.opacity = _hasMission ? 1.0 : 0.0;
    
    // 吹き出しをふわふわさせる (base: -size.y + 12)
    if (_hasMission) {
      _speechBubble.position.y = -size.y + 12 + sin(game.timeService.totalPlayTime * 3) * 2;
    }
  }

  void _onTalk() {
    final state = game.gameRuntimeState;
    
    // ステージ4の特殊処理
    if (state.currentOutdoorSceneId == 'outdoor_4') {
      if (isSatisfied) {
        game.windowManager.showDialog(["[$name]", "「希少な鉱石のおかげで助かったよ、ありがとう。」"]);
        return;
      }

      final hasStone = game.player.itemBag.getItemCount('希少な鉱石') > 0 || game.player.itemBag.getItemCount('石') > 0;
      
      if (hasStone) {
        game.windowManager.showDialog(
          ["[$name]", "「おや、君。もしかして『希少な鉱石』を持っていないかい？」", "「このあたりでは貴重な資源なんだ。1つ分けてくれないか？」"],
          options: ["あげる", "あげない"],
          onSelect: (index) {
            if (index == 0) {
              _onGiveStone();
            }
          }
        );
      } else {
        game.windowManager.showDialog(["[$name]", "「この世界は荒廃してしまった……。『希少な鉱石』一つ見つからないよ。」"]);
      }
      return;
    }

    // 通常の会話
    game.windowManager.showDialog(
      [
        "[$name]",
        ...talkMessages,
      ],
      onFinish: () {
        // 汎用的な共感ルートの進行（以前の仕様）
        if (state.currentOutdoorSceneId == 'outdoor_4' && !isSatisfied) {
          game.missionManager.onAction(GameRuntimeState.routeEmpathy);
        }
      },
    );
  }

  void _onGiveStone() {
    final state = game.gameRuntimeState;
    if (game.player.itemBag.getItemCount('希少な鉱石') > 0) {
      game.player.itemBag.removeItem('希少な鉱石');
    } else {
      game.player.itemBag.removeItem('石');
    }
    isSatisfied = true;
    state.satisfiedNpcIds.add(uniqueId);
    
    // ルートマネージャーを通じてアクションを通知（scoreが増加し、必要数に達すればルート確定）
    game.missionManager.onAction(GameRuntimeState.routeEmpathy, 5.0);
    
    game.windowManager.showDialog(
      ["[$name]", "「おお、ありがとう！ これで少しはマシな生活ができそうだ。」"],
    );
  }

  void dieAndDropItem() {
    // 即死 + アイテムドロップ
    final dropItem = ItemFactory.createItemByName('希少な鉱石', absolutePosition.clone());
    if (dropItem != null) {
      game.world.add(dropItem);
      dropItem.physicsBehavior.setEnabled(true);
      dropItem.physicsBehavior.velocity = Vector2(0, -100);
    }
    
    // NPCを消去
    removeFromParent();
    
    // Violenceスコアを大幅に加算（禁忌を犯した）
    game.missionManager.onAction(GameRuntimeState.routeViolence, 10.0);
  }
}
