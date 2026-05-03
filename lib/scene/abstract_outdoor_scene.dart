import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../component/npc/npc.dart';
import '../component/npc/ghost_echo.dart';
import '../component/player.dart';
import '../component/game_stage/building/building_data.dart';
import '../component/game_stage/building/building.dart';
import '../component/game_stage/building/shop.dart';
import '../component/game_stage/building/station.dart';
import '../component/game_stage/building/sushi.dart';
import '../component/game_stage/building/cafe.dart';
import '../component/game_stage/building/burger_store.dart';
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
import '../component/game_stage/building/abandoned_rocket.dart';
import '../component/game_stage/building/building_definitions.dart';
import '../component/game_stage/building/destructible_object.dart';
import '../component/common/hitboxes/interact_hitbox.dart';
import '../component/item/item.dart';
import '../system/storage/game_runtime_state.dart';
import '../game_manager/mission_manager.dart';
import 'dart:math';

abstract class AbstractOutdoorScene extends GameScene {
  Ground? ground; // null許容型に変更
  UnderGround? _underGround;
  UnderGround get underGround => _underGround!;
  final List<Building> buildings = [];
  final List<DestructibleObject> destructibles = []; // 破壊可能オブジェクト用リストを追加
  Station? station;
  AbandonedRocket? rocket; // ロケットを追加
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
    game.player.priority = 50;
    debugPrint('AbstractOutdoorScene: Player priority set to 50.');

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
    
    // 地面の色も世界の属性に合わせる
    final state = game.gameRuntimeState;
    final worldAttr = state.lastSimulatedAttribute ?? GameRuntimeState.routeNormal;
    final worldRedundancy = state.attributeRedundancy[worldAttr] ?? 0;
    final int worldLevel = state.completedRouteIds.contains(worldAttr) ? (2 + worldRedundancy).clamp(0, 3) : 0;
    
    Color? groundColor;
    if (worldLevel >= 1) {
      switch (worldAttr) {
        case GameRuntimeState.routeViolence: groundColor = Colors.red.withOpacity(0.3); break;
        case GameRuntimeState.routeEfficiency: groundColor = Colors.blueGrey.withOpacity(0.5); break;
        case GameRuntimeState.routeEmpathy: groundColor = Colors.orange.withOpacity(0.2); break;
        case GameRuntimeState.routePhilosophy: groundColor = Colors.greenAccent.withOpacity(0.2); break;
      }
    }

    ground = Ground(
      groundWidth: MyGame.worldWidth,
      groundHeight: groundHeight,
      position: Vector2(-MyGame.worldWidth, game.initialGameCanvasSize.y),
      groundSprite: groundSprite,
      loop: true,
      overlayColor: groundColor,
    )..priority = 3;
    await add(ground!);
    game.sceneManager.currentScene?.groundComponent = ground; // ! を削除
    debugPrint('AbstractOutdoorScene: Ground initialized and added.');

