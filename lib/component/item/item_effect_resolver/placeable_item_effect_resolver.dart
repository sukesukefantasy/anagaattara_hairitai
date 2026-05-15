import 'package:flutter/foundation.dart';
import 'package:anagaattara_hairitai/main.dart';

class PlaceableEffectResolver {
  static void Function(MyGame)? resolve(String? effectName) {
    switch (effectName) {
      case 'none':
        return (game) {};
      case 'automationKit':
        return (game) {
          debugPrint(
            'PlaceableEffectResolver(automationKit): スタブ '
            '(将来 game_ui の設置モードと AutomationKit 配置へ接続予定)',
          );
        };
      default:
        return null;
    }
  }
}
