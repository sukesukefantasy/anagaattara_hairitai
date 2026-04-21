import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../UI/window_manager.dart';
import '../UI/windows/shop_window.dart';
import 'game_scene.dart';
import '../component/game_stage/building/building.dart'; // Buildingをインポート
import '../UI/game_ui.dart';
import '../component/common/ground/ground.dart'; // Groundクラスをインポート
import '../component/game_stage/building/building_data.dart'; // backgroundDataMapをインポート
import '../component/game_stage/gamestage_component.dart'; // BackgroundComponentをインポート
import '../component/game_stage/building/building_definitions.dart'; // BuildingDefinitionsをインポート
import '../component/common/hitboxes/interact_hitbox.dart';
import '../component/game_stage/building/destructible_object.dart';

class ShopInteriorScene extends GameScene {
  final Building? _enteredBuilding;
  Vector2? _initialPlayerPosition;
  late final Ground? _ground;
  bool _isShowingExitAction = false; // 追加: インタラクトアクションの表示状態を追跡
  GameStageComponent? _backgroundComponent; // 追加: 背景コンポーネネントを保持

  final String? _buildingTypeFromSave; // セーブデータからロードされた建物のタイプ
  final Vector2? _buildingOutdoorPositionFromSave; // セーブデータからロードされた建物の屋外での位置
  final String? _outdoorSceneIdFromSave; // セーブデータからロードされた屋外シーンのID

  ShopInteriorScene({
    Building? enteredBuilding,
    Vector2? initialPlayerPosition,
    String? buildingTypeFromSave,
    Vector2? buildingOutdoorPositionFromSave,
    String? outdoorSceneIdFromSave,
  })  : _enteredBuilding = enteredBuilding,
        _initialPlayerPosition = initialPlayerPosition,
        _buildingTypeFromSave = buildingTypeFromSave,
        _buildingOutdoorPositionFromSave = buildingOutdoorPositionFromSave,
        _outdoorSceneIdFromSave = outdoorSceneIdFromSave,
        super();

  // ショップ内部の地面の高さを定義
  @override
  double get groundHeight => 50.0;

