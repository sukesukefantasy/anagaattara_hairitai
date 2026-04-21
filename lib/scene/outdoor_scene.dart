import 'package:flutter/material.dart';
import 'abstract_outdoor_scene.dart';
import 'package:flame/components.dart'; // Add for SpriteComponent
import '../UI/window_manager.dart';
import '../UI/windows/message_window.dart';
import '../component/vehicle/train.dart'; // Add this line
import '../component/item/item.dart';

class OutdoorScene extends AbstractOutdoorScene {
  // GameSceneの抽象ゲッターを実装
  @override
  double get groundHeight => 20.0;

  OutdoorScene({required super.sceneId, super.initialPlayerPosition});

  // 電車をスポーンさせるメソッド (このクラスに属する)
  void spawnTrain() {
    if (station == null) {
      debugPrint('Station is not yet initialized in OutdoorScene.');
      return;
    }
    final train = Train(
      position: Vector2(0, station!.position.y + station!.size.y - 126),
      station: station!,
    )..priority = 3; // 建物(priority: 5)より奥に描画される
    add(train); // OutdoorSceneの子として追加
    debugPrint('Spawned a new train in OutdoorScene.');
  }

  @override
  Future<void> initializeScene(dynamic data) async {
    await super.initializeScene(data);

    // Stage 6 (Despair) の場合、条件を満たしていなければオートプレイを開始
    if (sceneId == 'outdoor_despair') {
      final state = game.gameRuntimeState;
      // Stage 1-4 すべてでサブルート（能動性スコア30）を達成していれば回避
      bool allSubRoutesConfirmed = true;
      for (int i = 1; i <= 4; i++) {
        if (!state.subRouteConfirmedStages.contains('outdoor_$i')) {
          allSubRoutesConfirmed = false;
          break;
        }
      }

      if (!allSubRoutesConfirmed) {
        state.isAutoPlay = true;
        game.windowManager.showDialog(
          ["「……個の維持に失敗。オートプレイ・プロトコルを開始します。」"],
        );
      }
    }

    // ステージごとの固有設定
    List<double> entrances = [];
    switch (sceneId) {
      case 'outdoor':
        entrances = [-300.0, -555.0, -932.0, -1312.0, -1688.0];
        break;
      case 'outdoor_2':
        entrances = [-200.0, -800.0, -1400.0];
        break;
      case 'outdoor_3':
        entrances = [-400.0, -1000.0, -1800.0];
        break;
      case 'outdoor_4':
        entrances = [-100.0, -700.0, -1200.0, -1700.0];
        break;
      case 'outdoor_philosophy':
        // Philosophyステージ: 入口を増やして探索しやすく
        entrances = [-200.0, -500.0, -800.0, -1100.0, -1400.0, -1700.0];
        break;
      case 'outdoor_despair':
      case 'outdoor_true':
        entrances = [-300.0, -1000.0];
        break;
      default:
        entrances = [-500.0, -1000.0, -1500.0];
    }

    // 地下の採掘状況
    if (sceneId == 'outdoor_philosophy') {
      final state = game.gameRuntimeState;
      bool isSubScenario = true;
      for (int i = 1; i <= 4; i++) {
        if (!state.subRouteConfirmedStages.contains('outdoor_$i')) {
          isSubScenario = false;
          break;
        }
      }

      final targetItem = isSubScenario ? 'レスポンス' : '掌握された自意識';
      // 地下の3層目（深度3マス目）、x=-250にアイテムを配置
      final item = ItemFactory.createItemByName(targetItem, Vector2(-250, underGround.y + 160));
      if (item != null) {
        add(item);
      }
    }

    underGround.addDiggableEntrances(entrances);
    debugPrint('OutdoorScene initializeScene complete for $sceneId');
  }
}
