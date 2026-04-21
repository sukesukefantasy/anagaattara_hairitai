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
  final Vector2 defaultSize; // 各建物のデフォルトのサイズ（静的）... スプライトのsrcSize * 2 を使用している。
  final ExitPointCalculator exitPointCalculator;

  const BuildingDefinition({
    required this.type,
    required this.defaultSize,
    required this.exitPointCalculator,
  });
}

class BuildingDefinitions {
  static final Map<String, Map<String, BuildingDefinition>>
  allSceneDefinitions = {
    // ステージ1用の建物定義
    'outdoor_1': {
      'health_center': BuildingDefinition(
        type: 'health_center',
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
      'station': BuildingDefinition(
        type: 'station',
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
    'outdoor_3': {
      'cafe': BuildingDefinition(
        type: 'cafe',
        defaultSize: Vector2(276, 160),
        exitPointCalculator:
            (pos, size, pSize, gSize) => Vector2(pos.x + size.x / 2 - pSize.x / 2, gSize.y - pSize.y),
      ),
      'station': BuildingDefinition(
        type: 'station',
        defaultSize: Vector2(542, 122),
        exitPointCalculator:
            (pos, size, pSize, gSize) => Vector2(pos.x + size.x / 2 - pSize.x / 2, gSize.y - pSize.y),
      ),
    },
    'outdoor_4': {
      'burger_store': BuildingDefinition(
        type: 'burger_store',
        defaultSize: Vector2(212, 160),
        exitPointCalculator:
            (pos, size, pSize, gSize) => Vector2(pos.x + size.x / 2 - pSize.x / 2, gSize.y - pSize.y),
      ),
      'station': BuildingDefinition(
        type: 'station',
        defaultSize: Vector2(542, 122),
        exitPointCalculator:
            (pos, size, pSize, gSize) => Vector2(pos.x + size.x / 2 - pSize.x / 2, gSize.y - pSize.y),
      ),
    },
    'outdoor_philosophy': {
      'apartment': BuildingDefinition(
        type: 'apartment',
        defaultSize: Vector2(212, 440),
        exitPointCalculator:
            (pos, size, pSize, gSize) => Vector2(pos.x + size.x / 2 - pSize.x / 2, gSize.y - pSize.y),
      ),
      'station': BuildingDefinition(
        type: 'station',
        defaultSize: Vector2(542, 122),
        exitPointCalculator:
            (pos, size, pSize, gSize) => Vector2(pos.x + size.x / 2 - pSize.x / 2, gSize.y - pSize.y),
      ),
    },
    'outdoor_true': {
      // 最終ステージのため駅はなし
      'shop': BuildingDefinition(
        type: 'shop',
        defaultSize: Vector2(362, 190),
        exitPointCalculator: (pos, size, pSize, gSize) => Vector2(pos.x + size.x / 2 - pSize.x / 2, gSize.y - pSize.y),
      ),
    },
    'outdoor_despair': {
      // 最終ステージのため駅はなし
      'apartment': BuildingDefinition(
        type: 'apartment',
        defaultSize: Vector2(212, 440),
        exitPointCalculator: (pos, size, pSize, gSize) => Vector2(pos.x + size.x / 2 - pSize.x / 2, gSize.y - pSize.y),
      ),
    },
  };
}

// ExitPointCalculator の typedef は BuildingDefinition の上に移動されていることを前提とします。
