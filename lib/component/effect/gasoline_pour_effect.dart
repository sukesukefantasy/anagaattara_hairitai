import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../main.dart';

class GasolinePourEffect extends SpriteComponent with HasGameReference<MyGame> {
  bool facingRight;
  bool isVisible = true;

  GasolinePourEffect({
    required this.facingRight,
    required super.position,
  }) : super(
          size: Vector2(25, 25),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await game.loadSprite('gasoline_can.png');
    _updateTransform();
    priority = 100;
  }

  void updateState({required Vector2 position, required bool facingRight, required bool isVisible}) {
    this.position.setFrom(position);
    this.facingRight = facingRight;
    this.isVisible = isVisible;
    _updateTransform();
  }

  void _updateTransform() {
    if (facingRight) {
      if (scale.x > 0) flipHorizontally();
      angle = pi / 2;
    } else {
      if (scale.x < 0) flipHorizontally();
      angle = -pi / 2;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!isVisible) return;
    super.render(canvas);
  }

  double _timer = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    if (isVisible) {
      // 注いでる感を出すための微細な揺れ
      position.y += sin(_timer * 20) * 0.3;
    }
  }
}
