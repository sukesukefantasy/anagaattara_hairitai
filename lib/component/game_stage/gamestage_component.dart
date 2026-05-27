import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../depth_zoom_visual.dart';
import '../../game/pseudo3d_camera.dart';
import '../../game/world_scale.dart';
import '../../main.dart';
import '../../scene/abstract_outdoor_scene.dart';
import 'building/building_data.dart';
import 'lighting/camera_viewport_coords.dart';
import 'lighting/light_receiver.dart';
import 'lighting/lighting_participation.dart';
import 'lighting/lighting_participant.dart';
import 'lighting/shooting_star_light.dart';
import 'lighting/sun_modulate_mask.dart';

class GameStageComponent extends RectangleComponent
    with
        HasGameReference<MyGame>,
        LightingParticipant,
        LightReceiver,
        DepthZoomVisual {
  final BackgroundData data;
  late Sprite _backgroundSprite;
  List<Sprite>? _sheetFrames;
  int _frameIndex = 0;
  double _idleTimer = 0;
  double _frameTimer = 0;
  bool _playingBurst = false;
  final TransientShootingStarLight shootingStarLight = TransientShootingStarLight();
  final bool isScrollForward;

  /// true の層（遠景・中景など距離別の複数層）は [loopPeriodWorldWidth] 周期でタイルループする。
  final bool loop;

  double get depthMeters => data.depthMeters;

  @override
  LightingParticipation get lightingParticipation => data.lighting;

  @override
  double get worldDepthMeters => data.depthMeters;

  @override
  Vector2? get depthZoomFocusWorld => game.cameraController.depthZoomFocusWorld;

  Sprite? get backgroundSprite => isLoaded ? _backgroundSprite : null;

  bool get isSheetBurstPlaying => _playingBurst;

  int get sheetFrameIndex => _frameIndex;

  int get renderPriority => data.resolveRenderPriority();

  /// プレイフィールド地面線のワールド Y（center アンカー + [size] 基準の従来式）。
  double get groundLineWorldY => position.y + size.y;

  double get _tileWidth => data.srcSize.x;

  /// ループ周期（プレイエリア横幅 = カメラ可動域の基準）。
  static double get loopPeriodWorldWidth => MyGame.worldWidth;

  static int tilesPerPeriod(double tileW) =>
      (loopPeriodWorldWidth / tileW).ceil();

  final overlayPaint =
      Paint()
        ..color = const Color.fromARGB(255, 36, 36, 36).withAlpha(150)
        ..blendMode = BlendMode.srcOver;

  GameStageComponent({
    required this.data,
    this.isScrollForward = false,
    this.loop = false,
  }) : super(size: data.srcSize.clone());

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    scale.setValues(1, 1);
    final sheetAnim = data.sheetAnimation;
    if (sheetAnim != null) {
      final image = await game.images.load(data.imagePath);
      final frameW = data.srcSize.x;
      final frameH = data.srcSize.y;
      _sheetFrames = List.generate(sheetAnim.frameCount, (i) {
        final col = i % sheetAnim.columns;
        final row = i ~/ sheetAnim.columns;
        return Sprite(
          image,
          srcPosition: Vector2(col * frameW, row * frameH),
          srcSize: data.srcSize,
        );
      });
      _frameIndex = sheetAnim.idleFrameIndex;
      _backgroundSprite = _sheetFrames![_frameIndex];
    } else {
      _backgroundSprite = await Sprite.load(
        data.imagePath,
        srcPosition: data.srcPosition,
        srcSize: data.srcSize,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final sheetAnim = data.sheetAnimation;
    final frames = _sheetFrames;
    if (sheetAnim == null || frames == null) {
      return;
    }

    if (!_playingBurst) {
      _backgroundSprite = frames[sheetAnim.idleFrameIndex];
      _frameIndex = sheetAnim.idleFrameIndex;
      _idleTimer += dt;
      if (_idleTimer >= sheetAnim.intervalSeconds) {
        _playingBurst = true;
        _idleTimer = 0;
        _frameIndex = sheetAnim.playStartFrame;
        _frameTimer = 0;
        _backgroundSprite = frames[_frameIndex];
      }
      _syncShootingStarLight();
      return;
    }

    _frameTimer += dt;
    while (_frameTimer >= sheetAnim.stepTime) {
      _frameTimer -= sheetAnim.stepTime;
      if (_frameIndex < sheetAnim.playEndFrame) {
        _frameIndex++;
        _backgroundSprite = frames[_frameIndex];
      } else {
        _playingBurst = false;
        _frameIndex = sheetAnim.idleFrameIndex;
        _backgroundSprite = frames[_frameIndex];
        _idleTimer = 0;
        _syncShootingStarLight();
        return;
      }
    }
    _syncShootingStarLight();
  }

  void _syncShootingStarLight() {
    ShootingStarLightSync.updateEmitter(
      emitter: shootingStarLight,
      game: game,
      sync: data.sheetLightSync,
      anim: data.sheetAnimation,
      playingBurst: _playingBurst,
      frameIndex: _frameIndex,
    );
  }

  void resetPositions(Vector2 gameSize) {
    position.y = (gameSize.y - size.y) + (data.groundOffset ?? 0);
    if (loop) {
      position.x = 0;
    } else if (isMounted) {
      game.cameraController.syncDepthZoom();
    }
  }

  bool get _useOutdoorPseudo3D =>
      loop && game.sceneManager.currentScene is AbstractOutdoorScene;

  Pseudo3DCamera get _outdoorPseudo3D => game.cameraController.outdoorPseudo3D;

  bool get _isOutdoorScene =>
      game.sceneManager.currentScene is AbstractOutdoorScene;

  void _paintWithOutdoorDepthZoom(
    Canvas canvas,
    void Function(Canvas canvas) paint,
  ) {
    final pseudo3D = _outdoorPseudo3D;
    final pivot = pseudo3D.depthZoomPivotLocal(
      absoluteTopLeftPosition.x,
      size.y,
    );
    Pseudo3DCamera.paintWithDepthZoomAtPivot(
      canvas,
      factor: pseudo3D.depthZoomRenderFactor(depthMeters),
      pivotLocalX: pivot.x,
      pivotLocalY: pivot.y,
      paint: paint,
    );
  }

  @override
  void render(Canvas canvas) {
    renderWithComponentLighting(canvas, (layerCanvas) {
      if (_useOutdoorPseudo3D || (_isOutdoorScene && !loop)) {
        _paintWithOutdoorDepthZoom(layerCanvas, _renderBackground);
      } else {
        paintWithDepthZoom(layerCanvas, _renderBackground);
      }
    });
  }

  Rect _loopVisibleWorldRect(Pseudo3DCamera pseudo3D) {
    final vis = CameraViewportCoords.loopStageVisibleWorldRect(
      game.camera.visibleWorldRect,
    );
    return pseudo3D.expandedVisibleWorld(vis, depthMeters);
  }

  /// ライティングマスク生成用（[render] と同じ奥行きズーム＋タイル描画）。
  void paintLoopBackground(Canvas canvas, {Paint? overridePaint}) {
    if (_isOutdoorScene) {
      _paintWithOutdoorDepthZoom(
        canvas,
        (layerCanvas) =>
            _paintLoopBackgroundUnscaled(layerCanvas, overridePaint),
      );
    } else {
      _paintLoopBackgroundUnscaled(canvas, overridePaint);
    }
  }

  void _paintLoopBackgroundUnscaled(Canvas canvas, Paint? overridePaint) {
    final pseudo3D = _outdoorPseudo3D;
    paintLoopTiles(
      canvas: canvas,
      pseudo3D: pseudo3D,
      depthMeters: depthMeters,
      sprite: _backgroundSprite,
      tileW: _tileWidth,
      tileH: data.srcSize.y,
      tileGridOriginWorldX:
          WorldScale.loopBackgroundTileOriginWorldX(_tileWidth),
      componentWorldLeft: absoluteTopLeftPosition.x,
      visibleWorld: _loopVisibleWorldRect(pseudo3D),
      isScrollForward: isScrollForward,
      overridePaint: overridePaint,
    );
  }

  void _renderBackground(Canvas canvas) {
    final sunModulate = _sunModulatePaint();
    if (loop) {
      _paintLoopBackgroundUnscaled(canvas, sunModulate);
    } else if (_isOutdoorScene) {
      final pseudo3D = _outdoorPseudo3D;
      final anchorX = absoluteTopLeftPosition.x;
      final drawX =
          pseudo3D.projectedWorldX(anchorX, depthMeters) - anchorX;
      _backgroundSprite.render(
        canvas,
        position: Vector2(
          drawX + (isScrollForward ? 0 : -size.x),
          0,
        ),
        size: data.srcSize,
        overridePaint: sunModulate,
      );
    } else {
      _backgroundSprite.render(
        canvas,
        position: isScrollForward ? Vector2.zero() : Vector2(-size.x, 0),
        size: data.srcSize,
        overridePaint: sunModulate,
      );
    }

    if (game.player.inUnderGround && priority == 200) {
      final worldOriginInLocal = Vector2.zero() - absoluteTopLeftPosition;
      canvas.drawRect(
        Rect.fromLTWH(
          worldOriginInLocal.x - MyGame.worldWidth - game.size.x,
          worldOriginInLocal.y,
          worldOriginInLocal.x + (MyGame.worldWidth * 2),
          game.size.y,
        ),
        overlayPaint,
      );
    }
  }

  /// 遠景シルエット用: 空の [SunModulateMask.modulateFillColor] と同系の modulate。
  Paint? _sunModulatePaint() {
    if (data.lighting != LightingParticipation.none) {
      return null;
    }
    final scene = game.sceneManager.currentScene;
    if (scene is! AbstractOutdoorScene) {
      return null;
    }
    final world = scene.lightingWorld;
    final sunDark = world.sunDarknessFor(
      participation: LightingParticipation.none,
    );
    if (sunDark <= 0.001) {
      return null;
    }
    final sun = world.sunState;
    final modulate = SunModulateMask.modulateColor(
      darkness: sunDark,
      tintR: sun.tintR,
      tintG: sun.tintG,
      tintB: sun.tintB,
    );
    return Paint()
      ..colorFilter = ColorFilter.mode(modulate, BlendMode.modulate);
  }

  /// 全 [loop] 層共通: カメラ可視ワールド X のタイル index のみ描画（画面外は描かない）。
  static void paintLoopTiles({
    required Canvas canvas,
    required Pseudo3DCamera pseudo3D,
    required double depthMeters,
    required Sprite sprite,
    required double tileW,
    required double tileH,
    required double tileGridOriginWorldX,
    required double componentWorldLeft,
    required Rect visibleWorld,
    required bool isScrollForward,
    Paint? overridePaint,
  }) {
    if (tileW < 1 || visibleWorld.isEmpty) {
      return;
    }

    final step = isScrollForward ? tileW : -tileW;
    final i0 = ((visibleWorld.left - tileGridOriginWorldX) / tileW).floor() - 1;
    final i1 = ((visibleWorld.right - tileGridOriginWorldX) / tileW).ceil() + 1;
    for (var i = i0; i <= i1; i++) {
      final trueWorldLeft = tileGridOriginWorldX + i * step;
      final localX = pseudo3D.projectedWorldX(trueWorldLeft, depthMeters) -
          componentWorldLeft;
      sprite.render(
        canvas,
        position: Vector2(localX, 0),
        size: Vector2(tileW, tileH),
        overridePaint: overridePaint,
      );
    }
  }

  /// ライティングマスク用: 射影後タイル群のローカル矩形。
  static Rect projectedLoopLocalBounds({
    required Pseudo3DCamera pseudo3D,
    required double depthMeters,
    required double tileGridOriginWorldX,
    required double tileW,
    required double tileH,
    required double componentWorldLeft,
    required Rect visibleWorld,
    required bool isScrollForward,
  }) {
    if (tileW < 1 || visibleWorld.isEmpty) {
      return Rect.zero;
    }

    final step = isScrollForward ? tileW : -tileW;
    final i0 = ((visibleWorld.left - tileGridOriginWorldX) / tileW).floor() - 1;
    final i1 = ((visibleWorld.right - tileGridOriginWorldX) / tileW).ceil() + 1;
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    for (var i = i0; i <= i1; i++) {
      final trueWorldLeft = tileGridOriginWorldX + i * step;
      final localX = pseudo3D.projectedWorldX(trueWorldLeft, depthMeters) -
          componentWorldLeft;
      minX = math.min(minX, localX);
      maxX = math.max(maxX, localX + tileW);
    }
    if (!minX.isFinite || !maxX.isFinite) {
      return Rect.zero;
    }
    return Rect.fromLTRB(minX, 0, maxX, tileH);
  }
}
