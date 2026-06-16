import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../common/ground/ground.dart';
import '../../common/underground/underground.dart';
import '../../player_cargo_terminal.dart';
import '../gamestage_component.dart';
import 'lighting_mask_handle.dart';

/// カバレッジのみ（白 RGB + スプライト α）。暗さ・時間帯は含めない。
abstract final class LightingMaskBuilder {
  LightingMaskBuilder._();

  static const int maxMaskLongEdge = 256;

  /// 横長 strip / loop 遠景用（マスク生成）。
  static const int maxStripMaskLongEdge = 512;

  static ui.Image? _sharedUnitWhite;

  static Future<ui.Image> _sharedUnitWhiteImage() async {
    if (_sharedUnitWhite != null) {
      return _sharedUnitWhite!;
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = Colors.white,
    );
    final picture = recorder.endRecording();
    _sharedUnitWhite = await picture.toImage(1, 1);
    picture.dispose();
    return _sharedUnitWhite!;
  }

  static void disposeSharedResources() {
    _sharedUnitWhite?.dispose();
    _sharedUnitWhite = null;
  }

  static Future<LightingMaskFrame?> buildFrame(
    PositionComponent root, {
    int? animationFrameIndex,
  }) async {
    final localBounds = _localVisualBounds(root);
    final paint = Paint()
      ..color = Colors.white
      ..filterQuality = FilterQuality.none;

    return _rasterizeMaskFrame(
      localBounds: localBounds,
      maxLongEdge: maxMaskLongEdge,
      paintContent: (canvas) {
        if (_isRootSpriteReceiver(root)) {
          _paintRootSprite(
            canvas,
            root,
            paint,
            animationFrameIndex: animationFrameIndex,
          );
        } else {
          _paintNode(
            canvas,
            root,
            paint,
            root: root,
            animationFrameIndex: animationFrameIndex,
          );
        }
      },
    );
  }

  static Future<LightingMaskAtlas?> buildAtlas(
    PositionComponent root, {
    List<SpriteAnimation>? animations,
  }) async {
    if (root is SpriteAnimationComponent) {
      final sac = root;
      final toBake = <SpriteAnimation>[];
      if (animations != null && animations.isNotEmpty) {
        final seen = <SpriteAnimation>{};
        for (final anim in animations) {
          if (seen.add(anim)) {
            toBake.add(anim);
          }
        }
      } else if (sac.animation != null) {
        toBake.add(sac.animation!);
      } else {
        final single = await buildFrame(sac);
        if (single == null) {
          return null;
        }
        return LightingMaskAtlas(frames: [single]);
      }

      final frames = <LightingMaskFrame>[];
      final frameBase = <SpriteAnimation, int>{};
      final savedAnimation = sac.animation;
      final savedTicker = sac.animationTicker;
      final savedIndex = savedTicker?.currentIndex ?? 0;

      for (final anim in toBake) {
        frameBase[anim] = frames.length;
        sac.animation = anim;
        final frameCount = anim.frames.length;
        final ticker = sac.animationTicker;
        for (var i = 0; i < frameCount; i++) {
          ticker?.currentIndex = i;
          final built = await buildFrame(sac, animationFrameIndex: i);
          if (built != null) {
            frames.add(built);
          }
        }
      }

      sac.animation = savedAnimation;
      if (savedAnimation != null && savedTicker != null) {
        savedTicker.currentIndex = savedIndex.clamp(
          0,
          savedAnimation.frames.length - 1,
        );
      }

      if (frames.isEmpty) {
        return null;
      }
      return LightingMaskAtlas(
        frames: frames,
        frameBaseByAnimation: frameBase.length > 1 ? frameBase : null,
      );
    }

    final single = await buildFrame(root);
    if (single == null) {
      return null;
    }
    return LightingMaskAtlas(frames: [single]);
  }

  /// [Ground] 用: [paintStripTilesForMask] と同じタイル配置で strip 全幅。
  static Future<LightingMaskAtlas?> generateGroundMask(
    Ground ground,
    MyGame game,
  ) async {
    if (ground.groundSprite == null) {
      return null;
    }

    final bounds = Rect.fromLTWH(0, 0, ground.size.x, ground.size.y);
    final maskPaint = Paint()
      ..color = Colors.white
      ..filterQuality = FilterQuality.none;

    final frame = await _rasterizeMaskFrame(
      localBounds: bounds,
      maxLongEdge: maxStripMaskLongEdge,
      paintContent: (canvas) => ground.paintStripTilesForMask(canvas, maskPaint),
    );
    if (frame == null) {
      return null;
    }
    return LightingMaskAtlas(frames: [frame]);
  }

