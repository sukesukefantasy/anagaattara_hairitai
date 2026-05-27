import 'package:flame/components.dart';
import '../game/pseudo3d_camera.dart';
import '../game/world_scale.dart';
import '../main.dart';
import '../scene/abstract_outdoor_scene.dart';
import 'player.dart';
import 'game_stage/gamestage_component.dart';
import 'game_stage/lighting/sky_component.dart';

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

  /// 奥行きズーム補正の基準（[setZoom] / [syncDepthZoom] で使用）。
  double referenceZoom = 1.0;

  double _lastSyncedCameraZoom = -1;

  /// パララックス層の奥行きズーム中心（ワールド）。カメラフォーカスのみ（手動パン含む）。
  Vector2 get depthZoomFocusWorld => Vector2(
        cameraAnchor.position.x,
        game.initialGameCanvasSize.y,
      );

  /// 屋外背景の疑似3D射影（毎フレーム再生成）。
  Pseudo3DCamera get outdoorPseudo3D => Pseudo3DCamera(
        focusWorldX: cameraAnchor.position.x,
        referenceZoom: referenceZoom,
        viewfinderZoom: game.camera.viewfinder.zoom,
      );

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

    if (game.sceneManager.currentScene is AbstractOutdoorScene) {
      desired = _clampFocusToStageWorld(desired);
    }

    cameraAnchor.position = desired;
    // クランプで実際に動いた分を manualPan に織り込む（ズーム変更後もパン意図と一致させる）
    manualPanWorld.setFrom(desired - base);

    _syncDepthZoomIfNeeded();
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

  /// 可視範囲がプレイステージ [stageLeftX]〜[stageRightX]（= [worldWidth]）を
  /// はみ出さないようフォーカス X を補正する。
  ///
  /// 地面・空の描画は [extendedWorldLeft] まで広いが、カメラ可動域はステージ幅に合わせる。
  Vector2 _clampFocusToStageWorld(Vector2 focus) {
    final vf = game.camera.viewfinder.position.clone();
    game.camera.viewfinder.position = focus;
    final vis = game.camera.visibleWorldRect;
    game.camera.viewfinder.position = vf;

    final margin = _clampMarginScreenPx / game.camera.viewfinder.zoom;
    final minLeft = WorldScale.stageLeftX - margin;
    final maxRight = WorldScale.stageRightX + margin;

    double dx = 0;
    if (vis.left < minLeft) {
      dx = vis.left - minLeft;
    } else if (vis.right > maxRight) {
      dx = vis.right - maxRight;
    }

    return focus - Vector2(dx, 0);
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
    referenceZoom = game.minZoomToFit * 2;
    setZoom(referenceZoom);
    syncVerticalFocusFromPlayer();
    _beginSceneCamera();
  }

  void setInteriorSceneCamera() {
    _verticalFollowWorldAdjustmentY = -game.cameraFollowOffset.y;
    resetManualPan();
    game.camera.viewfinder.anchor =
        Anchor(Anchor.center.x, Anchor.center.y);
    referenceZoom = 2.0;
    setZoom(referenceZoom);
    syncVerticalFocusFromPlayer();
    _beginSceneCamera();
  }

  /// viewfinder.zoom を設定し、パララックス層の奥行きズーム補正を同期する。
  void setZoom(double zoom) {
    final clamped = zoom.clamp(game.minZoomToFit, game.maxZoomToFit);
    game.camera.viewfinder.zoom = clamped;
    _lastSyncedCameraZoom = -1;
    syncDepthZoom();
  }

  /// [GameStageComponent] と [SkyComponent] に深度別 scale 補正を適用する。
  void syncDepthZoom() {
    final scene = game.sceneManager.currentScene;
    if (scene == null) {
      return;
    }

    final cameraZoom = game.camera.viewfinder.zoom;
    if (cameraZoom <= 0 || referenceZoom <= 0) {
      return;
    }

    _lastSyncedCameraZoom = cameraZoom;

    if (scene is AbstractOutdoorScene) {
      return;
    }

    for (final bg in scene.children.whereType<GameStageComponent>()) {
      if (bg.isMounted && !bg.loop) {
        bg.applyDepthZoom(cameraZoom, referenceZoom);
      }
    }
  }

  void _syncDepthZoomIfNeeded() {
    final z = game.camera.viewfinder.zoom;
    if (z == _lastSyncedCameraZoom) {
      return;
    }
    syncDepthZoom();
  }

  /// 互換: 屋外 loop は [Pseudo3DCamera] が描画時に射影するため no-op。
  void resetBackgroundParallax() {}

  void zoomIn() {
    setZoom(game.camera.viewfinder.zoom + 0.1);
  }

  void zoomOut() {
    setZoom(game.camera.viewfinder.zoom - 0.1);
  }

  void adjustCameraForDigging() {
    if (_player == null) return;

    _verticalFollowWorldAdjustmentY = 0;
    game.camera.viewfinder.anchor = Anchor.center;
    referenceZoom = game.minZoomToFit * 1.5;
    setZoom(referenceZoom);
    syncVerticalFocusFromPlayer();
    _beginSceneCamera();
  }
}