    // underGroundの初期化と追加
    final double currentUnderGroundHeight = (sceneId == 'outdoor_philosophy') ? 2048.0 : UnderGround.underGroundHeight;
    _underGround = UnderGround(groundHeight: groundHeight, height: currentUnderGroundHeight);
    _underGround!.priority = 30; // priorityを設定
    await add(_underGround!); // ここで追加
    debugPrint('AbstractOutdoorScene: UnderGround added.');
    debugPrint('AbstractOutdoorScene: onLoad finished.');
  }

  void clearWorldObjects() {
    debugPrint('AbstractOutdoorScene: clearWorldObjects called.');
    for (final building in buildings) {
      if (building.isMounted) building.removeFromParent();
    }
    buildings.clear();

    for (final obj in destructibles) {
      if (obj.isMounted) obj.removeFromParent();
    }
    destructibles.clear();

    if (station != null && station!.isMounted) station!.removeFromParent();
    station = null;

    if (rocket != null && rocket!.isMounted) rocket!.removeFromParent();
    rocket = null;
  }

  @override
  Future<void> initializeScene(dynamic data) async {
    debugPrint('AbstractOutdoorScene: initializeScene started.');
    final state = game.gameRuntimeState;
    
    // 世界の変容は「最後にシミュレートされた属性（前回クリア時の確定属性）」に基づく
    // プレイヤー能力（リアルタイム）とは分離する
    // シナリオ1周目は世界の変容を発生させない
    final String worldAttr = state.scenarioCount > 1 
        ? (state.lastSimulatedAttribute ?? GameRuntimeState.routeNormal)
        : GameRuntimeState.routeNormal;
    
    // 属性レベル
    final worldRedundancy = state.attributeRedundancy[worldAttr] ?? 0;
    final int worldLevel = state.completedRouteIds.contains(worldAttr) ? (2 + worldRedundancy).clamp(0, 3) : 0;

    // 属性による世界の変容フラグ
    // 1. 前回クリア時の確定属性による変容 (継続的な世界観)
    // 2. 今現在のプレイで確定させた属性による変容 (即時的な変化)
    // シナリオ1では一律 false
    final bool isEfficiencyFlattened = state.scenarioCount > 1 && (
        (worldAttr == GameRuntimeState.routeEfficiency && worldLevel >= 2) ||
        (state.activeRouteId == GameRuntimeState.routeEfficiency && sceneId == 'outdoor_3')
    );
    
    final bool isViolenceAggressive = state.scenarioCount > 1 && worldAttr == GameRuntimeState.routeViolence && worldLevel >= 2;

    debugPrint(
      'AbstractOutdoorScene initializeScene start. worldAttr: $worldAttr, worldLevel: $worldLevel',
    );

    // 背景の初期化
    // 効率化ルート確定時は背景（街並み）を表示しない
    final outdoorBackgrounds =
        (isEfficiencyFlattened && sceneId != 'outdoor_1')
            ? null
            : backgroundDataMap[sceneId];
    if (outdoorBackgrounds != null) {
      for (final bgData in outdoorBackgrounds) {
        final background = GameStageComponent(data: bgData, loop: true)
          ..priority = bgData.priority;
        await add(background);
        background.resetPositions(game.initialGameCanvasSize);

        // プレイヤーの初期位置に合わせて背景座標を同期（パララックスのズレを解消）
        final playerX = game.player.position.x;
        background.position.x += -playerX * background.parallaxEffect;

        debugPrint(
            'AbstractOutdoorScene: GameStageComponent ${bgData.imagePath} added and synced.');
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

    // 5. 技術アーキテクチャ（MVCモデル）
    // ...
    
    // ステージとルートの対応マップ
    final currentRouteId = MissionManager.stageToRoute[sceneId];
    // 「完全に完了（ロケット発射済み）」しているかどうかの判定
    bool isCompleted = (currentRouteId != null && state.completedRouteIds.contains(currentRouteId));
    
    // Stage 1 の特殊判定: パーツ3つと希少な鉱石を持ってトランクにインタラクトするとクリア
    if (sceneId == 'outdoor_1') {
      isCompleted = state.completedRouteIds.contains(GameRuntimeState.routeNormal);
    }

    // Stage 6 (Despair) ではオートプレイを開始 (Efficiency属性のみ)
    if (sceneId == 'outdoor_despair') {
      final currentAttr = state.activeRouteId ?? game.missionManager.getCurrentAttribute();
      if (currentAttr == GameRuntimeState.routeEfficiency && state.scenarioCount > 1) {
        state.isAutoPlay = true;
        game.windowManager.showDialog(
          ["「……個の維持に失敗。オートプレイ・プロトコルを開始します。」"],
        );
      } else {
        state.isAutoPlay = false;
      }
    } else if (sceneId == 'outdoor_true') {
      state.isAutoPlay = false; // 覚醒時は操作奪還
    }

    // Stationの初期化
    if (currentSceneBuildingDefinitions.containsKey('station')) {
      final definition = currentSceneBuildingDefinitions['station']!;
      
      // 現在のステージ番号を取得
      int currentStageNum;
      if (sceneId == 'outdoor_philosophy') {
        currentStageNum = 5;
      } else if (sceneId == 'outdoor_despair' || sceneId == 'outdoor_true') {
        currentStageNum = 6;
      } else {
        currentStageNum = int.tryParse(sceneId.split('_').last) ?? 1;
      }

      // 帰還（ロケット発射）完了済みのステージ、かつ despair/true でない場合に駅を表示
      bool shouldAddStation = isCompleted && 
          sceneId != 'outdoor_despair' && 
          sceneId != 'outdoor_true';
      
      // 特殊ケース：全ルートクリア後などは駅を置いても良いかもしれないが、現状は上記に従う
      
      if (shouldAddStation) {
        station = Station(
          position: Vector2(
            -MyGame.worldWidth,
            game.initialGameCanvasSize.y - definition.defaultSize.y,
          ),
        )..priority = 5;
        buildings.add(station!);
        await add(station!);
        
        // 駅にインタラクトで「次のシーン」へ移動
        station!.add(InteractHitbox(
          position: Vector2(0, 0),
          size: station!.size,
        onInteract: () async {
          // 次のステージIDを決定
          int nextStageNum = currentStageNum + 1;
          String nextStageId = 'outdoor_$nextStageNum';
          
          if (nextStageNum == 5) {
            nextStageId = 'outdoor_philosophy';
          } else if (nextStageNum == 6) {
            // Stage 6 (最終定義ステージ) への移行時に属性を確定させる
            game.missionManager.finalizeRoute();

            // 分岐ロジック（Despair または True）
            bool isSubScenario = true;
            for (int i = 1; i <= 4; i++) {
              if (!state.subRouteConfirmedStages.contains('outdoor_$i')) {
                isSubScenario = false;
                break;
              }
            }
            nextStageId = isSubScenario ? 'outdoor_true' : 'outdoor_despair';
          }

          // 次のステージの配置をリセット（初めて訪れるか、電車移動時のみ）
          state.buildingPlacements.remove(nextStageId);

          // シナリオ1の場合は、ステージ移動時にスコアや状態をリセットする
          if (state.scenarioCount == 1) {
            state.resetStageState();
          }

          final resetPos = Vector2(-50, game.initialGameCanvasSize.y - game.player.size.y / 2);
          await game.sceneManager.loadScene(nextStageId, initialPlayerPosition: resetPos);
          // シーンロード後に羅針盤メッセージを表示
          game.missionManager.showCompassMessage(nextStageId, showWindow: true);
        },
          icon: Icons.train,
        ));
        debugPrint('AbstractOutdoorScene: Station added to move to next stage.');
      }
    }

    // ロケットの初期化
    bool shouldAddRocket = false;
    Vector2 rocketPos = Vector2(-MyGame.worldWidth, game.initialGameCanvasSize.y - 256);

    // まだ帰還（ロケット発射）していない場合、または despair/true の場合にロケットを表示
    if (!isCompleted || sceneId == 'outdoor_despair' || sceneId == 'outdoor_true') {
      shouldAddRocket = true;
      
      // シーン別の位置調整
      if (sceneId == 'outdoor_true') {
        // Trueエンドでは中央に配置
        rocketPos.x = -MyGame.worldWidth / 2 - 128; // 128はロケットの幅の半分くらいの調整
      } else if (sceneId == 'outdoor_despair') {
        // Despairエンドでは左端に配置（デフォルトのまま、無視して右の崖へ向かう）
        rocketPos.x = -MyGame.worldWidth;
      }
    }

    if (shouldAddRocket) {
      rocket = AbandonedRocket(position: rocketPos)..priority = 5;
      await add(rocket!);
      debugPrint('AbstractOutdoorScene: AbandonedRocket added at $sceneId at position ${rocketPos.x}.');
    }

    // Stage 3 ギミック：家具の配置（屋内シーンで行うのが本来だが、テスト用に屋外にも置けるようにするか検討）
    // 本来は各 InteriorScene の initializeScene で行うべき

    // コレクションアイテムのランダム配置
    if (sceneId.startsWith('outdoor')) {
      final random = Random();
      final collectionItems = ['バルブ', '点火装置', 'ノズル'];
      
      // Stage 1 の場合は「石」を追加
      if (sceneId == 'outdoor_1') {
        collectionItems.add('石');
      }
      
      // Stage 3 の場合は「棒」も追加
      if (sceneId == 'outdoor_2' || sceneId == 'outdoor_3') {
        collectionItems.add('棒');
      }
      
      // Stage 6 (Despair/True) の場合はそれぞれの属性別キーアイテムも配置
      if (sceneId == 'outdoor_despair') {
        final attr = state.activeRouteId ?? game.missionManager.getCurrentAttribute();
        switch (attr) {
          case GameRuntimeState.routeNormal: collectionItems.add('最終調査報告書'); break;
          case GameRuntimeState.routeViolence: collectionItems.add('殲滅完了コード'); break;
          case GameRuntimeState.routeEmpathy: collectionItems.add('心のバックアップ'); break;
          case GameRuntimeState.routePhilosophy: collectionItems.add('真実へのアクセスキー'); break;
          case GameRuntimeState.routeEfficiency: collectionItems.add('最適化完了ログ'); break;
          default: collectionItems.add('最終調査報告書');
        }
      } else if (sceneId == 'outdoor_true') {
        collectionItems.add('中枢演算コア');
      }

      for (final itemName in collectionItems) {
        // すでに所持している場合はスポーンさせない
        if (game.player.itemBag.getItemCount(itemName) > 0) continue;

        // -1900から0の範囲でランダムなX座標を生成
        final randomX = (random.nextDouble() * 1900) * -1;
        final item = ItemFactory.createItemByName(
          itemName,
          Vector2(randomX, game.initialGameCanvasSize.y - 25),
        );
        if (item != null) {
          await add(item);
          debugPrint('AbstractOutdoorScene: $itemName spawned at ($randomX, ${game.initialGameCanvasSize.y - 100}), priority: ${item.priority}');
        }
      }
    }

    final buildingTypesInScene = (isEfficiencyFlattened && sceneId != 'outdoor_1')
        ? [] // 効率化ルート確定時は建物を配置しない（平坦な世界）、ただしStage 1は除く
        : currentSceneBuildingDefinitions.keys
            .where((key) => key != 'station')
            .toList();
    
    // 建物配置の永続化チェック
    final scenePlacements = state.buildingPlacements[sceneId];
    final bool hasExistingPlacements = scenePlacements != null && scenePlacements.isNotEmpty;
    
    // 建物のランダム配置用
    final random = Random();
    final List<Rect> occupiedRanges = [];
    final double minX = -2000.0;
    final double maxX = -300.0;

    for (final type in buildingTypesInScene) {
      final definition = currentSceneBuildingDefinitions[type]!;
      
      Vector2 buildingPos = Vector2.zero();
      bool foundPosition = false;
      
      if (hasExistingPlacements && scenePlacements.containsKey(type)) {
        // 保存された配置がある場合はそれを使用
        buildingPos = Vector2(scenePlacements[type]!, game.initialGameCanvasSize.y - definition.defaultSize.y);
        occupiedRanges.add(Rect.fromLTWH(buildingPos.x, 0, definition.defaultSize.x + 50, definition.defaultSize.y));
        foundPosition = true;
      } else {
        // かぶらない位置を探す（最大50回試行）
        for (int attempt = 0; attempt < 50; attempt++) {
          final x = minX + random.nextDouble() * (maxX - minX);
          final potentialRect = Rect.fromLTWH(x, 0, definition.defaultSize.x + 50, definition.defaultSize.y);
          
          bool overlaps = false;
          for (final rect in occupiedRanges) {
            if (potentialRect.overlaps(rect)) {
              overlaps = true;
              break;
            }
          }
          
          if (!overlaps) {
            buildingPos = Vector2(x, game.initialGameCanvasSize.y - definition.defaultSize.y);
            occupiedRanges.add(potentialRect);
            foundPosition = true;
            
            // 新しい配置を保存
            state.buildingPlacements[sceneId] ??= {};
            state.buildingPlacements[sceneId]![type] = x;
            break;
          }
        }
      }

      if (!foundPosition) {
        debugPrint('AbstractOutdoorScene: Could not find position for $type');
        continue;
      }

      Building building;
      switch (type) {
        case 'sushi':
          building = Sushi(position: buildingPos);
          break;
        case 'cafe':
          building = Cafe(position: buildingPos);
          break;
        case 'burger_store':
          building = BurgerStore(position: buildingPos);
          break;
        case 'shop':
          building = Shop(
            position: buildingPos,
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
    int walkingEnemyCount = (isEfficiencyFlattened && sceneId != 'outdoor_1') ? 0 : 10;
    int carEnemyCount = (isEfficiencyFlattened && sceneId != 'outdoor_1') ? 0 : 1;

    if (sceneId == 'outdoor_2' || isViolenceAggressive) {
      walkingEnemyCount = 20; // Violence属性が高い、またはStage 2は敵を増やす
      carEnemyCount = 3;
    }

    for (int i = 0; i < walkingEnemyCount; i++) {
      final walkingEnemy = enemyManager!.createEnemyOnLoad(isWalkingEnemy: true);
      await add(walkingEnemy);
      debugPrint('AbstractOutdoorScene: Walking enemy ${i} added.');
    }

    for (int i = 0; i < carEnemyCount; i++) {
      final carEnemy = enemyManager!.createEnemyOnLoad(isWalkingEnemy: false);
      await add(carEnemy);
      debugPrint('AbstractOutdoorScene: Car enemy ${i} added.');
    }
    debugPrint('AbstractOutdoorScene: All enemies added.');

    // ライトの初期化
    final double testLightRadius = 60.0;
    final Vector2 testLightSize = Vector2(
      testLightRadius * 2,
      testLightRadius * 2,
    );

    // デフォルトの座標ではなく、実際に配置された建物の座標を使用する
    for (final building in buildings) {
      if (building is Station) continue; // 駅は別途処理

      final testLight = LightComponent(
        position: Vector2(building.position.x + building.size.x / 2, game.initialGameCanvasSize.y - building.size.y - 50.0),
        size: testLightSize,
        lightRadius: testLightRadius,
        lightColor: const Color.fromARGB(255, 255, 255, 200),
        lightIntensity: 0.8,
      );
      add(testLight);
      debugPrint('AbstractOutdoorScene: Light added at building position: ${building.position.x}.');
    }
    debugPrint('AbstractOutdoorScene: All building lights added.');

    // 建物から出てきた場合のプレイヤー位置調整
    if (game.gameRuntimeState.currentBuildingType != null) {
      final String exitedBuildingType = game.gameRuntimeState.currentBuildingType!;
      final Building? exitedBuilding = buildings.firstWhere(
        (b) => b.type == exitedBuildingType,
        orElse: () => buildings.first, // 見つからない場合は最初の建物（念のため）
      );

      if (exitedBuilding != null) {
        final definition = currentSceneBuildingDefinitions[exitedBuildingType] ?? currentSceneBuildingDefinitions.values.first;
        final Vector2 exitPos = definition.exitPointCalculator(
          exitedBuilding.position,
          exitedBuilding.size,
          game.player.size,
          game.initialGameCanvasSize,
        );
        game.player.teleportTo(exitPos);
        debugPrint('AbstractOutdoorScene: Player teleported to exited building ($exitedBuildingType) at $exitPos');
        
        // 建物情報をクリア
        game.gameRuntimeState.currentBuildingType = null;
        game.gameRuntimeState.currentBuildingPositionX = null;
        game.gameRuntimeState.currentBuildingPositionY = null;
      }
    } else {
      // 通常のロード時
      // Stage 3 効率ルート確定時の「平坦化」リロード時はワープを避ける
      final bool isEfficiencyFlattening = sceneId == 'outdoor_3' && 
          state.activeRouteId == GameRuntimeState.routeEfficiency &&
          initialPlayerPosition != null;

      if (isEfficiencyFlattening) {
        debugPrint('AbstractOutdoorScene: Efficiency flattening detected. Keeping current position.');
        // positionのセットのみ行い、カメラリセットを伴うteleportToは避ける
        game.player.position.setFrom(initialPlayerPosition!);
      } else {
        final Vector2 targetPos = initialPlayerPosition ??
            Vector2(-50, game.initialGameCanvasSize.y - game.player.size.y / 2);
        game.player.teleportTo(targetPos); // 背景パララックスのリセット
      }
    }
    
    game.player.priority = 50;
    game.player.unbeatable = false;

    game.player.setPhysicsBehavior(
      applyGravity: true,
      enableHorizontalPhysics: true,
      enableVerticalMovement: true,
    );

    // NPCの配置
    _spawnNpc();
    
    // 破壊可能オブジェクトの配置
    _spawnDestructibles();

    debugPrint('AbstractOutdoorScene initializeScene complete');
  }

  void _spawnDestructibles() async {
    try {
      final state = game.gameRuntimeState;

      final worldAttr =
          state.lastSimulatedAttribute ?? GameRuntimeState.routeNormal;
      final worldRedundancy = state.attributeRedundancy[worldAttr] ?? 0;
      final int worldLevel = state.completedRouteIds.contains(worldAttr)
          ? (2 + worldRedundancy).clamp(0, 3)
          : 0;

      // 効率化ルートが既に確定している場合、または前周回で確定している場合は配置しない（平坦な世界）
      final bool isEfficiencyFlattened =
          (worldAttr == GameRuntimeState.routeEfficiency && worldLevel >= 2) ||
              (state.activeRouteId == GameRuntimeState.routeEfficiency &&
                  sceneId == 'outdoor_3');

      if (isEfficiencyFlattened && sceneId != 'outdoor_1') {
        return;
      }

      // 仮の配置（等間隔に配置）
      for (int i = 0; i < 5; i++) {
        final x = -400.0 - (i * 300.0);
        final sprite = await game.loadSprite('CITY_MEGA.png', srcPosition: Vector2(1812, 368), srcSize: Vector2(24, 32));
        final obj = DestructibleObject(
          type: DestructibleType.street,
          itemName: '棒',
          uniqueId: '${sceneId}_street_$i', // IDを永続化
          position: Vector2(x, game.initialGameCanvasSize.y),
          size: Vector2(54, 72),
          sprite: sprite,
        );
        obj.priority = 4;
        destructibles.add(obj); // リストに追加
        add(obj);
      }
    } catch (e) {
      debugPrint('AbstractOutdoorScene: ERROR in _spawnDestructibles: $e');
    }
  }

  void _spawnGhostEchoes() {
    final state = game.gameRuntimeState;
    final colors = {
      GameRuntimeState.routeNormal: Colors.white, // Normal（1周目）も記録として追加
      GameRuntimeState.routeViolence: Colors.redAccent,
      GameRuntimeState.routeEfficiency: Colors.blueAccent,
      GameRuntimeState.routeEmpathy: Colors.orange,
      GameRuntimeState.routePhilosophy: Colors.greenAccent,
    };

    int i = 0;
    colors.forEach((attr, color) {
      // クリア済みのルート、またはNormal（1周目完了後なら必ずある）のみ表示
      if (state.completedRouteIds.contains(attr)) {
        final ghost = GhostEcho(
          attribute: attr,
          color: color,
          position: Vector2(-MyGame.worldWidth + 400 + (i * 100.0), game.initialGameCanvasSize.y - 32),
          size: Vector2(32, 32),
        );
        ghost.priority = 35;
        add(ghost);
        i++;
      }
    });
  }

  void _spawnNpc() {
    final state = game.gameRuntimeState;
    final worldAttr = state.lastSimulatedAttribute ?? GameRuntimeState.routeNormal;
    final worldRedundancy = state.attributeRedundancy[worldAttr] ?? 0;
    final int worldLevel = state.completedRouteIds.contains(worldAttr) ? (2 + worldRedundancy).clamp(0, 3) : 0;

    // 効率化ルートが既に確定している場合は、NPCを配置しない（平坦な世界）
    if ((worldAttr == GameRuntimeState.routeEfficiency && worldLevel >= 2 && sceneId != 'outdoor_1') ||
        (state.activeRouteId == GameRuntimeState.routeEfficiency && sceneId == 'outdoor_3')) {
      return;
    }

    // シナリオ2以降のStage 1開始時に「過去の自分の残影（Ghost Echoes）」を表示
    if (state.scenarioCount >= 2 && sceneId == 'outdoor_1') {
      _spawnGhostEchoes();
    }

    if (sceneId == 'outdoor_4') {
      // ステージ4では3体のNPCを配置
      for (int i = 0; i < 3; i++) {
        final npc = Npc(
          name: '住民${i + 1}',
          talkMessages: ["「希少な鉱石……希少な鉱石があれば……」"],
          giftResponse: "",
          uniqueId: 'stage4_npc_$i',
          position: Vector2(-400 - (i * 400.0), game.initialGameCanvasSize.y),
          size: Vector2(32, 32),
        );
        npc.priority = 40;
        add(npc);
      }
    } else {
      // その他のステージでは1体のNPCを配置
      final npc = Npc(
        name: '通行人',
        talkMessages: [
          "「いい天気だねぇ。」",
          "「君、見慣れない顔だね。どこから来たんだい？」",
        ],
        giftResponse: "「ほう、珍しいものを持ってるね。大事に使うよ。」",
        uniqueId: 'generic_npc_$sceneId',
        position: Vector2(-500, game.initialGameCanvasSize.y),
        size: Vector2(32, 32),
      );
      npc.priority = 40;
      add(npc);
    }
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

    if (!game.player.inUnderGround) {
      game.player.canDig = _underGround?.isPlayerNearDiggableEntrance(
        game.player.absoluteCenter,
      ) ?? false; // nullチェックを追加
      if (game.player.canDig) {
        GameUI.setDigButtonState(ActionButtonState.notice);
      } else {
        GameUI.setDigButtonState(ActionButtonState.disabled);
      }
    } else {
      game.player.canDig = true;
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
