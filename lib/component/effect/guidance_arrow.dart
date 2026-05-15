import 'dart:math';
import 'package:flame/components.dart';
import '../../main.dart';

class GuidanceArrow extends PositionComponent with HasGameReference<MyGame> {
  final PositionComponent target;
  late final SpriteComponent _arrowSprite;

  GuidanceArrow({required this.target}) : super(priority: 100);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _arrowSprite = SpriteComponent(
      sprite: await Sprite.load('CITY_MEGA.png',
          srcPosition: Vector2(1381, 403), srcSize: Vector2(16, 16)), // 仮の矢印
      size: Vector2(32, 32),
      anchor: Anchor.center,
    );
    add(_arrowSprite);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // プレイヤーの頭上に表示
    position = game.player.absolutePosition + Vector2(0, -60);
    
    // ターゲットの方向を向く
    final diff = target.absolutePosition - game.player.absolutePosition;
    angle = atan2(diff.y, diff.x);
    
    // ふわふわさせる
    _arrowSprite.position.y = sin(game.timeService.totalPlayTime * 5) * 5;
    
    // 依存ルートが解除されたら消える
    if (!game.gameRuntimeState.isDependencyOverloadForUi) {
      removeFromParent();
    }
  }
}