  /// [UnderGround] 用: フル解像度背景 Picture + トンネル / 床 / 子 Sprite を白+αで描画し、ここで 1 回だけ縮小。
  static Future<LightingMaskAtlas?> generateUnderGroundMask(
    UnderGround underGround,
  ) async {
    final bounds = Rect.fromLTWH(0, 0, underGround.size.x, underGround.size.y);
    final maskPaint = Paint()
      ..color = Colors.white
      ..filterQuality = FilterQuality.none;

    final frame = await _rasterizeMaskFrame(
      localBounds: bounds,
      maxLongEdge: maxStripMaskLongEdge,
      paintContent: (canvas) =>
          underGround.paintStripVisualsForMask(canvas, maskPaint),
    );
    if (frame == null) {
      return null;
    }
    return LightingMaskAtlas(frames: [frame]);
  }

  /// [GameStageComponent.loop] 用: カメラ可動域 X 帯のタイル列。
  static Future<LightingMaskAtlas?> generateLoopGameStageMask(
    GameStageComponent stage,
    MyGame game,
  ) async {
    if (!stage.isLoaded || !stage.usesHorizontalLoop) {
      return null;
    }
    final sprite = stage.backgroundSprite;
    if (sprite == null) {
      return null;
    }

    if (!stage.isMounted) {
      return null;
    }

    final origin = stage.absoluteTopLeftPosition;
    final tileW = stage.data.srcSize.x;
    final tileH = stage.data.srcSize.y;

    final pseudo3D = game.cameraController.outdoorPseudo3D;
    final depthZoomFactor = pseudo3D.depthZoomRenderFactor(stage.depthMeters);
    final localBounds = GameStageComponent.projectedLoopLocalBounds(
      pseudo3D: pseudo3D,
      depthMeters: stage.depthMeters,
      tileW: tileW,
      tileH: tileH,
      componentWorldLeft: origin.x,
      marginSlots: stage.data.loopMarginSlots,
      depthZoomFactor: depthZoomFactor,
    );
    if (localBounds.isEmpty) {
      return null;
    }

    final maskPaint = Paint()
      ..color = Colors.white
      ..filterQuality = FilterQuality.none;

    final frame = await _rasterizeMaskFrame(
      localBounds: localBounds,
      maxLongEdge: maxStripMaskLongEdge,
      paintContent: (canvas) {
        stage.paintLoopBackground(canvas, overridePaint: maskPaint);
      },
    );
    if (frame == null) {
      return null;
    }
    return LightingMaskAtlas(frames: [frame]);
  }

  /// [GameStageComponent] 用（非 loop: 描画位置を render と揃える）。
  static Future<LightingMaskAtlas?> buildGameStageMask(
    GameStageComponent stage,
  ) async {
    if (!stage.isLoaded) {
      return null;
    }
    final sprite = stage.backgroundSprite;
    if (sprite == null) {
      return null;
    }

    if (stage.usesHorizontalLoop) {
      return null;
    }

    final bounds = Rect.fromLTWH(0, 0, stage.size.x, stage.size.y);
    final maskPaint = Paint()
      ..color = Colors.white
      ..filterQuality = FilterQuality.none;

    final frame = await _rasterizeMaskFrame(
      localBounds: bounds,
      maxLongEdge: maxStripMaskLongEdge,
      paintContent: (canvas) {
        sprite.render(
          canvas,
          position: stage.isScrollForward
              ? Vector2.zero()
              : Vector2(-stage.size.x, 0),
          size: stage.size,
          overridePaint: maskPaint,
        );
      },
    );
    if (frame == null) {
      return null;
    }
    return LightingMaskAtlas(frames: [frame]);
  }

  /// 巨大テクスチャを作らず 1x1 白を [localBounds] に伸ばす（空など全面用）。
  static Future<LightingMaskAtlas> buildFullRectMask(Vector2 size) async {
    final image = await _sharedUnitWhiteImage();
    return LightingMaskAtlas(
      frames: [
        LightingMaskFrame(
          image: image,
          localBounds: Rect.fromLTWH(0, 0, size.x, size.y),
          ownsImage: false,
        ),
      ],
      isFullRect: true,
    );
  }

