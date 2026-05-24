import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../depth_zoom_visual.dart';
import '../../../main.dart';
import '../../../scene/abstract_outdoor_scene.dart';
import '../../item/lantern_item.dart';
import '../gamestage_component.dart';
import 'canvas_light_rings.dart';
import 'light_emitter.dart';
import 'light_emitter_spec.dart';
import 'light_receiver.dart';
import 'lighting_band_clip.dart';
import 'lighting_constants.dart';
import 'lighting_mask_catalog.dart';
import 'lighting_mask_handle.dart';
import 'lighting_participant.dart';
import 'lighting_participation.dart';
import 'camera_viewport_coords.dart';
import 'lantern_strip_light_registry.dart';
import 'lighting_world.dart';
import 'participant_dark_curtain.dart';

/// コンポーネント単位の太陽暗化 + ランタン（マスク不透明画素のみ）。
abstract final class LightReceiverRenderer {
  LightReceiverRenderer._();

  static final Set<int> _missingMaskWarned = {};

  static void renderReceiver({
    required Canvas canvas,
    required PositionComponent receiver,
    required LightingParticipant participant,
    required void Function(Canvas canvas) drawContent,
    required int maskFrameIndex,
  }) {
    final game = _gameOf(receiver);
    if (game == null) {
      drawContent(canvas);
      return;
    }

    final scene = game.sceneManager.currentScene;
    if (scene is! AbstractOutdoorScene) {
      drawContent(canvas);
      return;
    }

    final world = scene.lightingWorld;
    final atlas = receiver is LightReceiver
        ? receiver.lightingMaskAtlas
        : LightingMaskCatalog.atlasFor(receiver);
    final maskFrame = atlas?.frameAt(maskFrameIndex);
    final participation = participant.lightingParticipation;
    final bandClip = LightingBandClip.usesVisibleBandClip(receiver);

    final ambientBase = world.sunState.ambientBrightness;
    final sunDark = world.sunDarknessFor(participation: participation);

    var fullLayerRect = maskFrame?.localBounds ??
        Rect.fromLTWH(0, 0, receiver.size.x, receiver.size.y);
    if (fullLayerRect.isEmpty) {
      fullLayerRect = Rect.fromLTWH(0, 0, receiver.size.x, receiver.size.y);
    }

    final hasSilhouetteMask = maskFrame != null &&
        atlas != null &&
        atlas.isReady &&
        !atlas.isFullRect;

    final camera = game.camera;
    final zoom = camera.viewfinder.zoom;
    var paintRect = bandClip
        ? (LightingBandClip.usesLoopWorldWidthBand(receiver)
            ? CameraViewportCoords.visibleLoopLayerBandLocal(
                receiver,
                camera,
              )
            : CameraViewportCoords.visibleHorizontalBandLocal(
                receiver,
                camera,
              ))
        : fullLayerRect;

    if (bandClip &&
        paintRect.isEmpty &&
        !LightingBandClip.usesLoopWorldWidthBand(receiver)) {
      final worldRect = receiver.toAbsoluteRect();
      final vis = camera.visibleWorldRect;
      if (vis.right > worldRect.left && vis.left < worldRect.right) {
        paintRect = Rect.fromLTWH(0, 0, receiver.size.x, receiver.size.y);
      }
    }

    var effectiveBandClip = bandClip;
    if (receiver is DepthZoomVisual) {
      final depthFactor = receiver.depthZoomRenderFactor;
      if ((depthFactor - 1.0).abs() > 1e-6) {
        if (receiver is GameStageComponent && receiver.loop) {
          // ループ遠景: タイル側で可視域カリング済み。帯 clip はズームで内側に食い込むため無効化。
          effectiveBandClip = false;
        } else if (effectiveBandClip && !paintRect.isEmpty) {
          paintRect = CameraViewportCoords.inflateBandForDepthZoom(
            paintRect,
            depthFactor,
            receiver.depthZoomPivotLocal,
          );
        }
      }
    }

    final needsSun = _needsSunDarkening(sunDark);

    final tintR = world.sunState.tintR;
    final tintG = world.sunState.tintG;
    final tintB = world.sunState.tintB;

    if (effectiveBandClip && paintRect.isEmpty) {
      return;
    }

    _drawContentDirect(
      canvas: canvas,
      bandClip: effectiveBandClip,
      paintRect: paintRect,
      drawContent: drawContent,
    );

    // 遠景・近景シルエット: 暗さは [GameStageComponent] 側の modulate で付与（空との境目を揃える）。
    if (participation == LightingParticipation.none) {
      return;
    }

    if (!needsSun) {
      return;
    }

    final curtainRect = bandClip ? paintRect : fullLayerRect;
    if (curtainRect.isEmpty) {
      return;
    }

    final wantsPunch =
        ambientBase > 0.001 && participation == LightingParticipation.full;

    final canApplyVeil = hasSilhouetteMask ||
        participation != LightingParticipation.full;

    if (!canApplyVeil) {
      if (participation == LightingParticipation.full) {
        _warnMissingMask(receiver);
      }
      return;
    }

    ParticipantDarkCurtain.beginVeilOverlay(canvas, curtainRect);

    if (hasSilhouetteMask) {
      ParticipantDarkCurtain.paintMaskedSunVeil(
        canvas: canvas,
        layerRect: curtainRect,
        maskFrame: maskFrame,
        sunDark: sunDark,
        tintR: tintR,
        tintG: tintG,
        tintB: tintB,
      );
    } else {
      ParticipantDarkCurtain.paintSunVeilFill(
        canvas: canvas,
        layerRect: curtainRect,
        sunDark: sunDark,
        tintR: tintR,
        tintG: tintG,
        tintB: tintB,
      );
    }

    if (wantsPunch) {
      final punchBounds = bandClip
          ? _stripRelightBounds(paintRect, zoom, receiver)
          : fullLayerRect;
      LanternStripLightRegistry.instance.drawBakedPunches(
        canvas: canvas,
        receiver: receiver,
        boundsRect: punchBounds,
      );
      final carriedEmitters = _carriedLanternDynamicEmitters(game);
      if (bandClip) {
        for (final emitter in carriedEmitters) {
          final punchDepth = lightingReceiverDepthFactor(
            participant: participant,
            component: receiver,
            emitters: [emitter],
          );
          _drawDynamicStripPunch(
            canvas: canvas,
            receiver: receiver,
            boundsRect: punchBounds,
            emitter: emitter,
            ambientBase: ambientBase,
            depthFactor: punchDepth,
          );
        }
      } else if (hasSilhouetteMask) {
        for (final emitter in carriedEmitters) {
          final punchDepth = lightingReceiverDepthFactor(
            participant: participant,
            component: receiver,
            emitters: [emitter],
          );
          _drawDynamicSilhouettePunch(
            canvas: canvas,
            layerRect: fullLayerRect,
            maskFrame: maskFrame,
            receiver: receiver,
            emitter: emitter,
            ambientBase: ambientBase,
            depthFactor: punchDepth,
          );
        }
      }
      if (hasSilhouetteMask) {
        ParticipantDarkCurtain.clipToSilhouette(
          canvas,
          maskFrame,
          layerRect: curtainRect,
        );
      }
    }

    ParticipantDarkCurtain.closeVeilOverlay(canvas);
  }

