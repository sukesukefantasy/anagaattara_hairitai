import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import '../../main.dart';

/// starAlertLevel >= 6 で発動する環境侵食エフェクト。
/// ステージ背景や地形の各所から暗い粒子が周期的に滲み出し、
/// 「世界そのものが変質している」ことをプレイヤーに示す。
class ErosionEffect extends Component with HasGameReference<MyGame> {
  final Random _random = Random();

  /// 侵食パーティクルを放出する間隔（秒）
  static const double _spawnInterval = 1.5;
  double _timer = 0.0;


  @override
  void update(double dt) {
    super.update(dt);

    final alertLevel = game.gameRuntimeState.starAlertLevel;

    // 警戒度 6 未満なら何もしない
    if (alertLevel < 6.0) {
    return;
  }

  _timer += dt;

    // 警戒度が高いほど頻繁に発生（6→0.5秒、10→0.15秒）
    final currentInterval = _spawnInterval / ((alertLevel - 5.0).clamp(1.0, 5.0));

    if (_timer >= currentInterval) {
      _timer = 0.0;
      _spawnErosionParticles(alertLevel);
    }

  }

  void _spawnErosionParticles(double alertLevel) {
    // カメラの視野付近に散らしてパーティクルを配置する
    final camera = game.camera;
    final viewportSize = camera.viewport.size;

    // ランダムな画面内の位置をワールド座標に変換
    final screenX = _random.nextDouble() * viewportSize.x;
    final screenY = _random.nextDouble() * viewportSize.y;
    final worldPos = camera.globalToLocal(Vector2(screenX, screenY));

    // 警戒度に応じてパーティクル数を変化
    final count = (3 + (alertLevel - 6.0) * 2).toInt().clamp(3, 15);

    // 侵食パーティクル（黒い破片 + 紫の帯電）
    final isHighAlert = alertLevel >= 8.0;
    final color = isHighAlert
        ? const Color(0xFF6a0050) // 高警戒：紫がかった暗い色
        : const Color(0xFF1a001a); // 通常侵食：深い黒紫

    final particle = Particle.generate(
      count: count,
      lifespan: 1.2,
      generator: (i) {
        final dir = Vector2(
          _random.nextDouble() * 2 - 1,
          _random.nextDouble() * 2 - 1,
        ).normalized();
        final spd = dir * (_random.nextDouble() * 40 + 20);

        return AcceleratedParticle(
          speed: spd,
          acceleration: Vector2(0, 60),
          child: CircleParticle(
            radius: _random.nextDouble() * 3 + 1,
            paint: Paint()..color = color.withOpacity(0.8),
          ),
        );
      },
    );

    game.world.add(
      ParticleSystemComponent(
        position: worldPos,
        particle: particle,
        priority: 80,
      ),
    );
  }
}
