import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' show RadialGradient, Alignment, Colors;
import '../../../main.dart';

// HPが低い時のエフェクトコンポーネント
class HpLowEffect extends Component with HasGameReference<MyGame> {
  // `OpacityEffect` によって制御される透明度のための内部変数
  double _currentOpacity = 1.0;
  double _opacityDirection = -1.0; // 1.0 は増加、-1.0 は減少（最初は不透明度が減少するように）
  static const double _minOpacity = 0.5; // 最小不透明度
  static const double _maxOpacity = 1.0; // 最大不透明度
  static const double _cycleDuration = 2.0; // 1サイクルの時間 (秒)
  static const double _opacitySpeed =
      (_maxOpacity - _minOpacity) / (_cycleDuration / 2.0); // 透明度変化の速度

  HpLowEffect() : super(priority: 1051);

  @override
  Future<void> onLoad() async {
    // OpacityEffect は手動で透明度を制御するため不要
  }

  @override
  void render(Canvas canvas) {
    // HpLowEffect の現在の透明度 (`_currentOpacity`) を利用して、色をブレンドする
    final baseColor = const Color.fromARGB(192, 107, 9, 9); // 元の赤い色
    final blendedColor = baseColor.withOpacity(
      baseColor.opacity * _currentOpacity,
    );

    // HPが低い時に画面全体を黒くし、中央を透明にするグラデーション
    final paint =
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 1.0, // 画面全体を覆うように調整
            colors: [
              Colors.transparent, // 中央は完全に透明
              blendedColor, // 外側に向かって点滅する赤みがかった色
            ],
            stops: const [0.0, 1.0], // 透明から不透明への変化の割合
          ).createShader(game.size.toRect());
    canvas.drawRect(game.size.toRect(), paint);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 透明度を周期的に変更して点滅効果をシミュレート
    _currentOpacity += _opacityDirection * _opacitySpeed * dt;
    if (_currentOpacity > _maxOpacity) {
      _currentOpacity = _maxOpacity;
      _opacityDirection = -1.0; // 減少に転じる
    } else if (_currentOpacity < _minOpacity) {
      _currentOpacity = _minOpacity;
      _opacityDirection = 1.0; // 増加に転じる
    }

    // HPがエフェクト閾値を超えた場合にのみ削除
    if (game.player.currentHp > 350) {
      removeFromParent();
    }
  }
}
