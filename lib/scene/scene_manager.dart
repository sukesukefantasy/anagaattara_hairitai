import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../component/game_stage/building/building.dart';
import '../component/enemy/car_enemy.dart';
import '../component/game_stage/lighting/sky_component.dart';
import 'game_scene.dart';
import 'outdoor_scene.dart';
import 'abstract_outdoor_scene.dart'; // AbstractOutdoorSceneをインポート
import 'apartment_interior_scene.dart';
import 'burger_store_interior_scene.dart';
import 'cafe_interior_scene.dart';
import 'health_center_interior_scene.dart';
import 'shop_interior_scene.dart';
import 'sushi_interior_scene.dart';
import '../system/storage/game_runtime_state.dart'; // GameRuntimeStateをインポート

class SceneManager extends Component with HasGameReference<MyGame> {
  GameScene? _currentScene;
  // String? _currentOutdoorSceneId; // GameRuntimeStateに移管

  GameScene? get currentScene => _currentScene;

  String get currentSceneId => game.gameRuntimeState.currentSceneId;

  // シーン名とコンストラクタのマッピング
  late final Map<String, ({GameScene Function({dynamic data}) constructor})>
  _sceneConstructors;

  SceneManager({required MyGame game}) {
    _sceneConstructors = {
    'outdoor_1': (
      constructor: ({dynamic data}) {
        final Map<String, dynamic>? sceneData =
            data is Map ? data as Map<String, dynamic> : null;
        
        final state = game.gameRuntimeState;
        String outdoorSceneId = sceneData?['sceneId'] as String? ?? state.currentOutdoorSceneId ?? 'outdoor_1';
        
        // 分岐ロジック：特定のステージIDに対する個別の処理（必要があればここに追加）
        if (outdoorSceneId == 'outdoor_philosophy') {
          // そのままロード
        } else if (outdoorSceneId == 'outdoor_despair' || outdoorSceneId == 'outdoor_true') {
          // そのままロード
        }

        final Vector2? initialPlayerPosition =
            sceneData?['initialPlayerPosition'] as Vector2?;
        return OutdoorScene(
          sceneId: outdoorSceneId,
          initialPlayerPosition: initialPlayerPosition,
        );
      },
    ),
      'outdoor': ( // 互換性のために残すか、完全に移行
        constructor: ({dynamic data}) {
          return OutdoorScene(
            sceneId: 'outdoor_1',
            initialPlayerPosition: (data as Map?)?['initialPlayerPosition'] as Vector2?,
          );
        },
      ),
      'apartment_interior': (
        constructor: ({dynamic data}) {
          final Map<String, dynamic>? sceneData =
              data is Map ? data as Map<String, dynamic> : null;
          sceneData?['buildingType'] = 'apartment'; // buildingTypeを追加
          return ApartmentInteriorScene(
            enteredBuilding: sceneData?['building'] as Building?,
            initialPlayerPosition:
                sceneData?['initialPlayerPosition'] as Vector2?,
            buildingTypeFromSave: sceneData?['buildingTypeFromSave'] as String?,
            buildingOutdoorPositionFromSave:
                sceneData?['buildingOutdoorPositionFromSave'] as Vector2?,
            outdoorSceneIdFromSave:
                sceneData?['outdoorSceneIdFromSave'] as String?,
          );
        },
      ),
      'burger_store_interior': (
        constructor: ({dynamic data}) {
          final Map<String, dynamic>? sceneData =
              data is Map ? data as Map<String, dynamic> : null;
          sceneData?['buildingType'] = 'burger_store'; // buildingTypeを追加
          return BurgerStoreInteriorScene(
            enteredBuilding: sceneData?['building'] as Building?,
            initialPlayerPosition:
                sceneData?['initialPlayerPosition'] as Vector2?,
            buildingTypeFromSave: sceneData?['buildingTypeFromSave'] as String?,
            buildingOutdoorPositionFromSave:
                sceneData?['buildingOutdoorPositionFromSave'] as Vector2?,
            outdoorSceneIdFromSave:
                sceneData?['outdoorSceneIdFromSave'] as String?,
          );
        },
      ),
      'cafe_interior': (
        constructor: ({dynamic data}) {
          final Map<String, dynamic>? sceneData =
              data is Map ? data as Map<String, dynamic> : null;
          sceneData?['buildingType'] = 'cafe'; // buildingTypeを追加
          return CafeInteriorScene(
            enteredBuilding: sceneData?['building'] as Building?,
            initialPlayerPosition:
                sceneData?['initialPlayerPosition'] as Vector2?,
            buildingTypeFromSave: sceneData?['buildingTypeFromSave'] as String?,
            buildingOutdoorPositionFromSave:
                sceneData?['buildingOutdoorPositionFromSave'] as Vector2?,
            outdoorSceneIdFromSave:
                sceneData?['outdoorSceneIdFromSave'] as String?,
          );
        },
      ),
      'health_center_interior': (
        constructor: ({dynamic data}) {
          final Map<String, dynamic>? sceneData =
              data is Map ? data as Map<String, dynamic> : null;
          sceneData?['buildingType'] = 'health_center'; // buildingTypeを追加
          return HealthCenterInteriorScene(
            enteredBuilding: sceneData?['building'] as Building?,
            initialPlayerPosition:
                sceneData?['initialPlayerPosition'] as Vector2?,
            buildingTypeFromSave: sceneData?['buildingTypeFromSave'] as String?,
            buildingOutdoorPositionFromSave:
                sceneData?['buildingOutdoorPositionFromSave'] as Vector2?,
            outdoorSceneIdFromSave:
                sceneData?['outdoorSceneIdFromSave'] as String?,
          );
        },
      ),
      'shop_interior': (
        constructor: ({dynamic data}) {
          final Map<String, dynamic>? sceneData =
              data is Map ? data as Map<String, dynamic> : null;
          sceneData?['buildingType'] = 'shop'; // buildingTypeを追加
          return ShopInteriorScene(
            enteredBuilding: sceneData?['building'] as Building?,
            initialPlayerPosition:
                sceneData?['initialPlayerPosition'] as Vector2?,
            buildingTypeFromSave: sceneData?['buildingTypeFromSave'] as String?,
            buildingOutdoorPositionFromSave:
                sceneData?['buildingOutdoorPositionFromSave'] as Vector2?,
            outdoorSceneIdFromSave:
                sceneData?['outdoorSceneIdFromSave'] as String?,
          );
        },
      ),
      'sushi_interior': (
        constructor: ({dynamic data}) {
          final Map<String, dynamic>? sceneData =
              data is Map ? data as Map<String, dynamic> : null;
          sceneData?['buildingType'] = 'sushi'; // buildingTypeを追加
          return SushiInteriorScene(
            enteredBuilding: sceneData?['building'] as Building?,
            initialPlayerPosition:
                sceneData?['initialPlayerPosition'] as Vector2?,
            buildingTypeFromSave: sceneData?['buildingTypeFromSave'] as String?,
            buildingOutdoorPositionFromSave:
                sceneData?['buildingOutdoorPositionFromSave'] as Vector2?,
            outdoorSceneIdFromSave:
                sceneData?['outdoorSceneIdFromSave'] as String?,
          );
        },
      ),
      'outdoor_2': (
        constructor: ({dynamic data}) {
          final Map<String, dynamic>? sceneData =
              data is Map ? data as Map<String, dynamic> : null;
          return OutdoorScene(
            sceneId: 'outdoor_2',
            initialPlayerPosition: sceneData?['initialPlayerPosition'] as Vector2?,
          );
        },
      ),
      'outdoor_3': (
        constructor: ({dynamic data}) {
          final Map<String, dynamic>? sceneData =
              data is Map ? data as Map<String, dynamic> : null;
          return OutdoorScene(
            sceneId: 'outdoor_3',
            initialPlayerPosition: sceneData?['initialPlayerPosition'] as Vector2?,
          );
        },
      ),
      'outdoor_4': (
        constructor: ({dynamic data}) {
          final Map<String, dynamic>? sceneData =
              data is Map ? data as Map<String, dynamic> : null;
          return OutdoorScene(
            sceneId: 'outdoor_4',
            initialPlayerPosition: sceneData?['initialPlayerPosition'] as Vector2?,
          );
        },
      ),
      'outdoor_philosophy': (
        constructor: ({dynamic data}) {
          final Map<String, dynamic>? sceneData =
              data is Map ? data as Map<String, dynamic> : null;
          return OutdoorScene(
            sceneId: 'outdoor_philosophy',
            initialPlayerPosition: sceneData?['initialPlayerPosition'] as Vector2?,
          );
        },
      ),
    'outdoor_despair': (
      constructor: ({dynamic data}) {
        final Map<String, dynamic>? sceneData =
            data is Map ? data as Map<String, dynamic> : null;
        return OutdoorScene(
          sceneId: 'outdoor_despair',
          initialPlayerPosition: sceneData?['initialPlayerPosition'] as Vector2?,
        );
      },
    ),
    'outdoor_true': (
      constructor: ({dynamic data}) {
        final Map<String, dynamic>? sceneData =
            data is Map ? data as Map<String, dynamic> : null;
        return OutdoorScene(
          sceneId: 'outdoor_true',
          initialPlayerPosition: sceneData?['initialPlayerPosition'] as Vector2?,
        );
      },
    ),
  };
}

