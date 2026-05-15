import 'package:flame/components.dart';
import '../main.dart';
import 'player.dart';
import 'game_stage/gamestage_component.dart';

class CameraController extends Component with HasGameReference<MyGame> {
  Player? _player;

  /// viewfinder が追従するワールド上のフォーカス（プレイヤー＋オフセット＋手動パンを反映）。
  final PositionComponent cameraAnchor = PositionComponent();

  /// 右ドラッグなどによるワールド座標系の累積パン。
  final Vector2 manualPanWorld = Vector2.zero();

  /// 自動追従の Y（地上では更新しない。地下エリアにいるときのみプレイヤーに同期）。
  double _verticalFocusY = 0;

  /// [game.cameraFollowOffset] は屋外向けに Y 負方向へ寄せている。屋内ではその分を打ち消してプレイヤーを中央付近に置く。
  double _verticalFollowWorldAdjustmentY = 0;

  static const double _clampMarginScreenPx = 24;

  void initializeCamera(Player player) {
    _player = player;
    if (!cameraAnchor.isMounted) {
      game.world.add(cameraAnchor);
    }
    syncVerticalFocusFromPlayer();
  }

  @override
  Future<void> onLoad() async {}

  @override
  void update(double dt) {
    super.update(dt);
    final p = _player;
    if (p == null || !p.isMounted) return;

    if (p.inUnderGround) {
      _verticalFocusY = p.position.y +
          game.cameraFollowOffset.y +
          _verticalFollowWorldAdjustmentY;
    }

    final baseX = p.position.x + game.cameraFollowOffset.x;
    final base = Vector2(baseX, _verticalFocusY);
    var desired = base + manualPanWorld;

    if (game.clampPlayerInCamera) {
      desired = _clampFocusToKeepPlayerVisible(desired, p);
    }

    cameraAnchor.position = desired;
    // クランプで実際に動いた分を manualPan に織り込む（ズーム変更後もパン意図と一致させる）
    manualPanWorld.setFrom(desired - base);
  }

  /// 画面ピクセル単位のドラッグ delta をワールドへ（指に世界が追従する向き）。
  void addManualPanFromScreenDelta(Vector2 screenDelta, double zoom) {
    if (zoom <= 0) return;
    manualPanWorld.add(screenDelta / zoom);
  }

  void resetManualPan() {
    manualPanWorld.setZero();
  }

  void nudgeManualPanWorld(Vector2 worldDelta) {
    manualPanWorld.add(worldDelta);
  }

  /// シーン切替・テレポートなど、注視 Y をプレイヤー足元に合わせ直すときに呼ぶ。
  void syncVerticalFocusFromPlayer() {
    final p = _player;
    if (p == null) return;
    _verticalFocusY = p.position.y +
        game.cameraFollowOffset.y +
        _verticalFollowWorldAdjustmentY;
  }

  Vector2 _clampFocusToKeepPlayerVisible(Vector2 focus, Player p) {
    final vf = game.camera.viewfinder.position.clone();
    game.camera.viewfinder.position = focus;
    final vis = game.camera.visibleWorldRect;
    game.camera.viewfinder.position = vf;

    final m = _clampMarginScreenPx / game.camera.viewfinder.zoom;
    final inner = vis.deflate(m);
    final pr = p.toAbsoluteRect();

    double cx = 0;
    if (pr.width <= inner.width) {
      if (pr.left < inner.left) {
        cx = pr.left - inner.left;
      } else if (pr.right > inner.right) {
        cx = pr.right - inner.right;
      }
    }

    double cy = 0;
    if (pr.height <= inner.height) {
      if (pr.top < inner.top) {
        cy = pr.top - inner.top;
      } else if (pr.bottom > inner.bottom) {
        cy = pr.bottom - inner.bottom;
      }
    }

    return focus + Vector2(cx, cy);
  }

  void _beginSceneCamera() {
    game.camera.stop();
    game.camera.follow(cameraAnchor);
  }

  void setOutdoorSceneCamera() {
    _verticalFollowWorldAdjustmentY = 0;
    resetManualPan();
    game.camera.viewfinder.anchor =
        Anchor(Anchor.bottomCenter.x, Anchor.bottomCenter.y - 0.3);
    game.camera.viewfinder.zoom = game.minZoomToFit * 2;
    syncVerticalFocusFromPlayer();
    _beginSceneCamera();
  }

  void setInteriorSceneCamera() {
    _verticalFollowWorldAdjustmentY = -game.cameraFollowOffset.y;
    resetManualPan();
    game.camera.viewfinder.anchor =
        Anchor(Anchor.center.x, Anchor.center.y);
    game.camera.viewfinder.zoom = 2.0;
    syncVerticalFocusFromPlayer();
    _beginSceneCamera();
  }

  void updateBackgroundParallax(double playerDx) {
    if (game.sceneManager.currentScene == null) return;

    if (playerDx != 0) {
      game.sceneManager.currentScene!.children
          .whereType<GameStageComponent>()
          .forEach((bg) {
            bg.position.x += -playerDx * bg.parallaxEffect;
          });
    }
  }

  void resetBackgroundParallax() {
    if (game.sceneManager.currentScene == null) return;

    game.sceneManager.currentScene!.children
        .whereType<GameStageComponent>()
        .forEach((bg) {
          bg.position.x = 0;
        });
  }

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

  void adjustCameraForDigging() {
    if (_player == null) return;

    _verticalFollowWorldAdjustmentY = 0;
    game.camera.viewfinder.anchor = Anchor.center;
    game.camera.viewfinder.zoom = game.minZoomToFit * 1.5;
    syncVerticalFocusFromPlayer();
    _beginSceneCamera();
  }
}