  static void _drawDynamicStripPunch({
    required Canvas canvas,
    required PositionComponent receiver,
    required Rect boundsRect,
    required LightEmitter emitter,
    required double ambientBase,
    required double depthFactor,
  }) {
    if (ambientBase <= 0.001 || depthFactor <= 0.01) {
      return;
    }
    final lightCenter = _worldToLocalOffset(receiver, emitter.worldCenter);
    final outerLocal = emitter.profile.outerRadius * emitter.radiusScale;
    if (outerLocal < 1.0) {
      return;
    }
    if (!_rectOverlapsLightPool(boundsRect, lightCenter, outerLocal)) {
      return;
    }
    final poolRect = _lightPoolLocalRect(boundsRect, lightCenter, outerLocal);
    if (poolRect.isEmpty) {
      return;
    }
    final gradient = _buildRelightWeightGradient(
      lightCenter: lightCenter,
      emitter: emitter,
      outerLocal: outerLocal,
      depthFactor: depthFactor,
      ambientDarkness: ambientBase,
    );
    if (gradient == null) {
      return;
    }
    canvas.save();
    canvas.clipRect(poolRect);
    ParticipantDarkCurtain.punchVeilGradient(
      canvas: canvas,
      poolRect: poolRect,
      gradient: gradient,
    );
    canvas.restore();
  }

  static void _drawDynamicSilhouettePunch({
    required Canvas canvas,
    required Rect layerRect,
    required LightingMaskFrame maskFrame,
    required PositionComponent receiver,
    required LightEmitter emitter,
    required double ambientBase,
    required double depthFactor,
  }) {
    if (ambientBase <= 0.001 || depthFactor <= 0.01) {
      return;
    }
    final lightCenter = _worldToLocalOffset(receiver, emitter.worldCenter);
    final outerLocal = emitter.profile.outerRadius * emitter.radiusScale;
    if (outerLocal < 1.0) {
      return;
    }
    if (!_rectOverlapsLightPool(layerRect, lightCenter, outerLocal)) {
      return;
    }
    final poolRect = _lightPoolLocalRect(layerRect, lightCenter, outerLocal);
    if (poolRect.isEmpty) {
      return;
    }
    final gradient = _buildRelightWeightGradient(
      lightCenter: lightCenter,
      emitter: emitter,
      outerLocal: outerLocal,
      depthFactor: depthFactor,
      ambientDarkness: ambientBase,
    );
    if (gradient == null) {
      return;
    }

    canvas.save();
    canvas.clipRect(poolRect);
    ParticipantDarkCurtain.punchVeilGradient(
      canvas: canvas,
      poolRect: poolRect,
      gradient: gradient,
    );
    canvas.restore();
  }

