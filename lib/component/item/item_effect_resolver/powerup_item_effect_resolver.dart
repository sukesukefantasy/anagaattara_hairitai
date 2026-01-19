import 'package:anagaattara_hairitai/component/player.dart';

class PowerUpEffectResolver {
  static Function(Player)? resolve(String? effectName) {
    if (effectName == null) return null;

    switch (effectName) {
      case 'addMaxStress':
        return (player) => player.addMaxStress(5.0);
      // 他のパワーアップ効果があればここに追加
      default:
        return null;
    }
  }
}

