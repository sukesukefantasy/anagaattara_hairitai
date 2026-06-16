import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../game_stage/lighting/light_receiver.dart';
import '../game_stage/lighting/lighting_participation.dart';
import '../game_stage/lighting/lighting_participant.dart';

class GasolineStamp extends SpriteComponent
    with HasGameReference<MyGame>, LightingParticipant, LightReceiver {
  final double lifespan;
  double _timer = 0;

  GasolineStamp({
    required super.position,
    this.lifespan = 30.0, // 30秒間持続
  }) : super(
          size: Vector2(32, 16),
          anchor: Anchor.center,
        );

  @override
  LightingParticipation get lightingParticipation => LightingParticipation.full;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // ガソリンの溜まりを表現するスプライト。とりあえず黒い楕円のようなもので代用するか、
    // 専用の画像があればそれを使う。
    sprite = await game.loadSprite('cargo.png'); // 代用
    paint.color = Colors.black.withValues(alpha: 0.7);
    priority = 5; // 地面より少し上
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    if (_timer >= lifespan) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    // 消え去る直前にフェードアウト
    if (_timer > lifespan - 2.0) {
      final opacity = ((lifespan - _timer) / 2.0).clamp(0.0, 1.0);
      paint.color = Colors.black.withValues(alpha: 0.7 * opacity);
    }
    renderWithComponentLighting(canvas, super.render);
  }
}
