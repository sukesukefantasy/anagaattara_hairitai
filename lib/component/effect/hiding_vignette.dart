import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' show RadialGradient, Alignment, Colors;
import '../../../main.dart';

class HidingVignette extends Component with HasGameReference<MyGame> {
  HidingVignette() : super(priority: 1051);

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.8),
        ],
        stops: const [0.5, 1.0],
      ).createShader(game.size.toRect());
    canvas.drawRect(game.size.toRect(), paint);
  }
}
