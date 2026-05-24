import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ambient_lighting_utils.dart';

/// 時刻に応じた空色・環境光の暗さ・ライティングプロファイル。
class DayNightState {
  const DayNightState({
    required this.skyColor,
    required this.ambientBrightness,
    required this.profile,
  });

  /// 純粋な空の色。
  final Color skyColor;

  /// 環境光の明るさ (0.0=明, 1.0=暗)。
  final double ambientBrightness;

  /// オーバーレイ・ワールド tint 用プロファイル。
  final AmbientLightingProfile profile;
}

/// 時間帯の境界・空色 lerp・ライティング profile の唯一の定義。
abstract final class DayNightSchedule {
  DayNightSchedule._();

  static DayNightState evaluate(int hour, int minute) {
    final totalMinutesInDay = hour * 60 + minute;

    const Color midnightPureSkyColor = Color(0xFF05051F);
    const Color dawnPureSkyColor = Color.fromARGB(255, 255, 165, 0);
    const Color morningTransitionPureSkyColor = Color.fromARGB(
      255,
      255,
      192,
      203,
    );
    const Color dayPureSkyColor = Color.fromARGB(255, 132, 202, 255);
    const Color duskTransitionPureSkyColor = Color.fromARGB(255, 255, 113, 191);
    const Color duskPureSkyColor = Color(0xFFFF7F50);
    const Color nightPureSkyColor = Color(0xFF191970);

    const double midnightDefaultBrightness = 0.7;
    const double dawnDefaultBrightness = 0.55;
    const double morningDefaultBrightness = 0.2;
    const double dayDefaultBrightness = 0.0;
    const double duskDefaultBrightness = 0.38;
    const double nightDefaultBrightness = 0.7;

    late Color skyColor;
    late double ambientBrightness;

    if (totalMinutesInDay >= 4 * 60 && totalMinutesInDay < 5 * 60) {
      final progress = (totalMinutesInDay - (4 * 60)) / 60.0;
      skyColor = Color.lerp(
        midnightPureSkyColor,
        dawnPureSkyColor,
        progress.clamp(0.0, 1.0),
      )!;
      ambientBrightness = ui.lerpDouble(
        midnightDefaultBrightness,
        dawnDefaultBrightness,
        progress.clamp(0.0, 1.0),
      )!;
    } else if (totalMinutesInDay >= 5 * 60 && totalMinutesInDay < 6 * 60) {
      final progress = (totalMinutesInDay - (5 * 60)) / 60.0;
      skyColor = Color.lerp(
        dawnPureSkyColor,
        morningTransitionPureSkyColor,
        progress.clamp(0.0, 1.0),
      )!;
      ambientBrightness = ui.lerpDouble(
        dawnDefaultBrightness,
        morningDefaultBrightness,
        progress.clamp(0.0, 1.0),
      )!;
    } else if (totalMinutesInDay >= 6 * 60 && totalMinutesInDay < 9 * 60) {
      final progress = (totalMinutesInDay - (6 * 60)) / 180.0;
      skyColor = Color.lerp(
        morningTransitionPureSkyColor,
        dayPureSkyColor,
        progress.clamp(0.0, 1.0),
      )!;
      ambientBrightness = ui.lerpDouble(
        morningDefaultBrightness,
        dayDefaultBrightness,
        progress.clamp(0.0, 1.0),
      )!;
    } else if (totalMinutesInDay >= 9 * 60 && totalMinutesInDay < 15 * 60) {
      skyColor = dayPureSkyColor;
      ambientBrightness = dayDefaultBrightness;
    } else if (totalMinutesInDay >= 15 * 60 && totalMinutesInDay < 17 * 60) {
      final progress = (totalMinutesInDay - (15 * 60)) / 120.0;
      skyColor = Color.lerp(
        dayPureSkyColor,
        duskTransitionPureSkyColor,
        progress.clamp(0.0, 1.0),
      )!;
      ambientBrightness = ui.lerpDouble(
        dayDefaultBrightness,
        duskDefaultBrightness,
        progress.clamp(0.0, 1.0),
      )!;
    } else if (totalMinutesInDay >= 17 * 60 && totalMinutesInDay < 18 * 60) {
      final progress = (totalMinutesInDay - (17 * 60)) / 60.0;
      skyColor = Color.lerp(
        duskTransitionPureSkyColor,
        duskPureSkyColor,
        progress.clamp(0.0, 1.0),
      )!;
      ambientBrightness = ui.lerpDouble(
        duskDefaultBrightness,
        nightDefaultBrightness,
        progress.clamp(0.0, 1.0),
      )!;
    } else if (totalMinutesInDay >= 18 * 60 && totalMinutesInDay < 23 * 60) {
      final progress = (totalMinutesInDay - (18 * 60)) / 300.0;
      skyColor = Color.lerp(
        duskPureSkyColor,
        nightPureSkyColor,
        progress.clamp(0.0, 1.0),
      )!;
      ambientBrightness = ui.lerpDouble(
        nightDefaultBrightness,
        midnightDefaultBrightness,
        progress.clamp(0.0, 1.0),
      )!;
    } else if (hour >= 23) {
      final progress = (totalMinutesInDay - (23 * 60)) / 60.0;
      skyColor = Color.lerp(
        nightPureSkyColor,
        midnightPureSkyColor,
        progress.clamp(0.0, 1.0),
      )!;
      ambientBrightness = ui.lerpDouble(
        nightDefaultBrightness,
        midnightDefaultBrightness,
        progress.clamp(0.0, 1.0),
      )!;
    } else {
      skyColor = midnightPureSkyColor;
      ambientBrightness = midnightDefaultBrightness;
    }

    return DayNightState(
      skyColor: skyColor,
      ambientBrightness: ambientBrightness,
      profile: _profileFor(totalMinutesInDay),
    );
  }

  static AmbientLightingProfile profileFor(int hour, int minute) {
    return evaluate(hour, minute).profile;
  }

  /// 4:00–7:59 dawnMorning, 8:00–14:59 day, 15:00–18:59 evening, else night。
  static AmbientLightingProfile _profileFor(int totalMinutesInDay) {
    if (totalMinutesInDay >= 4 * 60 && totalMinutesInDay < 8 * 60) {
      return AmbientLightingProfile.dawnMorning;
    }
    if (totalMinutesInDay >= 8 * 60 && totalMinutesInDay < 15 * 60) {
      return AmbientLightingProfile.day;
    }
    if (totalMinutesInDay >= 15 * 60 && totalMinutesInDay < 19 * 60) {
      return AmbientLightingProfile.evening;
    }
    return AmbientLightingProfile.night;
  }
}
