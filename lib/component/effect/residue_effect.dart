import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart'; // Add this line
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

enum ResidueType {
  life,      // 赤い粒子 (意志活動の余熱)
  history,   // 青い波紋 (記憶の残響)
  inorganic, // 黒い破片 (星の構造破片)
}

class ResidueEffect extends ParticleSystemComponent {
  final ResidueType type;

  ResidueEffect({
    required Vector2 position,
    required this.type,
    int count = 10,
    double lifespan = 1.0,
    double speed = 50.0,
  }) : super(
          position: position,
          particle: _createParticle(type, count, lifespan, speed),
        );

  static Particle _createParticle(ResidueType type, int count, double lifespan, double speed) {
    final random = Random();
    
    Color color;
    switch (type) {
      case ResidueType.life:
        color = Colors.redAccent;
        break;
      case ResidueType.history:
        color = Colors.blueAccent;
        break;
      case ResidueType.inorganic:
        color = Colors.black;
        break;
    }

    return Particle.generate(
      count: count,
      lifespan: lifespan,
      generator: (i) {
        final direction = Vector2(random.nextDouble() * 2 - 1, random.nextDouble() * 2 - 1).normalized();
        final initialSpeed = direction * (random.nextDouble() * speed + speed * 0.5);
        
        // 生命資源は身体から漏れ出すような動き
        // 歴史資源は波紋のように広がる動き
        // 無機資源は剥離して落ちるような動き
        Vector2 acceleration = Vector2.zero();
        if (type == ResidueType.inorganic) {
          acceleration = Vector2(0, 200); // 重力で落ちる
        }

        return AcceleratedParticle(
          speed: initialSpeed,
          acceleration: acceleration,
          child: ComputedParticle(
            lifespan: lifespan,
            renderer: (canvas, particle) {
              final paint = Paint()
                ..color = color.withOpacity((1.0 - particle.progress).clamp(0.0, 1.0))
                ..style = PaintingStyle.fill;
              
              if (type == ResidueType.history) {
                // 歴史資源は波紋（円環）
                paint.style = PaintingStyle.stroke;
                paint.strokeWidth = 1.0;
                canvas.drawCircle(Offset.zero, particle.progress * 30, paint);
              } else if (type == ResidueType.inorganic) {
                // 無機資源は破片（四角）
                canvas.drawRect(
                  Rect.fromCenter(center: Offset.zero, width: 4, height: 4),
                  paint,
                );
              } else {
                // 生命資源は粒子（円）
                canvas.drawCircle(Offset.zero, 2, paint);
              }
            },
          ),
        );
      },
    );
  }

  /// 指定された位置に生命資源（赤）のエフェクトを発生させる
  static void spawnLife(FlameGame game, Vector2 position, {int count = 8}) {
    game.world.add(ResidueEffect(
      position: position,
      type: ResidueType.life,
      count: count,
      lifespan: 0.8,
      speed: 40.0,
    ));
  }

  /// 指定された位置に歴史資源（青）のエフェクトを発生させる
  static void spawnHistory(FlameGame game, Vector2 position, {int count = 3}) {
    game.world.add(ResidueEffect(
      position: position,
      type: ResidueType.history,
      count: count,
      lifespan: 1.5,
      speed: 20.0,
    ));
  }

  /// 指定された位置に無機資源（黒）のエフェクトを発生させる
  static void spawnInorganic(FlameGame game, Vector2 position, {int count = 10}) {
    game.world.add(ResidueEffect(
      position: position,
      type: ResidueType.inorganic,
      count: count,
      lifespan: 0.6,
      speed: 60.0,
    ));
  }

  /// 残滓「物質」とは別レイヤーの、短い視覚ノイズ（余熱・大気の屈折に見えるきらめき）。
  /// 当たり判定・カーゴ換算なし。星がカーゴ本体を吸い上げる挙動とは切り離した演出。
  static void spawnShimmerGlint(FlameGame game, Vector2 position, ResidueType type) {
    final random = Random();
    Color base;
    switch (type) {
      case ResidueType.life:
        base = Colors.redAccent;
        break;
      case ResidueType.history:
        base = Colors.lightBlueAccent;
        break;
      case ResidueType.inorganic:
        base = const Color(0xFF9aacbc);
        break;
    }

    final child = Particle.generate(
      count: 8,
      lifespan: 0.48,
      generator: (i) {
        final vx = random.nextDouble() * 56 - 28;
        final vy = -random.nextDouble() * 95 - 35;
        return AcceleratedParticle(
          speed: Vector2(vx, vy),
          acceleration: Vector2(0, 220),
          child: ComputedParticle(
            lifespan: 0.48,
            renderer: (canvas, particle) {
              final fade = ((1.0 - particle.progress) * 0.5).clamp(0.0, 1.0);
              final paint = Paint()
                ..color = base.withValues(alpha: fade)
                ..style = PaintingStyle.fill;
              final r = 1.4 + (1.0 - particle.progress) * 1.2;
              canvas.drawCircle(Offset.zero, r, paint);
            },
          ),
        );
      },
    );

    game.world.add(
      ParticleSystemComponent(
        position: position,
        particle: child,
        priority: 57,
      ),
    );
  }
}

