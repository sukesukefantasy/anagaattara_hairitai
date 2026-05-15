import 'package:anagaattara_hairitai/main.dart';

class HealthItemEffectResolver {
  static void apply(MyGame game, double healAmount) {
    game.player.recoveryIntegrity(healAmount);
  }

  /// 将来 `healEffect` 文字列を定義に付けたとき用。
  static void Function(MyGame)? resolve(String? effectName, double fallbackHeal) {
    if (effectName == null) {
      return (game) => apply(game, fallbackHeal);
    }
    switch (effectName) {
      default:
        return (game) => apply(game, fallbackHeal);
    }
  }
}
