import 'dart:math';

import 'package:anagaattara_hairitai/main.dart';

class StressItemEffectResolver {
  static void apply(MyGame game, double stressReduction) {
    game.player.updateStress(
      max(0, game.player.currentStress - stressReduction),
    );
  }

  /// 将来 `stressEffect` 文字列を定義に付けたとき用。
  static void Function(MyGame)? resolve(
    String? effectName,
    double fallbackReduction,
  ) {
    if (effectName == null) {
      return (game) => apply(game, fallbackReduction);
    }
    switch (effectName) {
      default:
        return (game) => apply(game, fallbackReduction);
    }
  }
}
