import 'package:flame/components.dart';
import '../main.dart'; // MyGameをインポート
import 'player.dart'; // Playerをインポート
import 'game_stage/gamestage_component.dart'; // BackgroundComponentをインポート

class CameraController extends Component with HasGameReference<MyGame> {
  Player? _player;

  // 各種カメラ設定のためのメソッド
  void initializeCamera(Player player) {
    _player = player;
  }

  @override
  Future<void> onLoad() async {}

  // OutdoorSceneのカメラ設定
  void setOutdoorSceneCamera() {
    game.camera.viewfinder.anchor = Anchor(Anchor.bottomCenter.x, Anchor.bottomCenter.y - 0.2); // OutdoorSceneはbottomCenter
    game.camera.viewfinder.zoom = game.minZoomToFit;
    game.camera.follow(_player!); // 全方向追従
  }

  // インテリアシーンのカメラ設定
  void setInteriorSceneCamera() {
    game.camera.viewfinder.anchor = Anchor(Anchor.center.x, Anchor.center.y); // OutdoorSceneはbottomCenter
    game.camera.viewfinder.zoom = 2.0;
    game.camera.follow(_player!); // 全方向追従
  }

  // 背景のパララックス効果を更新するメソッド
  void updateBackgroundParallax(double playerDx) {
    if (game.player == null || game.sceneManager.currentScene == null) return;

    if (playerDx != 0) {
      // プレイヤーが移動した場合のみ背景を更新
      game.sceneManager.currentScene!.children
          .whereType<GameStageComponent>()
          .forEach((bg) {
            bg.position.x += -playerDx * bg.parallaxEffect;
          });
    }
  }

  // ズームイン/アウト
  void zoomIn() {
    final newZoom = (game.camera.viewfinder.zoom + 0.1).clamp(
      game.minZoomToFit,
      game.maxZoomToFit,
    );
    game.camera.viewfinder.zoom = newZoom;
  }

  void zoomOut() {
    final newZoom = (game.camera.viewfinder.zoom - 0.1).clamp(
      game.minZoomToFit,
      game.maxZoomToFit,
    );
    game.camera.viewfinder.zoom = newZoom;
  }

  // プレイヤーが掘削中のカメラ追従を調整するメソッド
  void adjustCameraForDigging() {
    if (_player == null) return;

    // 掘削中は、プレイヤーが中心に来るように
    game.camera.viewfinder.anchor = Anchor.center;
    //game.camera.follow(_player!);
  }

  // カメラの目標Y座標を計算するヘルパーメソッド (もはや不要、上記メソッドで直接計算)
}
