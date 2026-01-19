import 'package:flame/components.dart';
import '../player.dart';

class DigEffectComponent extends SpriteAnimationComponent with HasGameReference {
  final Player player;


  DigEffectComponent({required this.player})
    : super(size: Vector2(64, 64), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    final spriteSheet = await game.images.load('dig_through.png');
    animation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 2,
        stepTime: 0.2,
        textureSize: Vector2(64, 64),
        amountPerRow: 2,
        loop: true,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    position = Vector2(player.position.x, player.position.y);
  }
}
