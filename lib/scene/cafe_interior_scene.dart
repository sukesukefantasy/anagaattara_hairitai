import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flame/collisions.dart';
import '../main.dart';
import '../component/player.dart';
import '../UI/window_manager.dart';
import 'game_scene.dart';
import '../component/game_stage/building/building.dart';
import '../UI/game_ui.dart';
import '../component/common/ground/ground.dart';
import '../component/game_stage/building/building_data.dart';
import '../component/game_stage/gamestage_component.dart';
import '../component/game_stage/building/building_definitions.dart'; // BuildingDefinitionsをインポート

class CafeInteriorScene extends GameScene {
  final Building? _enteredBuilding;
  Vector2? _initialPlayerPosition;
  late final Ground? _ground;
  bool _isShowingExitAction = false;
  GameStageComponent? _backgroundComponent;

  final String? _buildingTypeFromSave; // セーブデータからロードされた建物のタイプ
  final Vector2? _buildingOutdoorPositionFromSave; // セーブデータからロードされた建物の屋外での位置
  final String? _outdoorSceneIdFromSave; // セーブデータからロードされた屋外シーンのID

  CafeInteriorScene({
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

  @override
  double get groundHeight => 50.0;

  @override
  Future<void> initializeScene(dynamic data) async {
    // 背景の追加
    final interiorBackgrounds = backgroundDataMap['cafe_interior'];
    debugPrint('CafeInteriorScene: interiorBackgrounds: $interiorBackgrounds');
    if (interiorBackgrounds != null && interiorBackgrounds.isNotEmpty) {
      final bgData = interiorBackgrounds.first;
      _backgroundComponent = GameStageComponent(
        data: bgData,
        isScrollForward: true,
      );
      await add(_backgroundComponent!);
      _backgroundComponent!.resetPositions(
        game.initialGameCanvasSize,
      );
      debugPrint('CafeInteriorScene: _backgroundComponent initialized.');
    } else {
      debugPrint('CafeInteriorScene: No interior background data found.');
    }

    // 初期プレイヤー位置の設定（背景コンポーネントの初期化後に調整）
    if (_backgroundComponent == null) {
      debugPrint('CafeInteriorScene: _backgroundComponent is NULL, cannot set initial player position based on it.');
      // _backgroundComponentがnullの場合の代替処理、例えばデフォルト位置を設定するか、エラーを出すか
      _initialPlayerPosition ??= Vector2(70, game.initialGameCanvasSize.y - game.player!.size.y / 2);
    } else {
      _initialPlayerPosition ??= Vector2(
        70,
        _backgroundComponent!.position.y + _backgroundComponent!.size.y - game.player!.size.y / 2, // プレイヤーの足元を背景の下端に合わせる
      );
    }
    debugPrint('CafeInteriorScene: _initialPlayerPosition: $_initialPlayerPosition');
    debugPrint('CafeInteriorScene: game.player: ${game.player}');
    if (game.player == null) {
      debugPrint('CafeInteriorScene: game.player is NULL.');
    }

    debugPrint(
      'CafeInteriorScene initializeScene start for cafe: ${_enteredBuilding?.toString()}',
    );

    // 地面を追加
    final interiorGroundSprite = await Sprite.load('concrete_ground.png');
    _ground = Ground(
      groundWidth: _backgroundComponent!.size.x,
      groundHeight: groundHeight,
      position: Vector2(
        0,
        _backgroundComponent!.position.y + _backgroundComponent!.size.y,
      ),
      groundSprite: interiorGroundSprite,
      isScrollForward: true,
    )..priority = 1;
    await add(_ground!);
    game.sceneManager.currentScene!.groundComponent = _ground;
    debugPrint('Ground position: ${_ground!.position}, size: ${_ground!.size}');

    // インタラクト可能オブジェクト（例: カウンター）をカスタムコンポーネントに変更
    final scale =
        _backgroundComponent!.size.x / _backgroundComponent!.data.srcSize.x;
    final counterComponent = _InteriorCounter(
      sprite: await Sprite.load(
        'CITY_MEGA.png',
        srcPosition: Vector2(1040, 816),
        srcSize: Vector2(104, 32),
      ),
      position: Vector2(
        _backgroundComponent!.position.x +
            (48 * scale),
        _backgroundComponent!.position.y +
            (32 * scale),
      ),
      size: Vector2(104 * scale, 32 * scale),
    )..priority = 40;
    await add(counterComponent);
    debugPrint(
      'Counter position: ${counterComponent.position}, size: ${counterComponent.size}',
    );

    // プレイヤーの初期位置を設定
    game.player!.position = _initialPlayerPosition!;
    game.player!.priority = 50;
    game.player!.unbeatable = false;
    // await add(game.player!); // CafeInteriorSceneの子としてプレイヤーを追加

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
      'CafeInteriorScene initializeScene complete for cafe: ${_enteredBuilding?.toString()}',
    );
    debugPrint(
      'GameStageComponent position: ${_backgroundComponent!.position}, size: ${_backgroundComponent!.size}',
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (game.player == null || _ground == null) return;final exitAreaThreshold = game.player!.size.x;

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
            final String buildingType = _buildingTypeFromSave ?? 'cafe'; // セーブデータからのタイプを優先
            buildingDefinition = outdoorSceneDefinitions[buildingType];
          }

          if (buildingDefinition == null) {
            // 指定された屋外シーンIDの定義がない、または指定された建物タイプが見つからない場合、汎用的な出口位置を設定
            debugPrint('Warning: Building definition for ${_buildingTypeFromSave ?? 'cafe'} not found in $targetOutdoorSceneId. Placing player at a default exit point in $targetOutdoorSceneId.');
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
              final Vector2 buildingOutdoorPosition = _buildingOutdoorPositionFromSave ?? buildingDefinition.defaultOutdoorPosition;
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
      if (_isShowingExitAction) {
        GameUI.setInteractAction(null, null);
        _isShowingExitAction = false;
      }
    }
  }

  @override
  void onRemove() {
    GameUI.setInteractAction(null, null);
    if (game.player != null) {
      game.player!.setPhysicsBehavior(
        applyGravity: true,
        enableHorizontalPhysics: true,
        enableVerticalMovement: true,
      );
    }
    super.onRemove();
  }
}

class _InteriorCounter extends SpriteComponent
    with CollisionCallbacks, HasGameReference<MyGame> {
  _InteriorCounter({
    required super.sprite,
    required super.position,
    required super.size,
  });

  @override
  Future<void> onLoad() async {
    // playerのpriorityをシーンのonLoadで設定
    if (game.player != null) {
      game.player!.priority = 10; // 室内シーンでのプレイヤーのpriorityを調整
      debugPrint('CafeInteriorScene: Player priority set to 10.');
    }
    add(
      RectangleHitbox(
        size: size,
        position: Vector2.zero(),
        isSolid: true,
        collisionType: CollisionType.passive,
      ),
    );
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      debugPrint('Player collided with CafeCounter!');
      GameUI.setInteractAction(() {
        debugPrint('カフェのカウンターとインタラクトしました。');
        // TODO: カフェのインタラクト処理
      }, Icons.coffee); // カフェのアイコン
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is Player) {
      GameUI.setInteractAction(null, null);
    }
  }
} 