  Future<void> loadScene(
    String sceneId, {
    dynamic data,
    Vector2? initialPlayerPosition, // Vector2で受け取るように変更
  }) async {
    debugPrint('SceneManager.loadScene called for scene: $sceneId'); // 追加
    debugPrint('loadScene: Attempting to load scene: $sceneId');

    // シーン切り替え前に現在のシーンとプレイヤー位置を保存
    if (_currentScene != null && game.player != null) {
      // パンくずリスト情報の更新
      if (_currentScene is AbstractOutdoorScene &&
          sceneId.contains('interior')) {
        // 屋外から屋内へ遷移する場合
        game.gameRuntimeState.exitPlayerPositionX = game.player!.position.x;
        game.gameRuntimeState.exitPlayerPositionY = game.player!.position.y;

        final Building? building =
            data is Map
                ? data['building'] as Building?
                : null; // dataからBuildingを取得
        if (building != null) {
          game.gameRuntimeState.currentSceneId = sceneId;
          game.gameRuntimeState.currentBuildingType =
              building.type; // Buildingにtypeプロパティがある前提
          game.gameRuntimeState.currentBuildingPositionX = building.position.x;
          game.gameRuntimeState.currentBuildingPositionY = building.position.y;
          debugPrint(
            'パンくずリスト更新：屋外→屋内。outdoorSceneId=${game.gameRuntimeState.currentOutdoorSceneId}, buildingType=${game.gameRuntimeState.currentBuildingType}, buildingPos=(${game.gameRuntimeState.currentBuildingPositionX}, ${game.gameRuntimeState.currentBuildingPositionY})',
          );
        }
      } else if (_currentScene is AbstractOutdoorScene) {
        // 屋内から屋外へ遷移する場合
        game.gameRuntimeState.currentSceneId = sceneId;
        game.gameRuntimeState.exitPlayerPositionX = game.player!.position.x;
        game.gameRuntimeState.exitPlayerPositionY = game.player!.position.y;
        debugPrint('パンくずリストクリア：屋内→屋外');
      } else {
        // その他の遷移の場合（例: 屋内から屋内、またはゲーム開始時など）
        game.gameRuntimeState.currentSceneId = sceneId;
        game.gameRuntimeState.exitPlayerPositionX = game.player!.position.x;
        game.gameRuntimeState.exitPlayerPositionY = game.player!.position.y;
        debugPrint('パンくずリストクリア：その他の遷移');
      }
    }

    debugPrint('--- SceneManager.loadScene ---');

    // シーン切り替え時にすべてのSoLoud音源を停止
    // game.audioManager.soloud.stopAllSounds();
    // debugPrint('全てのSoLoud音源を停止しました。');

    // 現在のシーンと背景を削除
    if (_currentScene != null) {
      debugPrint('現在のシーンを削除中: ${_currentScene.runtimeType}');
      
      // シーンからプレイヤーを明示的に削除 (ワールドからは削除しない)
      final scene = _currentScene!;
      final player = game.player;
      if (player != null && scene.contains(player)) {
        debugPrint('シーンからプレイヤーを削除します。');
        scene.remove(player); // プレイヤーを古いシーンから削除
      }

      // OutdoorSceneからCarEnemyを明示的に削除し、音源を停止させる
      if (_currentScene is AbstractOutdoorScene) {
        final outdoorScene = _currentScene as AbstractOutdoorScene;
        final carEnemies = outdoorScene.children.whereType<CarEnemy>().toList();
        debugPrint(
          'Found ${carEnemies.length} CarEnemy instances in AbstractOutdoorScene.',
        );
        for (var enemy in carEnemies) {
          enemy.removeFromParent(); // ワールドから削除
          debugPrint('Stopped and removed CarEnemy: ${enemy.position}');
        }
      }
      // 現在のシーンからSkyComponentを削除
      _currentScene!.children.whereType<SkyComponent>().forEach((skyComponent) {
        skyComponent.removeFromParent();
      });
      _currentScene!.removeFromParent();
      debugPrint('現在のシーンを削除しました。'); // 追加
      _currentScene = null;
    }

    // 新しいシーンをインスタンス化
    final newSceneConstructor = _sceneConstructors[sceneId]!;
    debugPrint('新しいシーンのコンストラクタを特定しました: $sceneId'); // 追加

    // playerPositionを`data`マップに含めて渡す
    // `data`がBuildingインスタンスの場合、それを'building'キーで、playerPositionを'initialPlayerPosition'キーで渡す
    // それ以外の場合はdataをそのまま渡す
    final Map<String, dynamic> sceneData = {};
    if (data is Building) {
      sceneData['building'] = data;
    } else if (data != null) {
      // Buildingでないその他のデータはそのまま渡す（必要に応じて処理）
      sceneData['data'] = data; // 例として'data'キーで渡す
    }
    if (initialPlayerPosition != null) {
      sceneData['initialPlayerPosition'] =
          initialPlayerPosition; // playerPositionをマップに追加
    }

    // OutdoorSceneにシーンIDを渡すためのロジックを追加
    if (sceneId == 'outdoor') {
      final String targetOutdoorSceneId =
          (data is Map && data.containsKey('sceneId'))
              ? data['sceneId'] as String
              : game.gameRuntimeState.currentOutdoorSceneId ??
                  'outdoor'; // GameRuntimeStateから取得
      sceneData['sceneId'] = targetOutdoorSceneId; // OutdoorSceneのコンストラクタに渡す
    }

    // 室内シーンにoutdoorSceneIdFromSaveを渡すためのロジックを追加
    if (sceneId.contains('interior')) {
      final String? outdoorSceneIdFromSave =
          game.gameRuntimeState.currentOutdoorSceneId; // GameRuntimeStateから取得
      if (outdoorSceneIdFromSave != null) {
        sceneData['outdoorSceneIdFromSave'] = outdoorSceneIdFromSave;
      }
    }

    final newScene = newSceneConstructor.constructor(data: sceneData); // マップを渡す
    _currentScene = newScene;
    debugPrint('新しいシーンをインスタンス化しました: ${_currentScene.runtimeType}'); // 追加

    // ここで新しいシーンにプレイヤーを追加
    if (game.player != null) {
      debugPrint('新しいシーンにプレイヤーを追加します。');
      _currentScene!.add(game.player!); // プレイヤーを新しいシーンの子にする
    }
    
    await add(_currentScene!); // ゲームワールドにシーンを追加
    debugPrint('新しいシーンをゲームワールドに追加しました。'); // 追加
    await _currentScene!.initializeScene(sceneData); // シーンを初期化
    debugPrint('新しいシーンの初期化が完了しました。'); // 追加

    // シーンがロードされた後、もしそれが屋外シーンであればIDを保存
    if (newScene is AbstractOutdoorScene) {
      game.gameRuntimeState.currentOutdoorSceneId =
          newScene.sceneId; // GameRuntimeStateを更新
      debugPrint(
        'Current outdoor scene ID set to: ${game.gameRuntimeState.currentOutdoorSceneId}',
      );
    }

    // ステージ開始時のミッション設定を更新（メッセージウィンドウは出さない）
    game.routeManager.showCompassMessage(sceneId, showWindow: false);

    // カメラのズームレベルをリセット
    if (sceneId.contains('outdoor')) {
      game.cameraController.setOutdoorSceneCamera();
    } else if (sceneId.contains('interior')) {
      // すべての室内シーンに適用される汎用的なカメラ設定
      game.cameraController.setInteriorSceneCamera();
    }

    // シーンにライティングオーバーレイを追加
    if (_currentScene!.darknessOverlay != null) {
      _currentScene!.darknessOverlay!.priority = 1000;
      await _currentScene!.add(_currentScene!.darknessOverlay!);
    }
    if (_currentScene!.lightAndBrightnessOverlay != null) {
      _currentScene!.lightAndBrightnessOverlay!.priority =
          2000; // priorityを1000から2000に戻す
      await _currentScene!.add(_currentScene!.lightAndBrightnessOverlay!);
    }

    debugPrint('loadScene: Scene $sceneId loaded successfully.');
  }

