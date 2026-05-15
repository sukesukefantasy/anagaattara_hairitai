import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../../main.dart';
import '../player.dart';
import 'enemy_base.dart';
import '../game_stage/building/station.dart';

class WalkingEnemy extends EnemyBase {
  double _walkCycleTime = 0.0;
  static const double _bounceHeight = 5.0;
  final double _walkCycleSpeed;
  bool _readyToPlaySound = true;
  double _footstepSoundCooldown = 0.0;
  static const double _footstepCooldownDuration = 0.2;

  WalkingEnemy({
    required super.position,
    required super.direction,
    double walkCycleSpeed = 5.0,
    super.priority = 45,
    super.mass = 1.0,
  }) : _walkCycleSpeed = walkCycleSpeed {
    anchor = Anchor.bottomCenter;
  }

  @override
  double get speed => 50.0 + random.nextDouble() * 50.0;

  @override
  double get attackStress => 5.0;

  @override
  Future<void> onLoad() async {
    // TODO: 画像挿入 (エネミー本体)
    final enemyImage = await game.images.load('enemy.png');

    final int randomRow = random.nextInt(8);
    final int randomCol = random.nextInt(8);

    animation = SpriteAnimation.fromFrameData(
      enemyImage,
      SpriteAnimationData.sequenced(
        amount: 1,
        stepTime: 0.5,
        textureSize: Vector2(12, 12),
        texturePosition:
            Vector2(1 + (randomCol * 12), 1 + (randomRow * 12)),
      ),
    );

    size = animation!.frames.first.sprite.srcSize.clone();
    stepOverBasisSpeed = 75;
    await super.onLoad();

    // ダメージ検知用の小さいボディヒットボックス（物理は EnemyBase のフルサイズ hitbox が担当）
    add(
      RectangleHitbox(
        size: Vector2(size.x * 0.3, size.y * 0.5),
        position: Vector2(size.x * 0.35, size.y * 0.25),
        collisionType: CollisionType.active,
        isSolid: false,
      ),
    );
  }

  @override
  int get stepOverHorizontalIntent => direction.sign.toInt();

  @override
  void update(double dt) {
    super.update(dt); // EnemyBase.update → updatePhysics(dt) が呼ばれる
    _performMovement(dt);
  }

  void _performMovement(double dt) {
    _walkCycleTime += dt * _walkCycleSpeed;

    if (!isPhysicsSteppingOver) {
      final runScale =
          1.0 + game.gameRuntimeState.starAlertLevel * 0.12;
      position.x += speed * runScale * dt * direction;
    }

    // 視覚的なバウンスは「ほぼ自由落下中」のときだけ（地表付近での誤検知による地すべり防止）
    if (!isOnGround &&
        !isPhysicsSteppingOver &&
        velocity.y.abs() > 45.0) {
      final oldCycleY =
          sin(_walkCycleTime - dt * _walkCycleSpeed) * _bounceHeight;
      final newCycleY = sin(_walkCycleTime) * _bounceHeight;
      position.y -= (newCycleY - oldCycleY);
    }

    // 移動範囲の制限
    if (direction == -1.0) {
      if (position.x < -MyGame.worldWidth - size.x) {
        removeFromParent();
      }
    } else {
      if (position.x > game.camera.visibleWorldRect.right + size.x) {
        removeFromParent();
      }
    }

    // 足音
    if (sin(_walkCycleTime) > 0.99 &&
        _readyToPlaySound &&
        _footstepSoundCooldown <= 0) {
      game.audioManager.playFootstepSound(absolutePosition);
      _readyToPlaySound = false;
      _footstepSoundCooldown = _footstepCooldownDuration;
    }
    if (sin(_walkCycleTime) < 0.5) {
      _readyToPlaySound = true;
    }
    if (_footstepSoundCooldown > 0) {
      _footstepSoundCooldown -= dt;
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      // 衝突処理は Player クラスで行う
    } else if (other is Station) {
      // Station プラットフォームへのスナップ（物理補正の補助）
      if (other.platformHitbox.isSolid) {
        final stationPlatformTopY = other.position.y + (53 * 2);
        if (position.y > stationPlatformTopY) {
          position.y = stationPlatformTopY;
        }
      }
    }
  }
}
