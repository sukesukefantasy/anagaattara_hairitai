import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../main.dart';
import '../../../game/world_scale.dart';
import '../../common/hitboxes/interact_hitbox.dart';

class Bed extends SpriteComponent with HasGameReference<MyGame> {
  final double depthMeters;

  Bed({
    required super.position,
    required super.size,
    this.depthMeters = WorldScale.buildingDepthMeters,
  }) {
    anchor = Anchor.bottomCenter;
    priority = WorldScale.renderPriorityForDepth(depthMeters);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 仮のスプライト（CITY_MEGA.pngから適当な家具っぽいものを流用）
    // TODO: 画像挿入 (ベッド)
    sprite = await Sprite.load(
      'CITY_MEGA.png',
      srcPosition: Vector2(582, 79),
      srcSize: Vector2(36, 17),
    );

    // 見た目を分かりやすくするために色を付ける
    // TODO: 正式な画像が挿入されたら削除
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.blue.withOpacity(0.3),
      priority: -1,
    ));

    add(InteractHitbox(
      position: Vector2.zero(),
      size: size,
      onInteract: _onSleep,
      icon: Icons.bed,
    ));
  }

  void _onSleep() {
    game.windowManager.showDialog(
      ["「ふかふかのベッドです。朝まで休みますか？」", "（意志力が全回復し、超回復が発生する場合があります）"],
      options: ["休む", "やめる"],
      onSelect: (index) {
        if (index == 0) {
          _performSleep();
        }
      },
    );
  }

  void _performSleep() async {
    final state = game.gameRuntimeState;
    
    // 暗転演出（簡易版）
    game.windowManager.showDialog(["「……深い眠りについた。」"]);
    await Future.delayed(const Duration(seconds: 1));
    
    // 時間を進める
    game.timeService.skipToMorning();
    
    // 超回復と全回復
    state.superRecovery();
    
    game.windowManager.showDialog(["「……目が覚めた。体が軽い気がする。」"]);
  }
}
