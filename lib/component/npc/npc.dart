import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../main.dart';
import '../common/hitboxes/interact_hitbox.dart';
import '../../../system/storage/game_runtime_state.dart';

class Npc extends SpriteComponent with HasGameReference<MyGame> {
  final String name;
  final List<String> talkMessages;
  final String giftResponse;
  final String uniqueId; // 永続化用のID
  bool isSatisfied = false;

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
    }

    // 仮のスプライト（歩行エネミーのフレームなどを流用）
    sprite = await Sprite.load(
      'CITY_MEGA.png',
      srcPosition: Vector2(102, 162), // 適当なNPCっぽい位置
      srcSize: Vector2(21, 30),
    );

    // インタラクト用のヒットボックスを追加
    add(InteractHitbox(
      position: Vector2(0, 0),
      size: size,
      onInteract: _onTalk,
      icon: Icons.chat,
    ));
  }

  void _onTalk() {
    final state = game.gameRuntimeState;
    
    // ステージ4の特殊処理
    if (state.currentOutdoorSceneId == 'outdoor_4') {
      if (isSatisfied) {
        game.windowManager.showDialog(["[$name]", "「石ころのおかげで助かったよ、ありがとう。」"]);
        return;
      }

      final hasStone = game.player.itemBag.getItemCount('石') > 0;
      
      if (hasStone) {
        game.windowManager.showDialog(
          ["[$name]", "「おや、君。もしかして『石ころ』を持っていないかい？」", "「このあたりでは貴重な資源なんだ。1つ分けてくれないか？」"],
          options: ["あげる", "あげない"],
          onSelect: (index) {
            if (index == 0) {
              _onGiveStone();
            }
          }
        );
      } else {
        game.windowManager.showDialog(["[$name]", "「この世界は荒廃してしまった……。『石ころ』一つ見つからないよ。」"]);
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
          game.routeManager.onAction(GameRuntimeState.routeEmpathy);
        }
      },
    );
  }

  void _onGiveStone() {
    final state = game.gameRuntimeState;
    game.player.itemBag.removeItem('石');
    isSatisfied = true;
    state.satisfiedNpcIds.add(uniqueId);
    
    // ルートマネージャーを通じてアクションを通知（giftCountが増加し、必要数に達すればルート確定）
    game.routeManager.onAction(GameRuntimeState.routeEmpathy);
    
    game.windowManager.showDialog(
      ["[$name]", "「おお、ありがとう！ これで少しはマシな生活ができそうだ。」"],
    );
  }
}