  static void drawMaskDstIn(
    Canvas canvas,
    LightingMaskFrame maskFrame, {
    Rect? layerRect,
  }) {
    _drawMaskDstIn(canvas, maskFrame, layerRect: layerRect);
  }

  /// 運搬中ランタンのみ動的 punch（設置灯は baked）。
  static List<LightEmitter> _carriedLanternDynamicEmitters(MyGame game) {
    final carried = game.player.carriedItem;
    if (carried is LanternItem && carried.isMounted && carried.isActive) {
      return [carried];
    }
    return const [];
  }

  static Rect stripLanternPoolRect({
    required PositionComponent receiver,
    required Rect boundsRect,
    required LightEmitter emitter,
  }) {
    final lightCenter = _worldToLocalOffset(receiver, emitter.worldCenter);
    final outerLocal = emitter.profile.outerRadius * emitter.radiusScale;
    if (outerLocal < 1.0) {
      return Rect.zero;
    }
    if (!_rectOverlapsLightPool(boundsRect, lightCenter, outerLocal)) {
      return Rect.zero;
    }
    return _lightPoolLocalRect(boundsRect, lightCenter, outerLocal);
  }

  /// 1 灯分: ベール dstOut 用 relight 重みマスク。
  static Future<StripLanternBakedMasks?> bakeStripLanternPunchMask({
    required PositionComponent receiver,
    required Rect poolRect,
    required LightEmitter emitter,
    required double ambientBase,
    required double depthFactor,
  }) async {
    if (poolRect.isEmpty) {
      return null;
    }

    final lightCenter = _worldToLocalOffset(receiver, emitter.worldCenter);
    final outerLocal = emitter.profile.outerRadius * emitter.radiusScale;
    if (outerLocal < 1.0) {
      return null;
    }

    final punchMask = await _bakePunchMaskImage(
      poolRect: poolRect,
      lightCenter: lightCenter,
      emitter: emitter,
      outerLocal: outerLocal,
      depthFactor: depthFactor,
      ambientDarkness: ambientBase,
    );
    if (punchMask == null) {
      return null;
    }
    return StripLanternBakedMasks(punchMask: punchMask);
  }

  static void drawBakedPunchMask({
    required Canvas canvas,
    required Rect poolRect,
    ui.Image? punchMask,
  }) {
    if (poolRect.isEmpty || punchMask == null) {
      return;
    }
    ParticipantDarkCurtain.punchVeil(
      canvas: canvas,
      poolRect: poolRect,
      punchMask: punchMask,
    );
  }

  static Future<ui.Image?> _bakePunchMaskImage({
    required Rect poolRect,
    required Offset lightCenter,
    required LightEmitter emitter,
    required double outerLocal,
    required double depthFactor,
    required double ambientDarkness,
  }) async {
    final gradient = _buildRelightWeightGradient(
      lightCenter: lightCenter,
      emitter: emitter,
      outerLocal: outerLocal,
      depthFactor: depthFactor,
      ambientDarkness: ambientDarkness,
    );
    if (gradient == null) {
      return null;
    }

    final recorder = ui.PictureRecorder();
    final bakeCanvas = Canvas(recorder);
    bakeCanvas.translate(-poolRect.left, -poolRect.top);
    bakeCanvas.drawRect(
      poolRect,
      Paint()
        ..shader = gradient
        ..blendMode = BlendMode.srcOver,
    );

    final picture = recorder.endRecording();
    final w = poolRect.width.ceil().clamp(1, 4096);
    final h = poolRect.height.ceil().clamp(1, 4096);
    return picture.toImage(w, h);
  }

  static bool _needsSunDarkening(double sunDark) => sunDark > 0.001;

  static void _drawContentDirect({
    required Canvas canvas,
    required bool bandClip,
    required Rect paintRect,
    required void Function(Canvas canvas) drawContent,
  }) {
    if (bandClip) {
      canvas.save();
      canvas.clipRect(paintRect);
      drawContent(canvas);
      canvas.restore();
    } else {
      drawContent(canvas);
    }
  }

  static void _warnMissingMask(PositionComponent receiver) {
    final id = identityHashCode(receiver);
    if (_missingMaskWarned.add(id)) {
      debugPrint(
        'LightReceiverRenderer: no silhouette mask for '
        '${receiver.runtimeType} — lighting skipped. '
        'Ensure LightingMaskCatalog.bakeScene / bakeAndRegister ran.',
      );
    }
  }

