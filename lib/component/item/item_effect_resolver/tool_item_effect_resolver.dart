import 'package:anagaattara_hairitai/component/item/item.dart';
import 'package:anagaattara_hairitai/component/player.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class ToolEffectResolver {
  static Function(Player)? resolve(String? effectName) {
    if (effectName == null) return null;

    switch (effectName) {
      case 'swing':
        return (player) {
          player.performMeleeAttack();
        };
      case 'throw':
        return (player) {
          final equippedItem = ItemFactory.createItemByName(
            player.itemBag.equippedItemName!,
            Vector2.zero(),
          );
          player.throwWorldObject(equippedItem!);
          player.itemBag.removeItem(player.itemBag.equippedItemName!, count: 1);
          debugPrint('throw');
        };
      // 他の道具効果があればここに追加
      default:
        return null;
    }
  }
}
