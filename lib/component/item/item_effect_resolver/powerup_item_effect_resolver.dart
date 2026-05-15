import 'dart:math';

import 'package:anagaattara_hairitai/main.dart';

class PowerUpEffectResolver {
  static void Function(MyGame)? resolve(String? effectName) {
    if (effectName == null) return null;

    switch (effectName) {
      case 'increaseMaxHealth':
        return (game) {
          game.gameRuntimeState.hpBonus += 20;
          game.player.recoveryIntegrity(20);
        };
      case 'addMaxStress':
        return (game) {
          game.gameRuntimeState.stressBonus += 20;
          game.player.updateStress(max(0, game.player.currentStress - 20));
        };
      default:
        return null;
    }
  }
}
