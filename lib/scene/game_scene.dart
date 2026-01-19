import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // MyGameをインポート
import '../component/common/ground/ground.dart'; // Groundをインポート

// GameSceneの基底クラス
abstract class GameScene extends Component with HasGameReference<MyGame> {
  // 各シーンが持つGroundComponentへの参照
  Ground? groundComponent;

  // オーバーレイへの参照 (SceneManagerから渡される)
  RectangleComponent? darknessOverlay;
  RectangleComponent? lightAndBrightnessOverlay;

  // 各シーンが持つ地面の高さを定義
  double get groundHeight;

  GameScene(); // コンストラクタの定義を修正

  // 各シーンでオーバーライドされる初期化メソッド
  Future<void> initializeScene(dynamic data) async {}

  // シーンがゲームワールドから削除される時に呼ばれる
  @override
  void onRemove() {
    super.onRemove();
    // オーバーレイをシーンから削除（MyGameが所有するため削除不要）
    // darknessOverlay?.removeFromParent();
    // lightAndBrightnessOverlay?.removeFromParent();
  }
}