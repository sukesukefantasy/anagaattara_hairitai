import 'package:anagaattara_hairitai/main.dart';

/// 通貨アイテムの効果（定義の数値は [ItemFactory] 側の `value` / currencyValue）。
/// 将来 `currencyEffect` 文字列を足す場合は [resolve] に case を追加する。
class CurrencyItemEffectResolver {
  static void apply(MyGame game, int amount) {
    game.player.updateMoneyPoints(amount);
  }

  static void Function(MyGame)? resolve(String? effectName, int fallbackAmount) {
    if (effectName == null) {
      return (game) => apply(game, fallbackAmount);
    }
    switch (effectName) {
      default:
        return (game) => apply(game, fallbackAmount);
    }
  }
}
