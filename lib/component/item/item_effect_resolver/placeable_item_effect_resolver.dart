import 'package:anagaattara_hairitai/main.dart';
import 'package:anagaattara_hairitai/system/automation_tool_kind.dart';
import 'package:anagaattara_hairitai/system/automation_tool_state.dart';
import 'package:anagaattara_hairitai/system/placeable_placement_spec.dart';

class PlaceableEffectResolver {
  static void Function(MyGame)? resolve(
    String? effectName, {
    required String itemName,
    required String spritePath,
  }) {
    switch (effectName) {
      case 'none':
        return (game) {};
      case 'terrainFill':
        return (game) {
          _startPlacement(
            game,
            TerrainFillPlacementSpec(
              itemName: itemName,
              spritePath: spritePath,
            ),
          );
        };
      case 'floorPlate':
        return (game) {
          _startPlacement(
            game,
            FloorPlacementSpec(
              itemName: itemName,
              spritePath: spritePath,
            ),
          );
        };
      case 'automationKit':
      case 'automationHarvest':
      case 'automationUpkeep':
      case 'automationWard':
        return (game) {
          final kind = _kindFromEffect(effectName!, itemName);
          if (kind == null) return;
          final state = game.gameRuntimeState;
          if (!state.isOnTargetStarOutdoor) {
            game.windowManager.showDialog([
              '対象星の地上でのみ設置できる。',
            ]);
            return;
          }
          if (!state.canPlaceTool(kind)) {
            game.windowManager.showDialog([
              '${kind.itemName}は、この星ではすでに設置済みだ。',
            ]);
            return;
          }
          if (game.player.inUnderGround) {
            game.windowManager.showDialog(['地上に出てから設置して。']);
            return;
          }
          _startPlacement(
            game,
            AutomationToolPlacementSpec(
              toolKind: kind,
              itemName: itemName,
              spritePath: spritePath,
            ),
          );
        };
      case 'furniture':
        return (game) {
          _startPlacement(
            game,
            FurniturePlacementSpec(
              itemName: itemName,
              spritePath: spritePath,
            ),
          );
        };
      default:
        return null;
    }
  }

  static AutomationToolKind? _kindFromEffect(String effect, String itemName) {
    return switch (effect) {
      'automationHarvest' => AutomationToolKind.harvest,
      'automationUpkeep' || 'automationKit' => AutomationToolKind.upkeep,
      'automationWard' => AutomationToolKind.ward,
      _ => switch (itemName) {
          '自動収穫ツール' => AutomationToolKind.harvest,
          '自動整備ツール' || '自動化キット' => AutomationToolKind.upkeep,
          '自動防衛ツール' => AutomationToolKind.ward,
          _ => null,
        },
    };
  }

  static void _startPlacement(MyGame game, PlaceablePlacementSpec spec) {
    if (!spec.canStart(game)) {
      game.windowManager.showDialog(['ここでは配置できません。']);
      return;
    }
    if (!game.placeablePlacement.start(game, spec)) {
      game.windowManager.showDialog(['ここでは配置できません。']);
    }
  }
}