  // ショップシーンに入るメソッド
  void enterShopScene(
    Building shop, {
    Vector2? initialPlayerPosition,
    String? outdoorSceneId,
  }) {
    debugPrint('ショップの室内に入ります: $shop');
    loadScene(
      'shop_interior',
      data: {
        'building': shop,
        'initialPlayerPosition': initialPlayerPosition,
        'outdoorSceneIdFromSave': outdoorSceneId,
      },
    );
  }

  // ヘルスセンターシーンに入るメソッド
  void enterHealthCenterScene(
    Building healthCenter, {
    Vector2? initialPlayerPosition,
    String? outdoorSceneId,
  }) {
    debugPrint('ヘルスセンターの室内に入ります: $healthCenter');
    loadScene(
      'health_center_interior',
      data: {
        'building': healthCenter,
        'initialPlayerPosition': initialPlayerPosition,
        'outdoorSceneIdFromSave': outdoorSceneId,
      },
    );
  }

  // アパートシーンに入るメソッド
  void enterApartmentScene(
    Building apartment, {
    Vector2? initialPlayerPosition,
    String? outdoorSceneId,
  }) {
    debugPrint('アパートの室内に入ります: $apartment');
    loadScene(
      'apartment_interior',
      data: {
        'building': apartment,
        'initialPlayerPosition': initialPlayerPosition,
        'outdoorSceneIdFromSave': outdoorSceneId, // outdoorSceneIdFromSaveとして渡す
      },
    );
  }

