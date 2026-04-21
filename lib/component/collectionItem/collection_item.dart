import 'package:flame/components.dart';
import '../item/item.dart';
import '../player.dart';

/// コレクション用アイテムの基底クラス
class CollectionItem extends Item {
  CollectionItem({
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
  }) : super(type: ItemType.collection);

  @override
  Future<void> onItemLoad() async {
    if (spritePath.isNotEmpty) {
      sprite = await game.loadSprite(spritePath);
    }
  }

  @override
  void onUse(Player player) {
    // コレクションアイテムは直接使用しない
  }
}
