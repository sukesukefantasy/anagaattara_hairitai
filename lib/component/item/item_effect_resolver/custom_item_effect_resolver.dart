import 'package:anagaattara_hairitai/main.dart';

/// 定義の `customEffect` 文字列 → 効果。
class CustomItemEffectResolver {
  static void Function(MyGame)? resolve(String? effectName) {
    if (effectName == null) return null;

    switch (effectName) {
      case 'updateMiningPoints5':
        return (game) => game.player.updateMiningPoints(5);
      default:
        return null;
    }
  }
}