  // 寿司屋シーンに入るメソッド
  void enterSushiScene(
    Building sushi, {
    Vector2? initialPlayerPosition,
    String? outdoorSceneId,
  }) {
    debugPrint('寿司屋の室内に入ります: $sushi');
    loadScene(
      'sushi_interior',
      data: {
        'building': sushi,
        'initialPlayerPosition': initialPlayerPosition,
        'outdoorSceneIdFromSave': outdoorSceneId, // outdoorSceneIdFromSaveとして渡す
      },
    );
  }

  // カフェシーンに入るメソッド
  void enterCafeScene(
    Building cafe, {
    Vector2? initialPlayerPosition,
    String? outdoorSceneId,
  }) {
    debugPrint('カフェの室内に入ります: $cafe');
    loadScene(
      'cafe_interior',
      data: {
        'building': cafe,
        'initialPlayerPosition': initialPlayerPosition,
        'outdoorSceneIdFromSave': outdoorSceneId, // outdoorSceneIdFromSaveとして渡す
      },
    );
  }

  // ハンバーガー店シーンに入るメソッド
  void enterBurgerStoreScene(
    Building burgerStore, {
    Vector2? initialPlayerPosition,
    String? outdoorSceneId,
  }) {
    debugPrint('ハンバーガー店の室内に入ります: $burgerStore');
    loadScene(
      'burger_store_interior',
      data: {
        'building': burgerStore,
        'initialPlayerPosition': initialPlayerPosition,
        'outdoorSceneIdFromSave': outdoorSceneId, // outdoorSceneIdFromSaveとして渡す
      },
    );
  }
}
