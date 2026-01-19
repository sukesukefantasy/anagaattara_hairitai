import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../component/player.dart';
import '../component/game_stage/building/building_data.dart';
import '../component/game_stage/building/building.dart';
import '../component/game_stage/building/shop.dart';
import '../component/game_stage/building/station.dart';
import '../component/game_stage/building/health_center.dart';
import '../component/game_stage/building/apartment.dart';
import '../component/game_stage/building/sushi.dart';
import '../component/game_stage/building/cafe.dart';
import '../component/game_stage/building/burger_store.dart';
import '../component/vehicle/train.dart';
import '../component/enemy/enemy_manager.dart';
import '../component/enemy/walking_enemy.dart';
import '../component/enemy/car_enemy.dart';
import '../component/common/ground/ground.dart';
import '../component/common/underground/underground.dart';
import '../component/game_stage/gamestage_component.dart';
import '../component/game_stage/lighting/sky_component.dart';
import 'game_scene.dart';
import '../UI/game_ui.dart';
import '../component/game_stage/lighting/light_component.dart';
import '../component/game_stage/building/building_definitions.dart';

abstract class AbstractOutdoorScene extends GameScene {
  Ground? ground; // null許容型に変更
  UnderGround? _underGround;
  UnderGround get underGround => _underGround!;
  final List<Building> buildings = [];
  Station? station;
  EnemyManager? enemyManager;
  SkyComponent? skyBackgroundComponent;

  final String sceneId;
  final Vector2? initialPlayerPosition;

  static double get underGroundHeight => UnderGround.underGroundHeight;

  AbstractOutdoorScene({required this.sceneId, this.initialPlayerPosition})
    : super(); // コンストラクタからunderGroundの初期化を削除

  @override
  Future<void> onLoad() async {
    debugPrint('AbstractOutdoorScene: onLoad started.');
    // playerのpriorityをシーンのonLoadで設定
    if (game.player != null) {
      game.player!.priority = 50;
      debugPrint('AbstractOutdoorScene: Player priority set to 50.');
    }

    // skyBackgroundComponentの初期化と追加
    skyBackgroundComponent = SkyComponent(timeService: game.timeService)
      ..priority = 1;
    await add(skyBackgroundComponent!);

    // enemyManagerの初期化
    enemyManager = EnemyManager(game);
    debugPrint('AbstractOutdoorScene: EnemyManager initialized.');

    // groundの初期化と追加
    final groundSprite = await Sprite.load('concrete_ground.png');
    debugPrint('AbstractOutdoorScene: groundSprite loaded.');
    ground = Ground(
      groundWidth: MyGame.worldWidth,
      groundHeight: groundHeight,
      position: Vector2(-MyGame.worldWidth, game.initialGameCanvasSize.y),
      groundSprite: groundSprite,
      loop: true,
    )..priority = 3;
    await add(ground!); // late final なのでここで初期化
    game.sceneManager.currentScene!.groundComponent = ground; // currentSceneに設定
    debugPrint('AbstractOutdoorScene: Ground initialized and added.');

    // underGroundの初期化と追加
    _underGround = UnderGround(groundHeight: groundHeight);
    _underGround!.priority = 30; // priorityを設定
    await add(_underGround!); // ここで追加
    debugPrint('AbstractOutdoorScene: UnderGround added.');
    debugPrint('AbstractOutdoorScene: onLoad finished.');
  }

