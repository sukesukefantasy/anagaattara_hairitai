import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../../main.dart';
import '../../system/storage/game_runtime_state.dart';
import '../common/hitboxes/interact_hitbox.dart';

/// 表示用ルートID。[GameRuntimeState] のマクロ定数と `normal`。
class GhostEcho extends SpriteComponent with HasGameReference<MyGame> {
  final String routeId;
  final Color color;

  late final SpriteComponent _bubble;

  GhostEcho({
    required this.routeId,
    required this.color,
    required Vector2 position,
  }) : super(position: position, size: Vector2(1.0, 1.0)) {
    anchor = Anchor.bottomCenter;
  }

  @override
  Future<void> onLoad() async {
    try {
      sprite = await game.loadSprite(
        'player01_anim.png',
        srcPosition: Vector2(0, 0),
        srcSize: Vector2(50, 50),
      );
      if (sprite != null) {
        size = sprite!.srcSize.clone();
      }
    } catch (e) {
      debugPrint('Error loading GhostEcho sprite: $e');
      size = Vector2(1, 1);
    }
    paint.color = color.withOpacity(0.5);

    Vector2 bubblePos = Vector2(1381, 403);
    switch (routeId) {
      case GameRuntimeState.macroRouteNourishment:
        bubblePos = Vector2(1397, 403);
        break;
      case GameRuntimeState.macroRouteDestroy:
        bubblePos = Vector2(1413, 403);
        break;
      case GameRuntimeState.macroRouteNormal:
        bubblePos = Vector2(1429, 403);
        break;
      case GameRuntimeState.macroRouteTrue:
        bubblePos = Vector2(1445, 403);
        break;
      case 'normal':
        break;
      default:
        break;
    }

    final bubbleSprite = await Sprite.load(
      'CITY_MEGA.png',
      srcPosition: bubblePos,
      srcSize: Vector2(16, 16),
    );
    _bubble = SpriteComponent(
      sprite: bubbleSprite,
      position: Vector2(0, 0),
      size: bubbleSprite.srcSize.clone(),
      anchor: Anchor.bottomCenter,
    );
    add(_bubble);

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
    opacity = 0.4 + sin(game.timeService.totalPlayTime * 2) * 0.1;
  }

  void _onTalk() {
    String message = '';
    String tag = '';
    final state = game.gameRuntimeState;
    final isPrologue = state.currentOutdoorSceneId == 'outdoor_0';

    switch (routeId) {
      case 'normal':
        tag = 'INITIAL_LOG_00';
        if (isPrologue && state.scenarioCount == 1) {
          message =
              '「準備はいいか？ この星の重力ともおさらばだな。……君がこの世界に何を見出すか、楽しみにしているよ。」';
        } else {
          message =
              '「……記録によれば、特定の行動シーケンス（方向キーの2度押し）により、移動速度の向上が可能のようです。」';
        }
        break;
      case GameRuntimeState.macroRouteNourishment:
        tag = 'MACRO_NOURISHMENT';
        message = isPrologue
            ? '「便利さに手を染めた跡が、星の端から笑っている。……それでも止められないのか。」'
            : '「自動化の契約は、意志の核まで預けたという記録がある。星は肥え、余裕まで学んだ顔をする。」';
        break;
      case GameRuntimeState.macroRouteDestroy:
        tag = 'MACRO_DESTROY';
        message = isPrologue
            ? '「断片だけ残して消えた日の鼓動が聞こえる。奪還に本気になる星へ、あなたは近づいた。」'
            : '「殺戮と赤い残滓で警戒を積み上げた。星は防衛を選び、引き摺り戻そうとしている。」';
        break;
      case GameRuntimeState.macroRouteNormal:
        tag = 'MACRO_NORMAL';
        message = isPrologue
            ? '「無機と歴史だけを送還した静かな周回。無難だが、厚みは薄いままだ。」'
            : '「生命を極力伴わせずに回した記録。母星は動くが、名前は戻りにくい。」';
        break;
      case GameRuntimeState.macroRouteTrue:
        tag = 'MACRO_TRUE';
        message = isPrologue
            ? '「周回を重ね、父の断片と少女の回路が重なり合った。その先にだけ開く扉がある。」'
            : '「真の深層へ至った痕跡。ローグとファームの両輪が、一つの突破へ収束した。」';
        break;
      default:
        tag = 'LOG_UNKNOWN';
        message = '「……読み取れないログの残響だ。」';
    }

    game.windowManager.showDialog(['[$tag]', message]);
  }
}
