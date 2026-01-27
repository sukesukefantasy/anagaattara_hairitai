import 'package:anagaattara_hairitai/component/player.dart';

class PlaceableEffectResolver {
  static Function(Player)? resolve(String? effectName) {
    if (effectName == null) return null;

    switch (effectName) {
      case 'none':
        return (player) {};
        
      // 他のパワーアップ効果があればここに追加
      default:
        return null;
    }
  }
}

