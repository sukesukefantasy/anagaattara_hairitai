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
    game.camera.viewfinder.anchor =
        Anchor(Anchor.bottomCenter.x, Anchor.bottomCenter.y - 0.2);
    game.camera.viewfinder.zoom = game.minZoomToFit * 1.5; // 1.5倍に拡大
    game.camera.follow(_player!); // 全方向追従
  }

  // インテリアシーンのカメラ設定
  void setInteriorSceneCamera() {
    game.camera.viewfinder.anchor = Anchor(Anchor.center.x, Anchor.center.y); // OutdoorSceneはbottomCenter
    game.camera.viewfinder.zoom = 2.0;
    game.camera.follow(_player!); // 全方向追従
  }

  // 背景パララックスの更新
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

  // 背景位置をリセットするメソッド
  void resetBackgroundParallax() {
    if (game.sceneManager.currentScene == null) return;
    
    game.sceneManager.currentScene!.children
        .whereType<GameStageComponent>()
        .forEach((bg) {
          bg.position.x = 0;
        });
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
    game.camera.viewfinder.zoom = game.minZoomToFit * 1.5; // 地下でもズームを維持
  }

  // カメラの目標Y座標を計算するヘルパーメソッド (もはや不要、上記メソッドで直接計算)
}
