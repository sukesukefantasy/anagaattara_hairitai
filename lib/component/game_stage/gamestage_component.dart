import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../depth_zoom_visual.dart';
import '../../main.dart';
import '../../scene/abstract_outdoor_scene.dart';
import 'building/building_data.dart';
import 'lighting/camera_viewport_coords.dart';
import 'lighting/light_receiver.dart';
import 'lighting/lighting_participation.dart';
import 'lighting/lighting_participant.dart';
import 'lighting/sun_modulate_mask.dart';

class GameStageComponent extends RectangleComponent
    with
        HasGameReference<MyGame>,
        LightingParticipant,
        LightReceiver,
        DepthZoomVisual {
  final BackgroundData data;
  late final Sprite _backgroundSprite;
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

  int get renderPriority => data.resolveRenderPriority();

  double get parallaxEffect => data.parallaxEffect;

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
    _backgroundSprite = await Sprite.load(
      data.imagePath,
      srcPosition: data.srcPosition,
      srcSize: data.srcSize,
    );
  }

  void resetPositions(Vector2 gameSize) {
    position.y = (gameSize.y - size.y) + (data.groundOffset ?? 0);
    if (isMounted) {
      game.cameraController.syncDepthZoom();
    }
  }

  @override
  void render(Canvas canvas) {
    renderWithComponentLighting(canvas, (layerCanvas) {
      paintWithDepthZoom(layerCanvas, _renderBackground);
    });
  }

  Rect _loopVisibleWorldForDepthZoom() {
    var vis = CameraViewportCoords.loopStageVisibleWorldRect(
      game.camera.visibleWorldRect,
    );
    final factor = depthZoomRenderFactor;
    if (loop && (factor - 1.0).abs() > 1e-6) {
      vis = CameraViewportCoords.inflateWorldRectHorizontally(
        vis,
        1.0 / factor,
        depthZoomFocusWorld?.x ?? game.cameraController.cameraAnchor.position.x,
      );
    }
    return vis;
  }

  void _renderBackground(Canvas canvas) {
    final sunModulate = _sunModulatePaint();
    if (loop) {
      paintLoopTiles(
        canvas: canvas,
        sprite: _backgroundSprite,
        tileW: _tileWidth,
        tileH: data.srcSize.y,
        originWorldX: absoluteTopLeftPosition.x,
        visibleWorld: _loopVisibleWorldForDepthZoom(),
        isScrollForward: isScrollForward,
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
    required Sprite sprite,
    required double tileW,
    required double tileH,
    required double originWorldX,
    required Rect visibleWorld,
    required bool isScrollForward,
    Paint? overridePaint,
  }) {
    if (tileW < 1 || visibleWorld.isEmpty) {
      return;
    }

    final step = isScrollForward ? tileW : -tileW;
    final i0 = ((visibleWorld.left - originWorldX) / tileW).floor() - 1;
    final i1 = ((visibleWorld.right - originWorldX) / tileW).ceil() + 1;
    final tileSize = Vector2(tileW, tileH);

    for (var i = i0; i <= i1; i++) {
      sprite.render(
        canvas,
        position: Vector2(i * step, 0),
        size: tileSize,
        overridePaint: overridePaint,
      );
    }
  }

  /// PC オーバーレイ用: 可視タイル群を包むワールド矩形。
  static Rect visibleLoopLayerWorldRect({
    required double originWorldX,
    required double originWorldY,
    required double tileW,
    required double tileH,
    required Rect visibleWorld,
    required bool isScrollForward,
  }) {
    if (tileW < 1 || visibleWorld.isEmpty) {
      return Rect.zero;
    }

    final step = isScrollForward ? tileW : -tileW;
    final i0 = ((visibleWorld.left - originWorldX) / tileW).floor() - 1;
    final i1 = ((visibleWorld.right - originWorldX) / tileW).ceil() + 1;
    final localLeft = i0 * step;
    final localRight = i1 * step + tileW;
    final left = originWorldX + math.min(localLeft, localRight);
    final right = originWorldX + math.max(localLeft, localRight);
    return Rect.fromLTRB(left, originWorldY, right, originWorldY + tileH);
  }
}
