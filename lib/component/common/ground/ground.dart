import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../../main.dart';

class Ground extends RectangleComponent
    with CollisionCallbacks, HasGameReference<MyGame> {
  Sprite? _groundSprite;
  final double groundWidth;
  final double groundHeight;
  final bool isScrollForward;
  final bool loop;
  final Color? overlayColor;

  Ground({
    required this.groundWidth,
    required this.groundHeight,
    required super.position,
    this.isScrollForward = false,
    this.loop = false,
    Sprite? groundSprite,
    this.overlayColor,
  }) : super(size: Vector2(groundWidth, groundHeight)) {
    _groundSprite = groundSprite;
  }

  @override
  Future<void> onLoad() async {
    // シンプルな矩形ヒットボックス
    add(
      RectangleHitbox(
        size: Vector2(groundWidth, groundHeight),
        collisionType: CollisionType.passive,
        isSolid: true,
      ),
    );

    // positionはコンストラクタで設定されるため、onLoadでは変更しない
    debugPrint('Ground onLoad: position.y = ${position.y}, size.y = ${size.y}');
  }

  void resetPositions(Vector2 gameSize) {
    position.y = gameSize.y;
  }

  @override
  void render(Canvas canvas) {
    if (_groundSprite == null) return;

    try {
      if (loop) {
        final repeatCount = (size.x / _groundSprite!.srcSize.x).ceil();

        for (int i = 0; i <= repeatCount; i++) {
          _groundSprite!.render(
            canvas,
            position: Vector2(
              isScrollForward
                  ? i * _groundSprite!.srcSize.x
                  : i * -_groundSprite!.srcSize.x,
              0,
            ),
            size: size,
          );
        }
      } else {
        _groundSprite!.render(
          canvas,
          position: isScrollForward ? Vector2.zero() : Vector2(-_groundSprite!.srcSize.x, 0),
          size: size,
        );
      }

      if (overlayColor != null) {
        final paint = Paint()..color = overlayColor!..blendMode = BlendMode.srcATop;
        canvas.drawRect(Rect.fromLTWH(isScrollForward ? 0 : -size.x, 0, size.x, size.y), paint);
      }
    } catch (e) {
      debugPrint('Error rendering ground: $e');
    }
  }
}
