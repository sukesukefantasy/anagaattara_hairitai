import 'package:flutter/material.dart';
import 'abstract_outdoor_scene.dart';
import 'package:flame/components.dart'; // Add for SpriteComponent
import '../component/common/underground/underground.dart'; // Add for UnderGround.digAreaSize
import '../component/vehicle/train.dart'; // Add this line

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

    // 採掘可能入口のX座標を設定（このシーン固有の設定）
    underGround!.addDiggableEntrances([
      // 採掘可能入口のX座標を屋外シーン1用に設定
      -300.0,
      -555.0,
      -932.0,
      -1312.0,
      -1688.0,
    ]);

    debugPrint('OutdoorScene initializeScene complete');
  }
}