  @override
  Future<void> initializeScene(dynamic data) async {
    debugPrint('AbstractOutdoorScene: initializeScene started.');
    debugPrint(
      'AbstractOutdoorScene initializeScene start. game.initialGameCanvasSize.y: ${game.initialGameCanvasSize.y}',
    );

    // 背景の初期化
    final outdoorBackgrounds = backgroundDataMap[sceneId];
    if (outdoorBackgrounds != null) {
      for (final bgData in outdoorBackgrounds) {
        final background = GameStageComponent(data: bgData, loop: true)
          ..priority = bgData.priority;
        await add(background);
        background.resetPositions(game.initialGameCanvasSize);
        debugPrint('AbstractOutdoorScene: GameStageComponent ${bgData.imagePath} added.');
      }
    }
    debugPrint('AbstractOutdoorScene: Backgrounds initialized.');

    // GroundとUnderGroundはonLoadで初期化済みなので、ここではデバッグログとcurrentSceneへの設定のみ
    debugPrint(
      'AbstractOutdoorScene initializeScene: ground.position.y = ${ground!.position.y}, ground.size.y = ${ground!.size.y}',
    );
    debugPrint(
      'AbstractOutdoorScene initializeScene: _underGround.position.y = ${_underGround!.position.y}, _underGround.size.y = ${_underGround!.size.y}',
    );
    // game.sceneManager.currentScene!.groundComponent = ground; // onLoadで設定されるため、ここでは不要

    final currentSceneBuildingDefinitions =
        BuildingDefinitions.allSceneDefinitions[sceneId];
    if (currentSceneBuildingDefinitions == null) {
      debugPrint('Error: No building definitions found for sceneId: $sceneId');
      return;
    }
    debugPrint('AbstractOutdoorScene: Building definitions loaded.');

    // Stationの初期化
    if (currentSceneBuildingDefinitions.containsKey('station')) {
      final definition = currentSceneBuildingDefinitions['station']!;
      station = Station(
        position: Vector2(
          definition.defaultOutdoorPosition.x,
          game.initialGameCanvasSize.y - definition.defaultSize.y, // Y座標をここで計算
        ),
      )..priority = 5;
      buildings.add(station!);
      await add(station!);
      debugPrint('AbstractOutdoorScene: Station added.');
    }

    final buildingTypesInScene =
        currentSceneBuildingDefinitions.keys
            .where((key) => key != 'station')
            .toList();
    for (final type in buildingTypesInScene) {
      final definition = currentSceneBuildingDefinitions[type]!;
      Building building;
      switch (type) {
        case 'health_center':
          building = HealthCenter(
            position: Vector2(
              definition.defaultOutdoorPosition.x,
              game.initialGameCanvasSize.y - definition.defaultSize.y, // Y座標をここで計算
            ),
          );
          break;
        case 'apartment':
          building = Apartment(
            position: Vector2(
              definition.defaultOutdoorPosition.x,
              game.initialGameCanvasSize.y - definition.defaultSize.y, // Y座標をここで計算
            ),
          );
          break;
        case 'sushi':
          building = Sushi(
            position: Vector2(
              definition.defaultOutdoorPosition.x,
              game.initialGameCanvasSize.y - definition.defaultSize.y, // Y座標をここで計算
            ),
          );
          break;
        case 'cafe':
          building = Cafe(
            position: Vector2(
              definition.defaultOutdoorPosition.x,
              game.initialGameCanvasSize.y - definition.defaultSize.y, // Y座標をここで計算
            ),
          );
          break;
        case 'burger_store':
          building = BurgerStore(
            position: Vector2(
              definition.defaultOutdoorPosition.x,
              game.initialGameCanvasSize.y - definition.defaultSize.y, // Y座標をここで計算
            ),
          );
          break;
        case 'shop':
          building = Shop(
            position: Vector2(
              definition.defaultOutdoorPosition.x,
              game.initialGameCanvasSize.y - definition.defaultSize.y, // Y座標をここで計算
            ),
            windowManager: game.windowManager,
            itemBag: game.itemBag,
          );
          break;
        default:
          continue; // 未知の建物タイプはスキップ
      }
      building.priority = 5;
      buildings.add(building);
      await add(building);
      debugPrint('AbstractOutdoorScene: Building ${type} added. bottom position: ${building.position.y + building.size.y}');
    }
    debugPrint('AbstractOutdoorScene: All buildings added.');

    // 敵の初期化
    for (int i = 0; i < 10; i++) {
      final walkingEnemy = enemyManager!.createEnemyOnLoad(isWalkingEnemy: true);
      await add(walkingEnemy);
      debugPrint('AbstractOutdoorScene: Walking enemy ${i} added.');
    }

    for (int i = 0; i < 1; i++) {
      final carEnemy = enemyManager!.createEnemyOnLoad(isWalkingEnemy: false);
      await add(carEnemy);
      debugPrint('AbstractOutdoorScene: Car enemy ${i} added.');
    }
    debugPrint('AbstractOutdoorScene: All enemies added.');

    debugPrint(
      'AbstractOutdoorScene initializeScene: game.initialGameCanvasSize.y = ${game.initialGameCanvasSize.y}, groundHeight = $groundHeight',
    );
    game.player!.position =
        initialPlayerPosition ??
        Vector2(-50, game.initialGameCanvasSize.y - game.player!.size.y / 2);
    game.player!.priority = 50;
    game.player!.unbeatable = false;
    debugPrint('AbstractOutdoorScene: Player position set.'); // ログメッセージを修正

    game.player!.setPhysicsBehavior(
      applyGravity: true,
      enableHorizontalPhysics: true,
      enableVerticalMovement: true,
    );
    debugPrint('AbstractOutdoorScene: Player physics behavior set.');

    // ライトの初期化
    final double testLightRadius = 60.0;
    final Vector2 testLightSize = Vector2(
      testLightRadius * 2,
      testLightRadius * 2,
    );
    final buildingPositionsForLights =
        currentSceneBuildingDefinitions.values
            .where((def) => def.type != 'station') // Stationは別途処理
            .map((def) => def.defaultOutdoorPosition.x)
            .toList();

    for (final xPos in buildingPositionsForLights) {
      final testLight = LightComponent(
        position: Vector2(xPos, game.player!.position.y - 50.0),
        size: testLightSize,
        lightRadius: testLightRadius,
        lightColor: const Color.fromARGB(255, 255, 255, 200),
        lightIntensity: 0.8,
      );
      add(testLight);
      debugPrint('AbstractOutdoorScene: Light added at xPos: $xPos.');
    }
    debugPrint('AbstractOutdoorScene: All lights added.');

    debugPrint('AbstractOutdoorScene initializeScene complete');
  }

