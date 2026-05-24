import 'dart:ui';

import 'package:flame/components.dart';

/// スプライトシート形式のアイテム画像メタデータ。
class ItemSpriteSheetMeta {
  final double frameWidth;
  final double frameHeight;
  final int frameCount;
  final int amountPerRow;
  final double stepTime;

  const ItemSpriteSheetMeta({
    required this.frameWidth,
    required this.frameHeight,
    required this.frameCount,
    required this.amountPerRow,
    this.stepTime = 0.18,
  });

  factory ItemSpriteSheetMeta.fromMap(Map<String, dynamic> map) {
    final frameCount = map['frameCount'] as int;
    return ItemSpriteSheetMeta(
      frameWidth: (map['frameWidth'] as num).toDouble(),
      frameHeight: (map['frameHeight'] as num).toDouble(),
      frameCount: frameCount,
      amountPerRow: map['amountPerRow'] as int? ?? frameCount,
      stepTime: (map['stepTime'] as num?)?.toDouble() ?? 0.18,
    );
  }

  Sprite firstFrameSprite(Image image) {
    return Sprite(
      image,
      srcPosition: Vector2.zero(),
      srcSize: Vector2(frameWidth, frameHeight),
    );
  }

  SpriteAnimation createAnimation(Image image) {
    return SpriteAnimation.fromFrameData(
      image,
      SpriteAnimationData.sequenced(
        amount: frameCount,
        stepTime: stepTime,
        textureSize: Vector2(frameWidth, frameHeight),
        amountPerRow: amountPerRow,
      ),
    );
  }
}
