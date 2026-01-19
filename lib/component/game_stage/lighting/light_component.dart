import 'package:flame/components.dart';
import 'package:flutter/material.dart';

// ライトの位置、サイズ等を設定するコンポーネント
// ライトのシェーダーは別ファイルで定義している
// LightingOverlayComponent が環境光とシェーダーを設定し、
// このコンポーネントはただ固定ライトの位置、サイズ、色を設定するだけ
// ライトのオブジェクトとして認識して問題ない。
class LightComponent extends RectangleComponent {
  final Color lightColor;
  final double lightRadius;
  final double lightIntensity;

  LightComponent({
    required Vector2 position,
    required Vector2 size,
    required this.lightColor,
    required this.lightRadius,
    this.lightIntensity = 1.0,
  }) : super(
         position: position,
         size: size,
         paint:
             Paint()
               ..color = Colors.transparent, // 初期ペイントを設定 (後でシェーダーを適用)
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
  }

  // デバッグ用にライトの範囲を可視化
  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // デバッグ用の描画ロジック
    // final paint = Paint()
    //   ..color = lightColor.withOpacity(0.2) // 半透明で表示
    //   ..style = PaintingStyle.fill;

    // // LightComponentの中心に円を描画
    // canvas.drawCircle(Offset(size.x * 0.5, size.y * 0.5), lightRadius, paint);

    // デバッグ用の枠線（LightComponent自体のサイズを示す）
    // final strokePaint = Paint()
    //   ..color = Colors.red.withOpacity(0.5)
    //   ..style = PaintingStyle.stroke
    //   ..strokeWidth = 1.0;
    // canvas.drawRect(size.toRect(), strokePaint);
  }
}
