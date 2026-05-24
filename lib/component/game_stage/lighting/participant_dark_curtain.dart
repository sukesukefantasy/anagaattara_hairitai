import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'lighting_mask_handle.dart';
import 'light_receiver_renderer.dart';
import 'sun_modulate_mask.dart';

/// 参加者ローカルの暗幕（素描画の上に alpha ベール・不透明ピクセル形状のみ）。
abstract final class ParticipantDarkCurtain {
  ParticipantDarkCurtain._();

  static void beginVeilOverlay(Canvas canvas, Rect layerRect) {
    canvas.saveLayer(layerRect, Paint());
  }

  static void closeVeilOverlay(Canvas canvas) {
    canvas.restore();
  }

  static void paintSunVeilFill({
    required Canvas canvas,
    required Rect layerRect,
    required double sunDark,
    required double tintR,
    required double tintG,
    required double tintB,
  }) {
    if (sunDark <= 0.001 || layerRect.isEmpty) {
      return;
    }

    final color = SunModulateMask.veilColor(
      darkness: sunDark,
      tintR: tintR,
      tintG: tintG,
      tintB: tintB,
    );
    if (color.a <= 0.001) {
      return;
    }

    canvas.drawRect(
      layerRect,
      Paint()
        ..color = color
        ..blendMode = BlendMode.srcOver,
    );
  }

  /// シルエット形状だけベール（サブ saveLayer なし・呼び出し元の layer 内で実行）。
  static void paintMaskedSunVeil({
    required Canvas canvas,
    required Rect layerRect,
    required LightingMaskFrame maskFrame,
    required double sunDark,
    required double tintR,
    required double tintG,
    required double tintB,
  }) {
    if (sunDark <= 0.001 || layerRect.isEmpty) {
      return;
    }

    paintSunVeilFill(
      canvas: canvas,
      layerRect: layerRect,
      sunDark: sunDark,
      tintR: tintR,
      tintG: tintG,
      tintB: tintB,
    );
    clipToSilhouette(canvas, maskFrame, layerRect: layerRect);
  }

  static void clipToSilhouette(
    Canvas canvas,
    LightingMaskFrame maskFrame, {
    Rect? layerRect,
  }) {
    LightReceiverRenderer.drawMaskDstIn(
      canvas,
      maskFrame,
      layerRect: layerRect,
    );
  }

  static void punchVeil({
    required Canvas canvas,
    required Rect poolRect,
    required ui.Image punchMask,
  }) {
    if (poolRect.isEmpty) {
      return;
    }
    final src = Rect.fromLTWH(
      0,
      0,
      punchMask.width.toDouble(),
      punchMask.height.toDouble(),
    );
    canvas.drawImageRect(
      punchMask,
      src,
      poolRect,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..filterQuality = FilterQuality.none,
    );
  }

  static void punchVeilGradient({
    required Canvas canvas,
    required Rect poolRect,
    required ui.Gradient gradient,
  }) {
    if (poolRect.isEmpty) {
      return;
    }
    canvas.drawRect(
      poolRect,
      Paint()
        ..shader = gradient
        ..blendMode = BlendMode.dstOut,
    );
  }
}
