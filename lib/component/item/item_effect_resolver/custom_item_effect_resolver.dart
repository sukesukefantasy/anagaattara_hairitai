import 'package:anagaattara_hairitai/component/player.dart';

class CustomItemEffectResolver {
  static Function(Player)? resolve(String? effectName) {
    if (effectName == null) return null;

    switch (effectName) {
      case 'updateMiningPoints5':
        return (player) => player.updateMiningPoints(5);
      // 他のカスタム効果があればここに追加
      default:
        return null;
    }
  }
}