  void resetPositions(Vector2 gameSize) {
    debugPrint(
      'AbstractOutdoorScene resetPositions called. gameSize: $gameSize',
    );
    // ポジションリセット
    ground?.resetPositions(gameSize);
    _underGround?.resetPositions(gameSize); // nullチェックを追加
    for (var building in buildings) {
      // 建物のY座標を再計算
      building.position.y = gameSize.y - building.size.y;
    }
  }

  void updateDigAreas(Player player) {
    if (player.isDigging && player.inUnderGround) {
      if (player.position.y < game.initialGameCanvasSize.y) { 
        return;
      }
      _underGround?.addDugArea(player.absoluteCenter); // nullチェックを追加
    }
  }

  bool isDug(Vector2 position) {
    return _underGround?.isDug(position) ?? false; // nullチェックを追加
  }

  @override
  void onRemove() {
    super.onRemove();
    // skyBackgroundComponentはlate finalなので、nullチェックは不要
    skyBackgroundComponent!.removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!game.player!.inUnderGround) {
      game.player!.canDig = _underGround?.isPlayerNearDiggableEntrance(
        game.player!.absoluteCenter,
      ) ?? false; // nullチェックを追加
      if (game.player!.canDig) {
        GameUI.setDigButtonState(ActionButtonState.notice);
      } else {
        GameUI.setDigButtonState(ActionButtonState.disabled);
      }
    } else {
      game.player!.canDig = true;
      GameUI.setDigButtonState(ActionButtonState.normal);
    }

    final currentWalkingEnemies = children.whereType<WalkingEnemy>().length;
    final currentCarEnemies = children.whereType<CarEnemy>().length;

    final newEnemy = enemyManager!.trySpawnEnemy(
      dt,
      currentWalkingEnemies,
      currentCarEnemies,
    );

    if (newEnemy != null) {
      add(newEnemy);
    }
  }
}
