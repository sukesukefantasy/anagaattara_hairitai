import 'package:anagaattara_hairitai/main.dart';
import 'package:anagaattara_hairitai/system/placeable_placement_spec.dart';
import 'package:flutter/foundation.dart';

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
        return (game) {
          debugPrint(
            'PlaceableEffectResolver(automationKit): スタブ '
            '(将来 game_ui の設置モードと AutomationKit 配置へ接続予定)',
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

  static void _startPlacement(MyGame game, PlaceablePlacementSpec spec) {
    if (!spec.canStart(game)) {
      game.windowManager.showDialog(['地下でのみ配置できます。']);
      return;
    }
    if (!game.placeablePlacement.start(game, spec)) {
      game.windowManager.showDialog(['ここでは配置できません。']);
    }
  }
}
