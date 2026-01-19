// 建物の静的定義ファイル building_data.dart を元に扉の位置などを定義・調整するファイル

import 'package:flame/components.dart';
import '../../../main.dart'; // MyGameをインポート

typedef ExitPointCalculator =
    Vector2 Function(
      Vector2 buildingWorldPosition,
      Vector2 buildingSize,
      Vector2 playerSize,
      Vector2 gameCanvasSize,
    );

class BuildingDefinition {
  final String type;
  final Vector2 defaultOutdoorPosition; // 各建物のデフォルトの屋外配置位置（静的）
  final Vector2 defaultSize; // 各建物のデフォルトのサイズ（静的）... スプライトのsrcSize * 2 を使用している。
  final ExitPointCalculator exitPointCalculator;

  const BuildingDefinition({
    required this.type,
    required this.defaultOutdoorPosition,
    required this.defaultSize,
    required this.exitPointCalculator,
  });
}

class BuildingDefinitions {
  static final Map<String, Map<String, BuildingDefinition>>
  allSceneDefinitions = {
    // ステージ1用の建物定義
    'outdoor': {
      'health_center': BuildingDefinition(
        type: 'health_center',
        defaultOutdoorPosition: Vector2(-600, 0),
        defaultSize: Vector2(320, 306),
        exitPointCalculator:
            (
              buildingOutdoorPosition,
              buildingSize,
              playerSize,
              gameCanvasSize,
            ) => Vector2(
              buildingOutdoorPosition.x + buildingSize.x / 2 - playerSize.x / 2,
              gameCanvasSize.y - playerSize.y, // プレイヤーの足元を地面に合わせる
            ),
      ),
      'apartment': BuildingDefinition(
        type: 'apartment',
        defaultOutdoorPosition: Vector2(-300, 0),
        defaultSize: Vector2(212, 440),
        exitPointCalculator:
            (
              buildingOutdoorPosition,
              buildingSize,
              playerSize,
              gameCanvasSize,
            ) => Vector2(
              buildingOutdoorPosition.x + buildingSize.x / 2 - playerSize.x / 2,
              gameCanvasSize.y - playerSize.y,
            ),
      ),
      'sushi': BuildingDefinition(
        type: 'sushi',
        defaultOutdoorPosition: Vector2(-900, 0),
        defaultSize: Vector2(202, 352),
        exitPointCalculator:
            (
              buildingOutdoorPosition,
              buildingSize,
              playerSize,
              gameCanvasSize,
            ) => Vector2(
              buildingOutdoorPosition.x + buildingSize.x / 2 - playerSize.x / 2,
              gameCanvasSize.y - playerSize.y,
            ),
      ),
      'cafe': BuildingDefinition(
        type: 'cafe',
        defaultOutdoorPosition: Vector2(-1100, 0),
        defaultSize: Vector2(276, 160),
        exitPointCalculator:
            (
              buildingOutdoorPosition,
              buildingSize,
              playerSize,
              gameCanvasSize,
            ) => Vector2(
              buildingOutdoorPosition.x + buildingSize.x / 2 - playerSize.x / 2,
              gameCanvasSize.y - playerSize.y,
            ),
      ),
      'burger_store': BuildingDefinition(
        type: 'burger_store',
        defaultOutdoorPosition: Vector2(-1300, 0),
        defaultSize: Vector2(212, 160),
        exitPointCalculator:
            (
              buildingOutdoorPosition,
              buildingSize,
              playerSize,
              gameCanvasSize,
            ) => Vector2(
              buildingOutdoorPosition.x + buildingSize.x / 2 - playerSize.x / 2,
              gameCanvasSize.y - playerSize.y,
            ),
      ),
      'shop': BuildingDefinition(
        type: 'shop',
        defaultOutdoorPosition: Vector2(-2300, 0),
        defaultSize: Vector2(362, 190),
        exitPointCalculator:
            (
              buildingOutdoorPosition,
              buildingSize,
              playerSize,
              gameCanvasSize,
            ) => Vector2(
              buildingOutdoorPosition.x + buildingSize.x / 2 - playerSize.x / 2,
              gameCanvasSize.y - playerSize.y,
            ),
      ),
      'station': BuildingDefinition(
        type: 'station',
        defaultOutdoorPosition: Vector2(-MyGame.worldWidth, 0),
        defaultSize: Vector2(542, 122), // Stationのサイズ (271 * 2, 61 * 2)
        exitPointCalculator:
            (
              buildingOutdoorPosition,
              buildingSize,
              playerSize,
              gameCanvasSize,
            ) => Vector2(
              buildingOutdoorPosition.x + buildingSize.x / 2 - playerSize.x / 2,
              gameCanvasSize.y - playerSize.y,
            ),
      ),
    },
    // ステージ2用の建物定義
    'outdoor_2': {
      'health_center': BuildingDefinition(
        type: 'health_center',
        defaultOutdoorPosition: Vector2(-1000, 0),
        defaultSize: Vector2(320, 306), // HealthCenterのサイズ
        exitPointCalculator:
            (
              buildingOutdoorPosition,
              buildingSize,
              playerSize,
              gameCanvasSize,
            ) => Vector2(
              buildingOutdoorPosition.x + buildingSize.x / 2 - playerSize.x / 2,
              gameCanvasSize.y - playerSize.y,
            ),
      ),
      'apartment': BuildingDefinition(
        type: 'apartment',
        defaultOutdoorPosition: Vector2(-MyGame.worldWidth + 1000, 0),
        defaultSize: Vector2(212, 440), // Apartmentのサイズ
        exitPointCalculator:
            (
              buildingOutdoorPosition,
              buildingSize,
              playerSize,
              gameCanvasSize,
            ) => Vector2(
              buildingOutdoorPosition.x + buildingSize.x / 2 - playerSize.x / 2,
              gameCanvasSize.y - playerSize.y,
            ),
      ),
      'sushi': BuildingDefinition(
        type: 'sushi',
        defaultOutdoorPosition: Vector2(-1500, 0), // 修正: 正の領域に入りすぎないように調整
        defaultSize: Vector2(202, 352), // Sushiのサイズ
        exitPointCalculator:
            (
              buildingOutdoorPosition,
              buildingSize,
              playerSize,
              gameCanvasSize,
            ) => Vector2(
              buildingOutdoorPosition.x + buildingSize.x / 2 - playerSize.x / 2,
              gameCanvasSize.y - playerSize.y,
            ),
      ),
      'station': BuildingDefinition(
        type: 'station',
        defaultOutdoorPosition: Vector2(0 - 542, 0), // 駅の右端がX=0に来るように
        defaultSize: Vector2(542, 122), // Stationのサイズ (271 * 2, 61 * 2)
        exitPointCalculator:
            (
              buildingOutdoorPosition,
              buildingSize,
              playerSize,
              gameCanvasSize,
            ) => Vector2(
              buildingOutdoorPosition.x + buildingSize.x / 2 - playerSize.x / 2,
              gameCanvasSize.y - playerSize.y,
            ),
      ),
    },
  };
}

// ExitPointCalculator の typedef は BuildingDefinition の上に移動されていることを前提とします。