  static Future<LightingMaskFrame?> _rasterizeMaskFrame({
    required Rect localBounds,
    required int maxLongEdge,
    required void Function(Canvas canvas) paintContent,
  }) async {
    final w = localBounds.width;
    final h = localBounds.height;
    if (w < 1 || h < 1 || !w.isFinite || !h.isFinite) {
      return null;
    }

    final longEdge = math.max(w, h);
    final scale = longEdge > maxLongEdge ? maxLongEdge / longEdge : 1.0;
    final outW = math.max(1, (w * scale).round());
    final outH = math.max(1, (h * scale).round());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
    );
    canvas.scale(scale);
    canvas.translate(-localBounds.left, -localBounds.top);
    paintContent(canvas);

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(outW, outH);
      return LightingMaskFrame(image: image, localBounds: localBounds);
    } finally {
      picture.dispose();
    }
  }

  /// ルートが SAC/Sprite の Receiver（Player 等）。子 [PlayerCargoTerminal] は含めない。
  static bool _isRootSpriteReceiver(PositionComponent root) =>
      (root is SpriteComponent || root is SpriteAnimationComponent) &&
      root is! PlayerCargoTerminal;

  /// マスクはワールド表示サイズに合わせる。ソースと同寸付近のみ srcSize（プレイヤー bleed）。
  static Vector2 _maskRenderSize(PositionComponent node, Sprite sprite) {
    final dx = (node.size.x - sprite.srcSize.x).abs();
    final dy = (node.size.y - sprite.srcSize.y).abs();
    if (dx < 2 && dy < 2) {
      return sprite.srcSize;
    }
    return node.size;
  }

  /// ルート 1 枚のみ（[super.render] と同じ範囲）。
  static void _paintRootSprite(
    Canvas canvas,
    PositionComponent root,
    Paint paint, {
    int? animationFrameIndex,
  }) {
    if (root is SpriteComponent) {
      final sprite = root.sprite;
      if (sprite != null && !_hasAnimationChild(root)) {
        sprite.render(
          canvas,
          position: Vector2.zero(),
          size: _maskRenderSize(root, sprite),
          overridePaint: paint,
        );
      }
      return;
    }
    if (root is SpriteAnimationComponent) {
      final sac = root;
      final animation = sac.animation;
      Sprite? sprite;
      if (animation != null &&
          animationFrameIndex != null &&
          animationFrameIndex >= 0 &&
          animationFrameIndex < animation.frames.length) {
        sprite = animation.frames[animationFrameIndex].sprite;
      } else {
        sprite = sac.animationTicker?.getSprite();
      }
      if (sprite != null) {
        sprite.render(
          canvas,
          position: Vector2.zero(),
          size: _maskRenderSize(root, sprite),
          overridePaint: paint,
        );
      }
    }
  }

  static void _paintNode(
    Canvas canvas,
    Component node,
    Paint paint, {
    required PositionComponent root,
    int? animationFrameIndex,
  }) {
    if (node is PositionComponent) {
      final pos = identical(node, root)
          ? Vector2.zero()
          : node.position;

      if (node is SpriteComponent) {
        final sprite = node.sprite;
        if (sprite != null && !_hasAnimationChild(node)) {
          sprite.render(
            canvas,
            position: pos,
            size: _maskRenderSize(node, sprite),
            overridePaint: paint,
          );
        }
      } else if (node is SpriteAnimationComponent) {
        final animation = node.animation;
        Sprite? sprite;
        if (animation != null &&
            animationFrameIndex != null &&
            animationFrameIndex >= 0 &&
            animationFrameIndex < animation.frames.length) {
          sprite = animation.frames[animationFrameIndex].sprite;
        } else {
          sprite = node.animationTicker?.getSprite();
        }
        if (sprite != null) {
          sprite.render(
            canvas,
            position: pos,
            size: _maskRenderSize(node, sprite),
            overridePaint: paint,
          );
        }
      }
    }

    for (final child in node.children) {
      _paintNode(
        canvas,
        child,
        paint,
        root: root,
        animationFrameIndex: animationFrameIndex,
      );
    }
  }

  static bool _hasAnimationChild(PositionComponent component) {
    for (final child in component.children) {
      if (child is SpriteAnimationComponent) {
        return true;
      }
    }
    return false;
  }

  /// [render] と同じコンポーネントローカル座標（原点＝コンポーネント左上）。
  static Rect _localVisualBounds(PositionComponent root) {
    if (_isRootSpriteReceiver(root)) {
      return Rect.fromLTWH(0, 0, root.size.x, root.size.y);
    }

    Rect? bounds;

    void includeChildSpriteBounds(PositionComponent node) {
      if (node.size.x < 1 || node.size.y < 1) {
        return;
      }
      final rect = Rect.fromLTWH(
        node.position.x,
        node.position.y,
        node.size.x,
        node.size.y,
      );
      bounds = bounds == null ? rect : bounds!.expandToInclude(rect);
    }

    void walk(Component node) {
      if (node != root &&
          (node is SpriteComponent || node is SpriteAnimationComponent)) {
        includeChildSpriteBounds(node as PositionComponent);
      }
      for (final child in node.children) {
        walk(child);
      }
    }

    walk(root);

    if (bounds != null && !bounds!.isEmpty) {
      return bounds!;
    }

    return Rect.fromLTWH(0, 0, root.size.x, root.size.y);
  }
}