  static Offset _worldToLocalOffset(
    PositionComponent receiver,
    Vector2 worldPoint,
  ) {
    return CameraViewportCoords.worldOffsetToLocal(
      receiver,
      Offset(worldPoint.x, worldPoint.y),
    );
  }

  static MyGame? _gameOf(Component component) {
    if (component is HasGameReference<MyGame>) {
      return component.game;
    }
    return null;
  }

  static double _stripVisibilityPaddingWorld(double zoom) {
    const maxRadiusScale = 1.0 + 0.01;
    final base =
        LightEmitterSpec.lantern.profile.outerRadius * maxRadiusScale;
    final edgePad = kLightingScreenEdgePadding / zoom;
    const minEdgePadWorld = 48.0;
    return base + math.max(edgePad, minEdgePadWorld);
  }

  static Rect _stripRelightBounds(
    Rect drawBand,
    double zoom,
    PositionComponent receiver,
  ) {
    final pad = _stripVisibilityPaddingWorld(zoom);
    return drawBand
        .inflate(pad)
        .intersect(Rect.fromLTWH(0, 0, receiver.size.x, receiver.size.y));
  }

  static Rect _lightPoolLocalRect(
    Rect activeRect,
    Offset lightCenter,
    double outerLocal,
  ) {
    final pool = Rect.fromCircle(
      center: lightCenter,
      radius: outerLocal + kLightingScreenEdgePadding,
    );
    return activeRect.intersect(pool);
  }

  static bool _rectOverlapsLightPool(
    Rect bounds,
    Offset lightCenter,
    double outerRadius,
  ) {
    final pool = Rect.fromCircle(
      center: lightCenter,
      radius: outerRadius + kLightingScreenEdgePadding,
    );
    return bounds.overlaps(pool);
  }

  static void _drawMaskDstIn(
    Canvas canvas,
    LightingMaskFrame maskFrame, {
    Rect? layerRect,
  }) {
    final image = maskFrame.image;
    final bounds = maskFrame.localBounds;
    if (bounds.isEmpty) {
      return;
    }

    final dest = layerRect == null ? bounds : layerRect.intersect(bounds);
    if (dest.isEmpty) {
      return;
    }

    final bw = bounds.width;
    final bh = bounds.height;
    if (bw < 1e-6 || bh < 1e-6) {
      return;
    }

    final src = Rect.fromLTRB(
      (dest.left - bounds.left) / bw * image.width,
      (dest.top - bounds.top) / bh * image.height,
      (dest.right - bounds.left) / bw * image.width,
      (dest.bottom - bounds.top) / bh * image.height,
    );

    canvas.drawImageRect(
      image,
      src,
      dest,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..filterQuality = FilterQuality.none,
    );
  }

  static ui.Gradient? _buildRelightWeightGradient({
    required Offset lightCenter,
    required LightEmitter emitter,
    required double outerLocal,
    required double depthFactor,
    required double ambientDarkness,
  }) {
    final profile = emitter.profile;
    const localZoom = 1.0;
    final innerStop =
        (profile.innerRadius * emitter.radiusScale / outerLocal)
            .clamp(0.0, 1.0);
    var midStop =
        (profile.midRadius * emitter.radiusScale / outerLocal)
            .clamp(innerStop, 1.0);
    if (midStop <= innerStop) {
      midStop = (innerStop + 1e-4).clamp(0.0, 1.0);
    }

    double weightAt(double norm) {
      final cut = CanvasLightRings.ringCut(
        norm * outerLocal,
        profile,
        localZoom,
        emitter.radiusScale,
      );
      return CanvasLightRings.relightAlpha(
        cut,
        depthFactor,
        ambientDarkness,
      );
    }

    final centerW = weightAt(0);
    final midW = weightAt(midStop);
    if (centerW < 0.001 && midW < 0.001) {
      return null;
    }

    int byte(double a) => (a.clamp(0.0, 1.0) * 255).round();

    return ui.Gradient.radial(
      lightCenter,
      outerLocal,
      [
        Color.fromARGB(byte(centerW), 255, 255, 255),
        Color.fromARGB(byte(centerW), 255, 255, 255),
        Color.fromARGB(byte(midW), 255, 255, 255),
        const Color.fromARGB(0, 255, 255, 255),
      ],
      [0.0, innerStop, midStop, 1.0],
    );
  }
}

/// strip 用ベイク済み punch（暗幕ベール dstOut 用）。
final class StripLanternBakedMasks {
  const StripLanternBakedMasks({this.punchMask});

  final ui.Image? punchMask;

  void dispose() {
    punchMask?.dispose();
  }
}
