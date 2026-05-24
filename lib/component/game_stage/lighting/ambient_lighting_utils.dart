import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'day_night_schedule.dart';

/// 環境光ティントの時間帯プロファイル。
enum AmbientLightingProfile {
  day,
  dawnMorning,
  evening,
  night,
}

/// 時間帯に応じた環境光ティントの共通計算。
class AmbientLightingUtils {
  AmbientLightingUtils._();

  /// 環境光の色味ティント強度 (1.0=フル)。暗さ (alpha) には適用しない。
  static const double overlayStrength = 0.5;

  static AmbientLightingProfile profileForTime(int hour, int minute) {
    return DayNightSchedule.profileFor(hour, minute);
  }

  static Color desaturateColor(Color color, double factor) {
    final double r = color.red / 255.0;
    final double g = color.green / 255.0;
    final double b = color.blue / 255.0;

    final double gray = 0.299 * r + 0.587 * g + 0.114 * b;

    final double newR = r + (gray - r) * factor;
    final double newG = g + (gray - g) * factor;
    final double newB = b + (gray - b) * factor;

    return Color.fromARGB(
      color.alpha,
      (newR * 255).round().clamp(0, 255),
      (newG * 255).round().clamp(0, 255),
      (newB * 255).round().clamp(0, 255),
    );
  }

  static Color _scaleBrightness(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red * factor).round().clamp(0, 255),
      (color.green * factor).round().clamp(0, 255),
      (color.blue * factor).round().clamp(0, 255),
    );
  }

  static Color _warmBias(Color color) {
    return Color.fromARGB(
      color.alpha,
      (color.red * 1.04).round().clamp(0, 255),
      (color.green * 1.02).round().clamp(0, 255),
      (color.blue * 0.88).round().clamp(0, 255),
    );
  }

  static Color processAmbientColor(
    Color skyColor,
    AmbientLightingProfile profile,
  ) {
    switch (profile) {
      case AmbientLightingProfile.dawnMorning:
        return _scaleBrightness(desaturateColor(skyColor, 0.4), 0.75);
      case AmbientLightingProfile.evening:
        return _scaleBrightness(
          _warmBias(desaturateColor(skyColor, 0.35)),
          0.50,
        );
      case AmbientLightingProfile.night:
        return _scaleBrightness(desaturateColor(skyColor, 0.6), 0.45);
      case AmbientLightingProfile.day:
        return desaturateColor(skyColor, 0.6);
    }
  }

  /// 画面オーバーレイ用の環境光色 (0–1)。
  static ({double r, double g, double b}) ambientColorRgb(
    Color skyColor, {
    required int hour,
    required int minute,
  }) {
    final profile = profileForTime(hour, minute);
    final adjusted = processAmbientColor(skyColor, profile);
    return (
      r: adjusted.red / 255.0,
      g: adjusted.green / 255.0,
      b: adjusted.blue / 255.0,
    );
  }

  static double _maxWorldTintAlpha(AmbientLightingProfile profile) {
    switch (profile) {
      case AmbientLightingProfile.dawnMorning:
      case AmbientLightingProfile.evening:
      case AmbientLightingProfile.night:
        return 0.08;
      case AmbientLightingProfile.day:
        return 0.0;
    }
  }

  /// ワールドスプライト向けの薄い overlay 色。
  static Color? computeWorldTint(
    Color skyColor,
    double ambientBrightness, {
    required int hour,
    required int minute,
  }) {
    if (ambientBrightness <= 0.01) {
      return null;
    }

    final profile = profileForTime(hour, minute);
    final maxAlpha = _maxWorldTintAlpha(profile) * overlayStrength;
    if (maxAlpha <= 0.0) {
      return null;
    }

    final processed = processAmbientColor(skyColor, profile);
    final alpha = ui.lerpDouble(0.0, maxAlpha, ambientBrightness)!;
    return processed.withValues(alpha: alpha);
  }

  static ColorFilter? computeWorldColorFilter(
    Color skyColor,
    double ambientBrightness, {
    required int hour,
    required int minute,
  }) {
    final tint = computeWorldTint(
      skyColor,
      ambientBrightness,
      hour: hour,
      minute: minute,
    );
    if (tint == null) {
      return null;
    }
    return ColorFilter.mode(tint, BlendMode.srcATop);
  }

  /// スプライトコンポーネントへ環境光 [ColorFilter] を再帰的に適用する。
  static void applyColorFilterToSprites(
    Component root,
    ColorFilter? filter,
  ) {
    if (root is SpriteComponent) {
      root.paint.colorFilter = filter;
    }
    for (final child in root.children) {
      applyColorFilterToSprites(child, filter);
    }
  }
}