  @override
  Future<void> initializeScene(dynamic data) async {
    debugPrint(
      'ShopInteriorScene initializeScene start for shop: ${_enteredBuilding?.toString()}',
    );

    // 背景の追加
    final shopBackgrounds = backgroundDataMap['shop_interior'];
    if (shopBackgrounds != null && shopBackgrounds.isNotEmpty) {
      // isNotEmptyを追加
      final bgData = shopBackgrounds.first; // 最初の背景データを使用
      _backgroundComponent = GameStageComponent(
        data: bgData,
        isScrollForward: true,
      );
      await add(_backgroundComponent!); // ShopInteriorSceneの子として追加
      _backgroundComponent!.resetPositions(
        game.initialGameCanvasSize,
      );
    }

    // 初期プレイヤー位置の設定（背景コンポーネントの初期化後に調整）
    _initialPlayerPosition ??= Vector2(
      70,
      _backgroundComponent!.position.y + _backgroundComponent!.size.y - game.player!.size.y / 2, // プレイヤーの足元を背景の下端に合わせる
    );

    // ショップ内部の地面を追加
    final shopGroundSprite = await Sprite.load('concrete_ground.png');
    _ground = Ground(
      groundWidth: _backgroundComponent!.size.x, // 背景の幅に合わせる
      groundHeight: groundHeight,
      position: Vector2(
        0,
        _backgroundComponent!.position.y + _backgroundComponent!.size.y,
      ),
      groundSprite: shopGroundSprite,
      isScrollForward: true,
    )..priority = 1;
    await add(_ground!);
    game.sceneManager.currentScene!.groundComponent = _ground;
    debugPrint('Ground position: ${_ground!.position}, size: ${_ground!.size}');

    // レジ（インタラクト可能）
    // 倍率
    final scale =
        _backgroundComponent!.size.x / _backgroundComponent!.data.srcSize.x;
    final counterComponent = SpriteComponent(
      sprite: await Sprite.load(
        'CITY_MEGA.png',
        srcPosition: Vector2(1792, 731), // ユーザーが変更した値を使用
        srcSize: Vector2(32, 21),
      ),
      position: Vector2(
        _backgroundComponent!.position.x +
            ((1792 - 1504) * scale), // 背景画像内の相対位置を考慮
        _backgroundComponent!.position.y +
            ((667 - 624) * scale), // 背景画像内の相対位置を考慮
      ),
      size: Vector2(32 * scale, 21 * scale),
    )..priority = 40;
    await add(counterComponent);

    counterComponent.add(InteractHitbox(
      position: Vector2.zero(),
      size: counterComponent.size,
      onInteract: () {
        debugPrint('レジとインタラクトしました。ショップウィンドウを開きます。');
        game.windowManager.showWindow(
          GameWindowType.shop,
          ShopWindow(
            windowManager: game.windowManager,
            itemBag: game.itemBag,
            game: game,
          ),
        );
      },
      icon: Icons.point_of_sale,
    ));

    debugPrint(
      'Counter position: ${counterComponent.position}, size: ${counterComponent.size}',
    );

    // Stage 3 ギミック：壊せる家具の配置
    if (game.gameRuntimeState.currentOutdoorSceneId == 'outdoor_3') {
      final furnitureSprite = await Sprite.load('CITY_MEGA.png', srcPosition: Vector2(1632, 731), srcSize: Vector2(16, 16));
      for (int i = 0; i < 5; i++) {
        await add(DestructibleObject(
          type: DestructibleType.street, // 3回ヒット
          itemName: '高密度エネルギーキューブ',
          uniqueId: 'shop_interior_furniture_$i',
          position: Vector2(200 + (i * 100), _backgroundComponent!.position.y + _backgroundComponent!.size.y - 5),
          size: Vector2(32, 32),
          sprite: furnitureSprite,
        ));
      }
    }
    game.player!.priority = 10; // 室内シーンでのプレイヤーのpriorityを調整
    game.player!.unbeatable = false;
    
    // プレイヤーの移動状態をリセット
    game.player!.isMovingLeft = false;
    game.player!.isMovingRight = false;
    game.player!.velocity.x = 0; // 水平方向の速度もリセット
    
    game.player!.setPhysicsBehavior(
      applyGravity: true,
      enableHorizontalPhysics: true,
      enableVerticalMovement: true,
    );

    debugPrint(
      'ShopInteriorScene initializeScene complete for shop: ${_enteredBuilding?.toString()}',
    );
    debugPrint(
      'GameStageComponent position: ${_backgroundComponent!.position}, size: ${_backgroundComponent!.size}',
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    // プレイヤーがショップ内部にいる間、左右の移動制限を行う
    if (game.player == null || _ground == null) return;

    // 左端の出入り口エリアの定義
    final exitAreaThreshold = 20.0; // 出口判定を小さく（20px以内）

    // 左端エリアにプレイヤーがいる場合
    if (game.player!.position.x <= exitAreaThreshold) {
      if (!_isShowingExitAction) {
        GameUI.setInteractAction(() {
          Vector2 exitTargetPosition;
          // ターゲットとなる屋外シーンIDの決定ロジックを改善
          final String targetOutdoorSceneId = game.gameRuntimeState.currentOutdoorSceneId ?? _outdoorSceneIdFromSave ?? 'outdoor'; // 修正

          Map<String, BuildingDefinition>? outdoorSceneDefinitions = BuildingDefinitions.allSceneDefinitions[targetOutdoorSceneId];
          BuildingDefinition? buildingDefinition;

          // まず、指定された屋外シーンIDと建物タイプで定義を探す
          if (outdoorSceneDefinitions != null) {
            final String buildingType = _buildingTypeFromSave ?? 'shop'; // セーブデータからのタイプを優先
            buildingDefinition = outdoorSceneDefinitions[buildingType];
          }

          if (buildingDefinition == null) {
            // 指定された屋外シーンIDの定義がない、または指定された建物タイプが見つからない場合、汎用的な出口位置を設定
            debugPrint('Warning: Building definition for ${_buildingTypeFromSave ?? 'shop'} not found in $targetOutdoorSceneId. Placing player at a default exit point in $targetOutdoorSceneId.');
            // 例えば、屋外シーンの左端、地面の高さにプレイヤーを配置
            exitTargetPosition = Vector2(game.player!.size.x, game.initialGameCanvasSize.y - (game.player!.size.y / 2));
          } else {
            // 定義が見つかった場合、通常通り出口位置を計算
            if (_enteredBuilding != null) {
              // 建物インスタンスから屋外でのドア前の位置を計算
              exitTargetPosition = buildingDefinition.exitPointCalculator(
                _enteredBuilding!.position,
                _enteredBuilding!.size,
                game.player!.size,
                game.initialGameCanvasSize, // game.initialGameCanvasSize を game.initialGameCanvasSize に変更
              );
            } else {
              // _enteredBuildingがない場合（main.dartからの直接ロードなど）、BuildingDefinitionsからデフォルト位置を取得
              final Vector2 buildingOutdoorPosition = _buildingOutdoorPositionFromSave ?? Vector2.zero();
              final Vector2 buildingSize = buildingDefinition.defaultSize;

              exitTargetPosition = buildingDefinition.exitPointCalculator(
                buildingOutdoorPosition,
                buildingSize,
                game.player!.size,
                game.initialGameCanvasSize, // game.initialGameCanvasSize を game.initialGameCanvasSize に変更
              );
            }
          }
          game.sceneManager.loadScene(targetOutdoorSceneId, data: _enteredBuilding, initialPlayerPosition: exitTargetPosition);
          GameUI.setInteractAction(null, null);
        }, Icons.exit_to_app);
        _isShowingExitAction = true;
      }
    } else {
      // 左端エリアからプレイヤーが離れた場合
      if (_isShowingExitAction) {
        GameUI.setInteractAction(null, null); // インタラクトアクションを非表示にする
        _isShowingExitAction = false;
      }
    }
  }

  @override
  void onRemove() {
    GameUI.setInteractAction(null, null); // シーンが削除されるときにアクションをクリア
    if (game.player != null) {
      // プレイヤーの物理挙動をデフォルトに戻す（屋外シーンの場合）
      game.player!.setPhysicsBehavior(
        applyGravity: true,
        enableHorizontalPhysics: true,
        enableVerticalMovement: true,
      );
    }
    super.onRemove();
  }
}

