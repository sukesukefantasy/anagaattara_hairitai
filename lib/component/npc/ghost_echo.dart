import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../../main.dart';
import '../common/hitboxes/interact_hitbox.dart';
import '../../../system/storage/game_runtime_state.dart';

class GhostEcho extends SpriteComponent with HasGameReference<MyGame> {
  final String attribute;
  final Color color;

  late final SpriteComponent _bubble;

  GhostEcho({
    required this.attribute,
    required this.color,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size) {
    anchor = Anchor.bottomCenter;
  }

  @override
  Future<void> onLoad() async {
    // プレイヤーのスプライトシートから静止状態のフレームを切り出す
    sprite = await game.loadSprite(
      'player01_anim.png',
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(50, 50),
    );
    paint.color = color.withOpacity(0.5); // 半透明のシルエットにする

    // 浮遊アイコン
    Vector2 bubblePos = Vector2(1381, 403); // デフォルト白
    switch (attribute) {
      case GameRuntimeState.routeEfficiency: bubblePos = Vector2(1397, 403); break;
      case GameRuntimeState.routeViolence: bubblePos = Vector2(1413, 403); break;
      case GameRuntimeState.routePhilosophy: bubblePos = Vector2(1429, 403); break;
      case GameRuntimeState.routeEmpathy: bubblePos = Vector2(1445, 403); break;
    }

    _bubble = SpriteComponent(
      sprite: await Sprite.load('CITY_MEGA.png',
          srcPosition: bubblePos, srcSize: Vector2(16, 16)),
      position: Vector2(0, -size.y + 12),
      size: Vector2(16, 16),
      anchor: Anchor.bottomCenter,
    );
    add(_bubble);

    // インタラクト設定
    add(InteractHitbox(
      position: Vector2(0, 0),
      size: size,
      onInteract: _onTalk,
      icon: Icons.auto_awesome,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 浮遊エフェクト (base: -size.y + 12)
    _bubble.position.y = -size.y + 12 + sin(game.timeService.totalPlayTime * 4) * 2;
    // シルエット自体も少し揺らす
    opacity = 0.4 + sin(game.timeService.totalPlayTime * 2) * 0.1;
  }

  void _onTalk() {
    String message = "";
    String tag = "";
    switch (attribute) {
      case GameRuntimeState.routeNormal:
        tag = "INITIAL_LOG_00";
        message = "「……記録によれば、特定の行動シーケンス（方向キーの2度押し）により、移動速度の向上が可能のようです。」";
        break;
      case GameRuntimeState.routeViolence:
        tag = "RECORD_V_01";
        message = "「……もっと激しく。速く動けるはずだ。方向を『二度』叩け。止まるな。」";
        break;
      case GameRuntimeState.routeEfficiency:
        tag = "OPTIMIZE_E_02";
        message = "「移動効率の向上を検知。方向キーの『二度押し』による高速移動（Run）が解禁されました。」";
        break;
      case GameRuntimeState.routeEmpathy:
        tag = "EMPATHY_SYNC_03";
        message = "「みんながあなたを待っているわ。……急ぐなら、足を『二度』動かしてみて？」";
        break;
      case GameRuntimeState.routePhilosophy:
        tag = "COGNITIVE_P_04";
        message = "「思考が加速する。……二度の意志、二度の入力。それでこの閉じた世界を駆け抜けろ。」";
        break;
    }

    game.windowManager.showDialog(["[$tag]", message]);
  }
}
