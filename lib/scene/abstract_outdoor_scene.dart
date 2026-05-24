import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/world_scale.dart';
import '../system/storage/game_runtime_state.dart';
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
import '../component/game_stage/building/apartment.dart';
import '../component/enemy/enemy_manager.dart';
import '../component/enemy/walking_enemy.dart';
import '../component/enemy/car_enemy.dart';
import '../component/common/ground/ground.dart';
import '../component/common/underground/underground.dart';
import '../component/game_stage/gamestage_component.dart';
import '../component/game_stage/lighting/sky_component.dart';
import '../component/game_stage/lighting/ambient_lighting_utils.dart';
import 'game_scene.dart';
import '../UI/game_ui.dart';
import '../component/game_stage/lighting/lighting_bake_coordinator.dart';
import '../component/game_stage/lighting/lighting_world.dart';
import '../component/game_stage/building/abandoned_rocket.dart';
import '../component/game_stage/building/building_definitions.dart';
import '../component/game_stage/building/destructible_object.dart';
import '../component/vehicle/train.dart';
import '../component/common/hitboxes/interact_hitbox.dart';
import '../component/item/item.dart';
import '../component/effect/guidance_arrow.dart';
import '../component/effect/erosion_effect.dart';
import 'dart:math';

/// ゴーストエコー表示色（v8.3 [GameRuntimeState] のマクロID）
const Map<String, Color> _ghostEchoPalette = {
  'normal': Colors.white,
  GameRuntimeState.macroRouteNourishment: Colors.tealAccent,
  GameRuntimeState.macroRouteDestroy: Colors.redAccent,
  GameRuntimeState.macroRouteNormal: Colors.blueGrey,
  GameRuntimeState.macroRouteTrue: Colors.amberAccent,
};

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
  late final LightingWorld lightingWorld;
  double gravityMultiplier = 1.0;

  final String sceneId;
  final Vector2? initialPlayerPosition;

  static double get underGroundHeight => UnderGround.underGroundHeight;

  AbstractOutdoorScene({required this.sceneId, this.initialPlayerPosition})
    : super(); // コンストラクタからunderGroundの初期化を削除

  // 電車をスポーンさせるメソッド (基底クラスで定義)
  void spawnTrain() {
    if (station == null) {
      debugPrint('Station is not yet initialized in $sceneId.');
      return;
    }
    final train = Train(
      position: Vector2(0, station!.position.y + station!.size.y),
      station: station!,
    )..priority = 3; // 建物(priority: 5)より奥に描画される
    add(train);
    debugPrint('Spawned a new train in $sceneId.');
  }

  @override
  Future<void> onLoad() async {
    debugPrint('AbstractOutdoorScene: onLoad started.');
    // playerのpriorityをシーンのonLoadで設定
    game.player.priority = 50;
    debugPrint('AbstractOutdoorScene: Player priority set to 50.');

    // skyBackgroundComponentの初期化と追加
    lightingWorld = LightingWorld(timeService: game.timeService);

    skyBackgroundComponent = SkyComponent(timeService: game.timeService)
      ..priority = 1;
    await add(skyBackgroundComponent!);

    // 環境侵食エフェクトを追加（starAlertLevel >= 6 で自動起動）
    add(ErosionEffect());

    // enemyManagerの初期化
    enemyManager = EnemyManager(game);
    debugPrint('AbstractOutdoorScene: EnemyManager initialized.');

    // groundの初期化と追加
    final groundSprite = await Sprite.load('concrete_ground.png');
    debugPrint('AbstractOutdoorScene: groundSprite loaded.');
    
    // ground: 旧4属性ティントは廃止（スプライトのみ）

    // ワールド幅より左右に広げ、敵スポーン付近や端の探索でも床が途切れないようにする
    ground = Ground(
      groundWidth: WorldScale.extendedWorldWidth,
      groundHeight: groundHeight,
      position: Vector2(
        WorldScale.extendedWorldLeft,
        game.initialGameCanvasSize.y,
      ),
      groundSprite: groundSprite,
      loop: true,
      overlayColor: null,
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

    await add(
      LightingBakeCoordinator(timeService: game.timeService),
    );
    debugPrint(
      'AbstractOutdoorScene: Per-component dark curtain + bake coordinator.',
    );

    debugPrint('AbstractOutdoorScene: onLoad finished.');
  }

  @override
  Future<void> initializeScene(dynamic data) async {
    debugPrint('AbstractOutdoorScene: initializeScene started.');
    final state = game.gameRuntimeState;

    debugPrint(
      'AbstractOutdoorScene initializeScene start. scenarioCount: ${state.scenarioCount}',
    );

    // 背景の初期化
    final outdoorBackgrounds = backgroundDataMap[sceneId];
    if (outdoorBackgrounds != null) {
      for (final bgData in outdoorBackgrounds) {
        final background = GameStageComponent(data: bgData, loop: true)
          ..priority = bgData.resolveRenderPriority();
        await add(background);
        background.resetPositions(game.initialGameCanvasSize);

        debugPrint(
            'AbstractOutdoorScene: GameStageComponent ${bgData.imagePath} added and synced.');
      }
    }
    debugPrint('AbstractOutdoorScene: Backgrounds initialized.');
    game.cameraController.syncBackgroundParallaxFromCamera();
    game.cameraController.syncDepthZoom();

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
    

    // Stage 6 (Despair)：旧 efficiency 系オートプレイは廃止
    if (sceneId == 'outdoor_despair') {
      state.isAutoPlay = false;
    } else if (sceneId == 'outdoor_true') {
      state.isAutoPlay = false; // 覚醒時は操作奪還
    }

    // Stationの初期化
    if (currentSceneBuildingDefinitions.containsKey('station')) {
      final definition = currentSceneBuildingDefinitions['station']!;

      // Stage 0 (Prologue)・despair・true 以外のステージは常時駅を表示する。
      // ロケットははぐれたベテラン調査員の元にあるため、通常ステージには存在しない。
      // 駅はステージ間移動の手段として、カーゴ射出後に電車が来る仕組みで運用する。
      bool shouldAddStation =
          sceneId != 'outdoor_0' &&
          sceneId != 'outdoor_despair' &&
          sceneId != 'outdoor_true';
      
      if (shouldAddStation) {
        station = Station(
          position: Vector2(
            -MyGame.worldWidth,
            game.initialGameCanvasSize.y - definition.defaultSize.y,
          ),
        )..priority = 5;
        buildings.add(station!);
        await add(station!);
        
        // 駅にインタラクトで「次のシーン」へ移動（カーゴ射出後のみ電車が来る）
        station!.add(InteractHitbox(
          position: Vector2(0, 0),
          size: station!.size,
        onInteract: () async => game.advanceOutdoorStageViaTrain(),
          icon: Icons.train,
        ));
        debugPrint('AbstractOutdoorScene: Station added to move to next stage.');
      }
    }

    // ロケットの初期化
    // ロケットははぐれたベテラン調査員の元にあるため、
    // プロローグ（outdoor_0）とトゥルーエンド（outdoor_true）にのみ配置する。
    // 通常ステージ（outdoor_1〜4、philosophy、despair）には配置しない。
    bool shouldAddRocket = false;
    Vector2 rocketPos = Vector2(-MyGame.worldWidth, game.initialGameCanvasSize.y);

    if (sceneId == 'outdoor_0') {
      shouldAddRocket = true;
      rocketPos.x = -2500.0;
    } else if (sceneId == 'outdoor_true') {
      shouldAddRocket = true;
      rocketPos.x = -MyGame.worldWidth / 2 - 128;
    }

    if (shouldAddRocket) {
      rocket = AbandonedRocket(position: rocketPos)..priority = 5;
      await add(rocket!);
      if (sceneId == 'outdoor_true') {
        rocket!.add(
          InteractHitbox(
            position: Vector2.zero(),
            size: rocket!.size,
            onInteract: () async {
              final st = game.gameRuntimeState;
              if (!st.canStartTrueDeepSequence) {
                game.windowManager.showDialog([
                  'ロケットは静かだ。',
                  '（深層へ向かう条件が整っていない）',
                ]);
                return;
              }
              st.trueSequencePhase = 1;
              await st.saveGame();
              final resetPos = Vector2(
                -100,
                game.initialGameCanvasSize.y - game.player.size.y / 2,
              );
              await game.sceneManager.loadScene(
                'outdoor_true_corridor',
                initialPlayerPosition: resetPos,
              );
            },
            icon: Icons.hub_outlined,
          ),
        );
      }
      debugPrint('AbstractOutdoorScene: AbandonedRocket added at $sceneId at position ${rocketPos.x}.');
    }

    // Stage 3 ギミック：家具の配置（屋内シーンで行うのが本来だが、テスト用に屋外にも置けるようにするか検討）
    // 本来は各 InteriorScene の initializeScene で行うべき

    // コレクションアイテムのランダム配置
    if (sceneId.startsWith('outdoor')) {
      final random = Random();
      final collectionItems = [];
      
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
        collectionItems.add('最終調査報告書');
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

    final buildingTypesInScene = currentSceneBuildingDefinitions.keys
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
        case 'apartment':
          building = Apartment(position: buildingPos);
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
    int walkingEnemyCount = sceneId == 'outdoor_0' ? 0 : 10;
    int carEnemyCount = sceneId == 'outdoor_0' ? 0 : 1;

    if (sceneId == 'outdoor_2') {
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

    // 建物から出てきた場合のプレイヤー位置調整
    if (game.gameRuntimeState.currentBuildingType != null) {
      final String exitedBuildingType = game.gameRuntimeState.currentBuildingType!;
      Building? exitedBuilding;
      
      try {
        exitedBuilding = buildings.firstWhere(
          (b) => b.type == exitedBuildingType,
        );
      } catch (_) {
        // 見つからない場合は null のまま
      }

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
      final Vector2 targetPos = initialPlayerPosition ??
          Vector2(-100, game.initialGameCanvasSize.y - game.player.size.y / 2);
      game.player.teleportTo(targetPos); // 背景パララックスのリセット
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
      if (sceneId == 'outdoor_true_corridor' || sceneId == 'outdoor_true_vault') {
        return;
      }

      if (sceneId == 'outdoor_true_finale') {
        final sprite = await game.loadSprite(
          'CITY_MEGA.png',
          srcPosition: Vector2(1812, 368),
          srcSize: Vector2(48, 64),
        );
        final obj = DestructibleObject(
          type: DestructibleType.wall,
          itemName: '石',
          uniqueId: 'outdoor_true_finale_barrier',
          position: Vector2(-500, game.initialGameCanvasSize.y),
          size: sprite!.srcSize,
          sprite: sprite,
        );
        obj.priority = 4;
        destructibles.add(obj);
        add(obj);
        return;
      }

      // 仮の配置（等間隔に配置）
      for (int i = 0; i < 5; i++) {
        final x = -400.0 - (i * 300.0);
        // TODO: 画像挿入 (破壊可能オブジェクト)
        final sprite = await game.loadSprite('CITY_MEGA.png', srcPosition: Vector2(1812, 368), srcSize: Vector2(24, 32));
        final obj = DestructibleObject(
          type: DestructibleType.street,
          itemName: '棒',
          uniqueId: '${sceneId}_street_$i', // IDを永続化
          position: Vector2(x, game.initialGameCanvasSize.y),
          size: sprite!.srcSize,
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

  void spawnGhostEchoes() {
    final state = game.gameRuntimeState;
    const ordered = [
      GameRuntimeState.macroRouteNourishment,
      GameRuntimeState.macroRouteDestroy,
      GameRuntimeState.macroRouteNormal,
      GameRuntimeState.macroRouteTrue,
    ];
    var i = 0;
    for (final routeId in ordered) {
      if (!state.completedMacroRoutes.contains(routeId)) continue;
      final color = _ghostEchoPalette[routeId] ?? Colors.white70;
      final ghost = GhostEcho(
        routeId: routeId,
        color: color,
        position: Vector2(-MyGame.worldWidth + 400 + (i * 100.0), game.initialGameCanvasSize.y - 32),
      );
      ghost.priority = 35;
      add(ghost);
      i++;
    }
  }

  void _spawnNpc() {
    final state = game.gameRuntimeState;

    // シナリオ2以降のStage 0開始時に「過去の自分の残影（Ghost Echoes）」を表示
    if (state.scenarioCount >= 2 && sceneId == 'outdoor_0') {
      spawnGhostEchoes();
    }

    if (sceneId == 'outdoor_4') {
      // ステージ4では3体のNPCを配置
      for (int i = 0; i < 3; i++) {
        final npc = Npc(
          name: '住民${i + 1}',
          talkMessages: ["「希少な鉱石……希少な鉱石があれば……」"],
          giftResponse: "",
          uniqueId: 'stage4_npc_$i',
          position: Vector2(-400 - (i * 400.0),
              game.initialGameCanvasSize.y + 2),
          srcPosition: Vector2(102 , 162), // TODO: 住民用スプライト
          srcSize: Vector2(21, 30),
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
        position:
            Vector2(-500, game.initialGameCanvasSize.y + 2),
        srcPosition: Vector2(104, 108), // TODO: 通行人用スプライト
        srcSize: Vector2(16, 20),
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

  @Deprecated('掘削は Player._tickDigCarve → UnderGround.carveCapsule が担当')
  void updateDigAreas(Player player) {}

  bool isDug(Vector2 position) {
    return _underGround?.isDug(position) ?? false; // nullチェックを追加
  }

  @override
  void onRemove() {
    skyBackgroundComponent?.removeFromParent();
    skyBackgroundComponent = null;
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 依存ルートの演出：誘導矢印の表示
    if (game.gameRuntimeState.isDependencyOverloadForUi && rocket != null) {
      if (children.whereType<GuidanceArrow>().isEmpty) {
        add(GuidanceArrow(target: rocket!));
      }
    }

    // TODO: 視覚演出の更新ロジックの再設計
    _updateVisualEffects(dt);

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

    // プロローグ以外で敵をスポーン
    if (sceneId != 'outdoor_0') {
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

  void _updateVisualEffects(double dt) {
    _updateAmbientWorldTint();
  }

  void _updateAmbientWorldTint() {
    if (game.player.inUnderGround) {
      _clearAmbientWorldTint();
      return;
    }

    final sky = skyBackgroundComponent;
    if (sky == null) {
      _clearAmbientWorldTint();
      return;
    }

    final worldTint = AmbientLightingUtils.computeWorldTint(
      sky.currentSkyColor,
      sky.currentAmbientBrightness,
      hour: game.timeService.hour,
      minute: game.timeService.minute,
    );

    ground?.overlayColor = worldTint;
  }

  void _clearAmbientWorldTint() {
    ground?.overlayColor = null;
    game.player.setAmbientColorFilter(null);
  }
}
