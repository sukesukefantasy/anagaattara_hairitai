import 'package:anagaattara_hairitai/main.dart';

class ToolEffectResolver {
  static void Function(MyGame)? resolve(String? effectName) {
    if (effectName == null) return null;

    switch (effectName) {
      case 'swing':
        return (game) => game.player.performMeleeAttack();
      case 'throw':
        return (game) {
          game.player.throwEquippedToolItem();
        };
      default:
        return null;
    }
  }
}
