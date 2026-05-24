import 'package:flame/collisions.dart';

import 'package:flame/components.dart';

import 'package:flutter/material.dart';

import '../../../../main.dart';

import '../collision/collision_family.dart';

import '../../game_stage/lighting/camera_viewport_coords.dart';

import '../../game_stage/lighting/light_receiver.dart';

import '../../game_stage/lighting/lighting_participation.dart';

import '../../game_stage/lighting/lighting_participant.dart';

class Ground extends RectangleComponent
    with
        CollisionCallbacks,
        HasGameReference<MyGame>,
        HasCollisionFamily,
        LightingParticipant,
        LightReceiver {
  @override
  CollisionFamily get collisionFamily => CollisionFamily.terrain;

  @override
  LightingParticipation get lightingParticipation =>
      LightingParticipation.full;

  Sprite? _groundSprite;

  final double groundWidth;

  final double groundHeight;

  final bool isScrollForward;

  final bool loop;

  Sprite? get groundSprite => _groundSprite;

  Color? overlayColor;

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
    add(
      RectangleHitbox(
        size: Vector2(groundWidth, groundHeight),
        collisionType: CollisionType.passive,
        isSolid: true,
      ),
    );
    debugPrint('Ground onLoad: position.y = ${position.y}, size.y = ${size.y}');
  }

  void resetPositions(Vector2 gameSize) {
    position.y = gameSize.y;
  }

  @override
  void render(Canvas canvas) {
    if (_groundSprite == null) return;

    renderWithComponentLighting(canvas, _renderGroundSprites);
  }

  /// strip 照明用（[render] と同じタイル描画）。
  void renderStripTiles(Canvas canvas) => _renderGroundSprites(canvas);

  /// マスク生成用: strip 全幅（0..size.x）を [maskPaint] で描画。
  void paintStripTilesForMask(Canvas canvas, Paint maskPaint) {
    final sprite = _groundSprite;
    if (sprite == null) {
      return;
    }
    final tileW = sprite.srcSize.x;
    if (tileW < 1) {
      return;
    }

    final clip = Rect.fromLTWH(0, 0, size.x, size.y);
    if (loop) {
      final step = isScrollForward ? tileW : -tileW;
      final int startI;
      final int endI;
      if (step > 0) {
        startI = ((clip.left - tileW) / step).floor();
        endI = ((clip.right + tileW) / step).ceil();
      } else {
        startI = ((clip.right + tileW) / step).ceil();
        endI = ((clip.left - tileW) / step).floor();
      }
      if (startI <= endI) {
        for (var i = startI; i <= endI; i++) {
          sprite.render(
            canvas,
            position: Vector2(i * step, 0),
            size: size,
            overridePaint: maskPaint,
          );
        }
      }
    } else {
      final drawX = isScrollForward ? 0.0 : -tileW;
      final tileRect = Rect.fromLTWH(drawX, 0, size.x, size.y);
      if (tileRect.overlaps(clip)) {
        sprite.render(
          canvas,
          position: Vector2(drawX, 0),
          size: size,
          overridePaint: maskPaint,
        );
      }
    }
  }

  /// clip は [LightReceiverRenderer] が [visibleHorizontalBandLocal] で行う。
  /// ここではタイル index 範囲の算出に同じ帯を使う。
  void _renderGroundSprites(Canvas canvas) {
    try {
      final sprite = _groundSprite!;
      final tileW = sprite.srcSize.x;
      if (tileW < 1) {
        return;
      }

      final band = CameraViewportCoords.visibleHorizontalBandLocal(
        this,
        game.camera,
      );
      final clip = band.intersect(Rect.fromLTWH(0, 0, size.x, size.y));
      if (clip.isEmpty) {
        return;
      }

      if (loop) {
        final step = isScrollForward ? tileW : -tileW;
        final int startI;
        final int endI;
        if (step > 0) {
          startI = ((clip.left - tileW) / step).floor();
          endI = ((clip.right + tileW) / step).ceil();
        } else {
          startI = ((clip.right + tileW) / step).ceil();
          endI = ((clip.left - tileW) / step).floor();
        }
        if (startI <= endI) {
          for (var i = startI; i <= endI; i++) {
            sprite.render(
              canvas,
              position: Vector2(i * step, 0),
              size: size,
            );
          }
        }
      } else {
        final drawX = isScrollForward ? 0.0 : -tileW;
        final tileRect = Rect.fromLTWH(drawX, 0, size.x, size.y);
        if (tileRect.overlaps(clip)) {
          sprite.render(
            canvas,
            position: Vector2(drawX, 0),
            size: size,
          );
        }
      }

      if (overlayColor != null) {
        final overlayBounds = Rect.fromLTWH(
          isScrollForward ? 0 : -size.x,
          0,
          size.x,
          size.y,
        ).intersect(clip);
        if (!overlayBounds.isEmpty) {
          final paint = Paint()
            ..color = overlayColor!
            ..blendMode = BlendMode.srcATop;
          canvas.drawRect(overlayBounds, paint);
        }
      }
    } catch (e) {
      debugPrint('Error rendering ground: $e');
    }
  }
}
