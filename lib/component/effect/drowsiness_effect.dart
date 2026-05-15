import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../main.dart';

class DrowsinessEffect extends PositionComponent with HasGameReference<MyGame> {
  double intensity = 0.0; // 0.0 to 1.0

  DrowsinessEffect() : super(priority: 1000);

  @override
  void render(Canvas canvas) {
    if (intensity <= 0) return;

    final rect = game.camera.viewport.size.toRect();
    
    // 眠気演出：画面端を暗くし、中央をぼんやりさせる（簡易版として半透明の黒と白を重ねる）
    final paint = Paint()
      ..color = Colors.black.withOpacity(intensity * 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, 50 * intensity);
    
    canvas.drawRect(rect, paint);

    // まぶたが閉じるような演出
    final double eyelidHeight = (game.camera.viewport.size.y / 2) * intensity;
    final eyelidPaint = Paint()..color = Colors.black.withOpacity(intensity * 0.8);
    
    // 上まぶた
    canvas.drawRect(Rect.fromLTWH(0, 0, game.camera.viewport.size.x, eyelidHeight), eyelidPaint);
    // 下まぶた
    canvas.drawRect(Rect.fromLTWH(0, game.camera.viewport.size.y - eyelidHeight, game.camera.viewport.size.x, eyelidHeight), eyelidPaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 常にビューポート全体をカバー
    size = game.camera.viewport.size;
  }
}
