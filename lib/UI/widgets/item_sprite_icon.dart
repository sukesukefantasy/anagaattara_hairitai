import 'package:flutter/material.dart';

import '../../component/item/item.dart';

/// アイテムアイコン表示。スプライトシートの場合は1フレーム目のみ表示する。
class ItemSpriteIcon extends StatelessWidget {
  final String itemName;
  final String spritePath;
  final double? width;
  final double? height;
  final BoxFit fit;

  const ItemSpriteIcon({
    super.key,
    required this.itemName,
    required this.spritePath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = 'assets/images/$spritePath';
    final meta = ItemFactory.resolveSpriteSheetMeta(
      itemName: itemName,
      spritePath: spritePath,
    );

    if (meta == null) {
      return Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.broken_image,
            size: width ?? height ?? 40,
            color: Colors.grey,
          );
        },
      );
    }

    // 1フレーム分だけ見せる（シート全体を縮小しない）
    return SizedBox(
      width: width,
      height: height,
      child: FittedBox(
        fit: fit,
        child: SizedBox(
          width: meta.frameWidth,
          height: meta.frameHeight,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: meta.frameWidth,
              maxHeight: meta.frameHeight,
              alignment: Alignment.centerLeft,
              child: Image.asset(
                assetPath,
                width: meta.frameWidth * meta.frameCount,
                height: meta.frameHeight,
                fit: BoxFit.none,
                alignment: Alignment.centerLeft,
                filterQuality: FilterQuality.none,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.broken_image,
                    size: meta.frameWidth,
                    color: Colors.grey,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
