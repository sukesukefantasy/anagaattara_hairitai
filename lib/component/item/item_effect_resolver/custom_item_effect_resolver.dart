import 'package:anagaattara_hairitai/component/player.dart';
import 'package:anagaattara_hairitai/system/storage/game_runtime_state.dart';

class CustomItemEffectResolver {
  static Function(Player)? resolve(String? effectName) {
    if (effectName == null) return null;

    switch (effectName) {
      case 'updateMiningPoints5':
        return (player) => player.updateMiningPoints(5);
      /* case 'addMetaScore':
        return (player) => {
          if (player.game.gameRuntimeState.currentOutdoorSceneId == 'outdoor_philosophy') {
            player.game.routeManager.onAction(GameRuntimeState.routePhilosophy)
          }
        }; */
        
      // 他のカスタム効果があればここに追加
      default:
        return null;
    }
  }
}

