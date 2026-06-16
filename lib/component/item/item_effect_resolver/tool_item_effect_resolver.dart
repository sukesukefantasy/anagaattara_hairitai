import 'package:anagaattara_hairitai/main.dart';
import '../../player.dart';

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
      case 'gasolinePour':
        // 単発使用は何もしない（押しっぱなしのみ）
        return (game) {};
      default:
        return null;
    }
  }

  static void Function(Player, bool)? resolveToggle(String? effectName) {
    if (effectName == null) return null;

    switch (effectName) {
      case 'gasolinePour':
        return (player, isPressed) {
          if (isPressed) {
            player.startPouringGasoline();
          } else {
            player.stopPouringGasoline();
          }
        };
      default:
        return null;
    }
  }
}
