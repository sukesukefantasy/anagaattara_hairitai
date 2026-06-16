import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../common/hitboxes/interact_hitbox.dart';
import '../game_stage/lighting/lighting_participant.dart';
import '../game_stage/lighting/lighting_participation.dart';

/// 母星からの支援物資。前ステージでカーゴを射出した場合に出現する。
class Toolbox extends SpriteComponent
    with HasGameReference<MyGame>, LightingParticipant {
  @override
  LightingParticipation get lightingParticipation => LightingParticipation.full;

  Toolbox({required Vector2 position})
      : super(
          position: position,
          size: Vector2(32, 32),
          priority: 45,
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    sprite = await game.loadSprite('toolbox.png');
    // スプライトのサイズに合わせる
    if (sprite != null) {
      size.setFrom(sprite!.srcSize);
    }
    
    add(
      InteractHitbox(
        onInteract: _onInteract,
        size: size + Vector2(20, 20),
        position: Vector2.zero(),
        anchor: Anchor.center,
        icon: Icons.inventory_2_outlined,
      ),
    );
  }

  void _onInteract() {
    final state = game.gameRuntimeState;
    
    // 報酬の付与（ここでは固定だが、将来的に送信資源量で変動させても良い）
    state.accumulateCargo(life: 50, history: 20, inorganic: 50);
    state.currency += 100;
    
    game.windowManager.showDialog([
      '【支援物資】',
      '母星からのコンテナを開けた。',
      '中には予備のパーツと、いくらかの物資が入っている。',
      '「——生き延びろ。それが唯一の命令だ」',
    ]);
    
    state.pendingToolboxReward = false;
    state.saveGame();
    removeFromParent();
  }
}
