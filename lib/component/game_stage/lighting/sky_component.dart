import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui; // dart:ui を 'ui' としてインポート
import '../../../game_manager/time_service.dart'; // TimeServiceとTimeOfDayTypeをインポート
import '../../../main.dart'; // MyGameをインポート
// import 'dart:ui' as ui; // dart:ui はこのファイルでは不要になりました

// SkyComponent が空の背景色を設定する
class SkyComponent extends RectangleComponent with HasGameReference<MyGame> {
  final TimeService timeService;

  // 新しいgetterを追加: 純粋な空の色
  Color get currentSkyColor => _currentSkyColor;
  Color _currentSkyColor = Colors.black; // 初期値

  // 新しいgetterを追加: 環境光の明るさ (0.0=bright, 1.0=dark)
  double get currentAmbientBrightness => _currentAmbientBrightness;
  double _currentAmbientBrightness = 0.0; // 初期値

  SkyComponent({required this.timeService})
    : super(
        position: Vector2(-MyGame.worldWidth * 2, 0),
        paint: Paint()..color = Colors.blue.withOpacity(0.0), // 初期は透明な水色
        priority: 1, // 最も奥に配置
      );

  Color get currentColor => paint.color; // 現在の空の色を返すgetter (変更)

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    position = Vector2(-MyGame.worldWidth * 2, game.initialGameCanvasSize.y);
    size = Vector2(MyGame.worldWidth * 4, game.initialGameCanvasSize.y * 2);
    anchor = Anchor.bottomLeft;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updateSkyBackgroundColor();
  }

  void _updateSkyBackgroundColor() {
    final currentHour = timeService.hour;
    final currentMinute = timeService.minute;
    final totalMinutesInDay = currentHour * 60 + currentMinute;

    Color newSkyColor; // 新しい空の色
    double newAmbientBrightness; // 新しい環境光の明るさ (0.0-1.0)

    // 各時間帯の色の定義 (これらは純粋な空の色)
    const Color midnightPureSkyColor = Color(0xFF05051F);
    const Color dawnPureSkyColor = Color.fromARGB(255, 255, 165, 0);
    const Color morningTransitionPureSkyColor = Color.fromARGB(
      255,
      255,
      192,
      203,
    );
    const Color dayPureSkyColor = Color.fromARGB(255, 132, 202, 255); // 明るい青空
    const Color duskTransitionPureSkyColor = Color.fromARGB(255, 255, 113, 191);
    const Color duskPureSkyColor = Color(0xFFFF7F50);
    const Color nightPureSkyColor = Color(0xFF191970);

    // 各時間帯の環境光の明るさ (0.0=bright, 1.0=dark)
    const double midnightDefaultBrightness = 0.7; // 真夜中は暗い (0.9 -> 0.7に調整)
    const double dawnDefaultBrightness = 0.7; // 夜明けはやや暗い
    const double morningDefaultBrightness = 0.2; // 朝は明るめ
    const double dayDefaultBrightness = 0.0; // 昼間は完全に明るい
    const double duskDefaultBrightness = 0.5; // 夕暮れはやや明るめ (0.7 -> 0.5に調整)
    const double nightDefaultBrightness = 0.7; // 夜は暗めだが、急激ではない (0.8 -> 0.7に調整)

    // 4:00 (日の出開始) から 5:00 (日の出初期の終わり)
    if (totalMinutesInDay >= 4 * 60 && totalMinutesInDay < 5 * 60) {
      double progress = (totalMinutesInDay - (4 * 60)) / (60.0); // 1時間
      newSkyColor =
          Color.lerp(
            midnightPureSkyColor,
            dawnPureSkyColor,
            progress.clamp(0.0, 1.0),
          )!;
      newAmbientBrightness =
          ui.lerpDouble(
            midnightDefaultBrightness,
            dawnDefaultBrightness,
            progress.clamp(0.0, 1.0),
          )!;
    }
    // 5:00 (日の出中期開始) から 6:00 (日の出中期〜終わりの移行)
    else if (totalMinutesInDay >= 5 * 60 && totalMinutesInDay < 6 * 60) {
      double progress = (totalMinutesInDay - (5 * 60)) / (60.0); // 1時間
      newSkyColor =
          Color.lerp(
            dawnPureSkyColor,
            morningTransitionPureSkyColor,
            progress.clamp(0.0, 1.0),
          )!;
      newAmbientBrightness =
          ui.lerpDouble(
            dawnDefaultBrightness,
            morningDefaultBrightness,
            progress.clamp(0.0, 1.0),
          )!;
    }
    // 6:00 (朝の始まり) から 9:00 (朝の終わり)
    else if (totalMinutesInDay >= 6 * 60 && totalMinutesInDay < 9 * 60) {
      double progress = (totalMinutesInDay - (6 * 60)) / (180.0); // 3時間
      newSkyColor =
          Color.lerp(
            morningTransitionPureSkyColor,
            dayPureSkyColor,
            progress.clamp(0.0, 1.0),
          )!;
      newAmbientBrightness =
          ui.lerpDouble(
            morningDefaultBrightness,
            dayDefaultBrightness,
            progress.clamp(0.0, 1.0),
          )!;
    }
    // 9:00 (昼開始) から 15:00 (昼終了、日の入り開始)
    else if (totalMinutesInDay >= 9 * 60 && totalMinutesInDay < 15 * 60) {
      newSkyColor = dayPureSkyColor;
      newAmbientBrightness = dayDefaultBrightness;
    }
    // 15:00 (日の入り開始) から 17:00 (夕焼け初期の終わり)
    else if (totalMinutesInDay >= 15 * 60 && totalMinutesInDay < 17 * 60) {
      double progress = (totalMinutesInDay - (15 * 60)) / (120.0); // 2時間
      newSkyColor =
          Color.lerp(
            dayPureSkyColor,
            duskTransitionPureSkyColor,
            progress.clamp(0.0, 1.0),
          )!;
      newAmbientBrightness =
          ui.lerpDouble(
            dayDefaultBrightness,
            duskDefaultBrightness,
            progress.clamp(0.0, 1.0),
          )!;
    }
    // 17:00 (夕焼け中期開始) から 18:00 (夕焼け終期〜夜の移行)
    else if (totalMinutesInDay >= 17 * 60 && totalMinutesInDay < 18 * 60) {
      double progress = (totalMinutesInDay - (17 * 60)) / (60.0); // 1時間
      newSkyColor =
          Color.lerp(
            duskTransitionPureSkyColor,
            duskPureSkyColor,
            progress.clamp(0.0, 1.0),
          )!;
      newAmbientBrightness =
          ui.lerpDouble(
            duskDefaultBrightness,
            nightDefaultBrightness,
            progress.clamp(0.0, 1.0),
          )!;
    }
    // 18:00 (夜開始) から 23:00 (夜終了、夜中開始)
    else if (totalMinutesInDay >= 18 * 60 && totalMinutesInDay < 23 * 60) {
      double progress = (totalMinutesInDay - (18 * 60)) / (300.0); // 5時間
      newSkyColor =
          Color.lerp(
            duskPureSkyColor,
            nightPureSkyColor,
            progress.clamp(0.0, 1.0),
          )!;
      newAmbientBrightness =
          ui.lerpDouble(
            nightDefaultBrightness,
            midnightDefaultBrightness,
            progress.clamp(0.0, 1.0),
          )!;
    }
    // 23:00 (夜中開始) から 4:00 (夜中終了、日の出開始) - 深夜をまたぐ場合
    else {
      // totalMinutesInDay >= 23 * 60 || totalMinutesInDay < 4 * 60
      if (currentHour >= 23) {
        // 23:00 - 23:59 (夜から夜中へ)
        double progress = (totalMinutesInDay - (23 * 60)) / (60.0); // 1時間
        newSkyColor =
            Color.lerp(
              nightPureSkyColor,
              midnightPureSkyColor,
              progress.clamp(0.0, 1.0),
            )!;
        newAmbientBrightness =
            ui.lerpDouble(
              nightDefaultBrightness,
              midnightDefaultBrightness,
              progress.clamp(0.0, 1.0),
            )!;
      } else {
        // 0:00 - 3:59 (夜中)
        newSkyColor = midnightPureSkyColor;
        newAmbientBrightness = midnightDefaultBrightness;
      }
    }

    _currentSkyColor = newSkyColor;
    _currentAmbientBrightness = newAmbientBrightness;
    // paint.color の更新は、SkyComponentが純粋な背景色になるため引き続き必要
    if (paint.color != newSkyColor) {
      paint.color = newSkyColor; // SkyComponentの背景色として設定
    }
  }
}
