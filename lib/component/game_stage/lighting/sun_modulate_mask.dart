import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 太陽暗化用色（時間帯・tint）。
///
/// - **alpha ベール**: [veilColor] を saveLayer 上に srcOver → 素描画の上に合成。
/// - **レガシー modulate**: [apply] / [modulateColor]（シェーダー経路等）。
abstract final class SunModulateMask {
  SunModulateMask._();

  static ui.Image? _unitImage;
  static Future<void>? _warmFuture;

  static Future<void> warmUp() {
    return _warmFuture ??= _createUnitImage();
  }

  static Future<void> _createUnitImage() async {
    if (_unitImage != null) {
      return;
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final picture = recorder.endRecording();
    try {
      _unitImage = await picture.toImage(1, 1);
    } finally {
      picture.dispose();
    }
  }

  static void dispose() {
    _unitImage?.dispose();
    _unitImage = null;
    _warmFuture = null;
  }

  /// 時間帯・tint から modulate 色（シェーダー互換）。
  static Color modulateColor({
    required double darkness,
    required double tintR,
    required double tintG,
    required double tintB,
  }) {
    final d = darkness.clamp(0.0, 1.0);
    final keep = (1.0 - d * 0.92).clamp(0.08, 1.0);
    final r = (255 * keep * (1.0 - tintR * 0.55)).round().clamp(0, 255);
    final g = (255 * keep * (1.0 - tintG * 0.55)).round().clamp(0, 255);
    final b = (255 * keep * (1.0 - tintB * 0.55)).round().clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
  }

  /// [modulateColor] を単色塗りに適用した結果（空色・シルエットの環境暗化用）。
  static Color modulateFillColor({
    required Color base,
    required double darkness,
    required double tintR,
    required double tintG,
    required double tintB,
  }) {
    final mod = modulateColor(
      darkness: darkness,
      tintR: tintR,
      tintG: tintG,
      tintB: tintB,
    );
    return Color.fromARGB(
      base.alpha,
      (base.red * mod.red / 255).round().clamp(0, 255),
      (base.green * mod.green / 255).round().clamp(0, 255),
      (base.blue * mod.blue / 255).round().clamp(0, 255),
    );
  }

  /// ローカル暗幕ベール用: 暗色 tint + alpha（srcOver で素描画を暗くする）。
  static Color veilColor({
    required double darkness,
    required double tintR,
    required double tintG,
    required double tintB,
  }) {
    final d = darkness.clamp(0.0, 1.0);
    if (d <= 0.001) {
      return const Color(0x00000000);
    }
    final keep = (1.0 - d * 0.98).clamp(0.04, 1.0);
    final veilAlpha = (1.0 - keep).clamp(0.0, 0.96);
    // modulate 相当の暗さ: 黒ベース + 時間帯 tint（高 RGB の薄白 overlay にしない）。
    final r = (tintR * 48).round().clamp(0, 64);
    final g = (tintG * 40).round().clamp(0, 56);
    final b = (16 + tintB * 72).round().clamp(0, 96);
    return Color.fromARGB(
      (veilAlpha * 255).round().clamp(1, 235),
      r,
      g,
      b,
    );
  }

  /// saveLayer なし: 1×1 画像を伸ばして modulate。
  static void apply({
    required Canvas canvas,
    required Rect layerRect,
    required double darkness,
    required double tintR,
    required double tintG,
    required double tintB,
  }) {
    if (darkness <= 0.001 || layerRect.isEmpty) {
      return;
    }

    final color = modulateColor(
      darkness: darkness,
      tintR: tintR,
      tintG: tintG,
      tintB: tintB,
    );
    canvas.drawRect(
      layerRect,
      Paint()
        ..color = color
        ..blendMode = BlendMode.modulate,
    );
    warmUp();
  }
}
