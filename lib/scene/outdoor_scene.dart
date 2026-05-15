import 'package:flutter/material.dart';
import 'abstract_outdoor_scene.dart';
import 'package:flame/components.dart'; // Add for SpriteComponent
// import '../UI/window_manager.dart';
// import '../UI/windows/message_window.dart';
// import '../component/vehicle/train.dart'; // Add this line
import '../component/item/item.dart';

class OutdoorScene extends AbstractOutdoorScene {
  // GameSceneの抽象ゲッターを実装
  @override
  double get groundHeight => 20.0;

  OutdoorScene({required super.sceneId, super.initialPlayerPosition});

  @override
  Future<void> initializeScene(dynamic data) async {
    await super.initializeScene(data);

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
      case 'outdoor_true_corridor':
      case 'outdoor_true_vault':
      case 'outdoor_true_finale':
        entrances = [-300.0, -1000.0];
        break;
      default:
        entrances = [-500.0, -1000.0, -1500.0];
    }

    // 地下の採掘状況
    if (sceneId == 'outdoor_philosophy') {
      // bool isSubScenario = true;
      // for (int i = 1; i <= 4; i++) {
      //   if (!state.subRouteConfirmedStages.contains('outdoor_$i')) {
      //     isSubScenario = false;
      //     break;
      //   }
      // }

      final targetItem = '中枢演算コア';
      // 地下の3層目（深度3マス目）、x=-250にアイテムを配置
      final item = ItemFactory.createItemByName(targetItem, Vector2(-250, underGround.y + 160));
      if (item != null) {
        add(item);
      }
    }

    underGround.addDiggableEntrances(entrances);

    if (sceneId == 'outdoor_true_corridor') {
      game.windowManager.showDialog(
        [
          '〔深層廊下〕',
          '父の断片が足元の摩擦を薄めている。（意志力の消費が抑制される）',
          'この先、6桁の錠が待つ。',
        ],
        options: ['金庫区画へ進む', 'しばらく留まる'],
        onSelect: (i) async {
          if (i != 0) return;
          final st = game.gameRuntimeState;
          st.trueSequencePhase = 2;
          await st.saveGame();
          await game.sceneManager.loadScene(
            'outdoor_true_vault',
            initialPlayerPosition: Vector2(
              -100,
              game.initialGameCanvasSize.y - game.player.size.y / 2,
            ),
          );
        },
      );
    }

    if (sceneId == 'outdoor_true_vault') {
      Future.microtask(() => game.windowManager.showTrueVaultDial(game));
    }

    debugPrint('OutdoorScene initializeScene complete for $sceneId');
  }
}
