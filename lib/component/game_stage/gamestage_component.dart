import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../depth_zoom_visual.dart';
import '../../game/pseudo3d_camera.dart';
import '../../game/world_scale.dart';
import '../../main.dart';
import '../../scene/abstract_outdoor_scene.dart';
import 'building/building_data.dart';
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

  /// コンストラクタでの明示上書き（未指定時は [BackgroundData.loopHorizontal]）。
  final bool loop;

  /// 水平タイルループを使うか（[loop] または [BackgroundData.loopHorizontal]）。
  bool get usesHorizontalLoop => loop || data.loopHorizontal;

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
    priority = data.resolveRenderPriority();
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
    if (usesHorizontalLoop) {
      final strip = WorldScale.loopStageStripBounds(
        _tileWidth,
        marginSlots: data.loopMarginSlots,
      );
      position.x = strip.left;
      size.x = strip.width;
      size.y = data.srcSize.y;
    } else if (isMounted) {
      game.cameraController.syncDepthZoom();
    }
  }

  bool get _useOutdoorPseudo3D =>
      usesHorizontalLoop &&
      game.sceneManager.currentScene is AbstractOutdoorScene;

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
      if (_useOutdoorPseudo3D || (_isOutdoorScene && !usesHorizontalLoop)) {
        _paintWithOutdoorDepthZoom(layerCanvas, _renderBackground);
      } else {
        paintWithDepthZoom(layerCanvas, _renderBackground);
      }
    });
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
      componentWorldLeft: absoluteTopLeftPosition.x,
      marginSlots: data.loopMarginSlots,
      overridePaint: overridePaint,
    );
  }

  void _renderBackground(Canvas canvas) {
    final sunModulate = _sunModulatePaint();
    if (usesHorizontalLoop) {
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

  /// ステージ固定タイル列を描画（カリングはカメラ任せ）。
  static void paintLoopTiles({
    required Canvas canvas,
    required Pseudo3DCamera pseudo3D,
    required double depthMeters,
    required Sprite sprite,
    required double tileW,
    required double tileH,
    required double componentWorldLeft,
    int marginSlots = 0,
    Paint? overridePaint,
  }) {
    if (tileW < 1) {
      return;
    }

    final tileCount = WorldScale.loopStageTileCount(tileW);
    if (tileCount <= 0) {
      return;
    }

    final slots =
        WorldScale.loopStagePaintSlotRange(tileCount, marginSlots: marginSlots);
    final stripLeft = WorldScale.loopStageTileTrueLeft(slots.start, tileW);
    // 各スロットを個別射影すると見かけ幅が tileW*s になりフル画像が重なる。
    // ストリップ左端だけパララックスし、タイル間は常に tileW 刻みで並べる。
    final baseProjectedX =
        pseudo3D.projectedWorldX(stripLeft, depthMeters);
    final tileSpan = slots.endInclusive - slots.start + 1;
    for (var i = 0; i < tileSpan; i++) {
      final localX = baseProjectedX + i * tileW - componentWorldLeft;
      sprite.render(
        canvas,
        position: Vector2(localX, 0),
        size: Vector2(tileW, tileH),
        overridePaint: overridePaint,
      );
    }
  }

  /// ライティングマスク用: 射影後タイル群のローカル矩形（[paintLoopTiles] と同じスロット列）。
  static Rect projectedLoopLocalBounds({
    required Pseudo3DCamera pseudo3D,
    required double depthMeters,
    required double tileW,
    required double tileH,
    required double componentWorldLeft,
    int marginSlots = 0,
    double depthZoomFactor = 1.0,
  }) {
    if (tileW < 1) {
      return Rect.zero;
    }

    final tileCount = WorldScale.loopStageTileCount(tileW);
    if (tileCount <= 0) {
      return Rect.zero;
    }

    final slots =
        WorldScale.loopStagePaintSlotRange(tileCount, marginSlots: marginSlots);
    final stripLeft = WorldScale.loopStageTileTrueLeft(slots.start, tileW);
    final baseProjectedX =
        pseudo3D.projectedWorldX(stripLeft, depthMeters);
    final minX = baseProjectedX - componentWorldLeft;
    final tileSpan = slots.endInclusive - slots.start + 1;
    final maxX = minX + tileSpan * tileW;
    final extraTop = tileH * ((depthZoomFactor - 1.0).clamp(0.0, 8.0));
    final minY = -extraTop;
    final maxY = tileH;
    if (!minX.isFinite || !maxX.isFinite) {
      return Rect.zero;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
