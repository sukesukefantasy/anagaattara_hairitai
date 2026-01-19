import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kDebugModeをインポート

/// デバッグ目的でコンポーネントの描画を可視化するためのMixin。
/// PositionComponentを継承するクラスにこのMixinを適用することで、
/// コンポーネントの境界線、塗りつぶし、ヒットボックスを異なる色で表示できます。
/// enableDebugPaintがtrueの場合に描画されます。
/// kDebugModeがtrueの場合に、enableDebugPaintは自動的にtrueに設定されます。
///
/// 手順
///
/// 1. DebugPaintMixinをインポート
/* import '../../../deb/debug_paint.dart'; */
/// 2. コンポーネントを継承するクラスにDebugPaintMixinを適用する。
/// 3. renderメソッドをオーバーライドして、デバッグ描画を行う。(renderメソッドに以下を記述)
/* if (enableDebugPaint) {
    // DebugPaintMixinのrenderを呼び出す
    super.render(canvas);
    for (final child in children) {
      if (child is RectangleHitbox) {
        canvas.drawRect(child.toRect(), debugHitboxPaint);
      }
    }
  } */
/// ※詳しい操作はこのファイルのメソッドを使用してください。
///
///
mixin DebugPaintMixin on PositionComponent {
  /// コンポーネント自身の塗りつぶしに使用されるペイント。
  Paint debugColorPaint =
      Paint()
        ..color = Colors.red.withOpacity(0.5)
        ..style = PaintingStyle.fill;

  /// コンポーネント自身の輪郭線に使用されるペイント。
  Paint debugOutlinePaint =
      Paint()
        ..color = Colors.blue.withOpacity(0.8) // デフォルトの輪郭色
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0; // 線の太さ
  /// 子要素のRectangleHitboxの描画に使用されるペイント。
  Paint debugHitboxPaint =
      Paint()
        ..color = Colors.green.withOpacity(0.5)
        ..style = PaintingStyle.fill;

  /// デバッグ描画を有効にするかどうかを制御するフラグ。
  /// kDebugModeがtrueの場合、デフォルトでtrueになります。
  bool enableDebugPaint = kDebugMode; // kDebugModeで初期化

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (enableDebugPaint) {
      // 要素自身の塗りつぶし
      canvas.drawRect(size.toRect(), debugColorPaint);
      // 要素自身の輪郭
      canvas.drawRect(size.toRect(), debugOutlinePaint);
    }
  }

  /// コンポーネント自身の塗りつぶし色を設定します。
  void setDebugColor(Color color) {
    debugColorPaint.color = color;
  }

  /// コンポーネント自身の輪郭色を設定します。
  void setDebugOutlineColor(Color color) {
    debugOutlinePaint.color = color;
  }

  /// 子要素のヒットボックスの色を設定します。
  void setDebugHitboxColor(Color color) {
    debugHitboxPaint.color = color;
  }

  /// デバッグ描画の有効/無効を切り替えます。
  void toggleDebugPaint() {
    enableDebugPaint = !enableDebugPaint;
  }
}
