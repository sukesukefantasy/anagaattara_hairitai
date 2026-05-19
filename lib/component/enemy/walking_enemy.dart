import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../main.dart';
import '../player.dart';
import '../game_stage/building/station.dart';
import 'enemy_base.dart';

class WalkingEnemy extends EnemyBase {
  /// walkingEnemy.png: 52×52 / 4列×6行 (208×312)
  static const double _frameSize = 52.0;
  static const int _walkFrameCount = 2;
  /// 歩行は1・2列目（0-indexed: col 0–1）、キャラは1–5行目（0-indexed: row 0–4）
  static const int _characterRowCount = 5;

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

  /// sin(_walkCycleTime) の半周期（1歩）に相当するフレーム表示時間
  static double walkStepTimeForCycleSpeed(double walkCycleSpeed) =>
      pi / walkCycleSpeed;

  static SpriteAnimation createWalkAnimation(
    Image walkingEnemyImage, {
    required int rowIndex,
    required double walkCycleSpeed,
  }) {
    assert(rowIndex >= 0 && rowIndex < _characterRowCount);
    return SpriteAnimation.fromFrameData(
      walkingEnemyImage,
      SpriteAnimationData.sequenced(
        amount: _walkFrameCount,
        stepTime: walkStepTimeForCycleSpeed(walkCycleSpeed),
        textureSize: Vector2.all(_frameSize),
        texturePosition: Vector2(0, rowIndex * _frameSize),
        loop: true,
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    final walkingEnemyImage = await game.images.load('walkingEnemy.png');
    final randomRow = random.nextInt(_characterRowCount);

    animation = createWalkAnimation(
      walkingEnemyImage,
      rowIndex: randomRow,
      walkCycleSpeed: _walkCycleSpeed,
    );

    size = animation!.frames.first.sprite.srcSize.clone();
    stepOverBasisSpeed = 75;
    await super.onLoad();

    // walkingEnemy スプライトは右向き基準のため、EnemyBase と反転して移動方向に合わせる
    scale.x = direction == 1.0 ? 1.0 : -1.0;

    // バウンス・足音と位相を揃えるため、_walkCycleTime から手動でフレーム更新
    animationTicker?.paused = true;

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
  void preparePhysicsVelocity(double dt) {
    if (!isPhysicsSteppingOver) {
      final runScale = 1.0 + game.gameRuntimeState.starAlertLevel * 0.12;
      velocity.x = speed * runScale * direction;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _performMovement(dt);
  }

  void _syncWalkAnimationToCycle() {
    final ticker = animationTicker;
    if (ticker == null) return;
    final frameIndex =
        (_walkCycleTime / pi).floor() % _walkFrameCount;
    if (ticker.currentIndex != frameIndex) {
      ticker.currentIndex = frameIndex;
    }
  }

  void _performMovement(double dt) {
    _walkCycleTime += dt * _walkCycleSpeed;
    _syncWalkAnimationToCycle();

    if (!isOnGround && !isPhysicsSteppingOver && velocity.y.abs() > 45.0) {
      final oldCycleY =
          sin(_walkCycleTime - dt * _walkCycleSpeed) * _bounceHeight;
      final newCycleY = sin(_walkCycleTime) * _bounceHeight;
      position.y -= (newCycleY - oldCycleY);
    }

    if (direction == -1.0) {
      if (position.x < -MyGame.worldWidth - size.x) {
        removeFromParent();
      }
    } else {
      if (position.x > game.camera.visibleWorldRect.right + size.x) {
        removeFromParent();
      }
    }

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
      if (other.platformHitbox.isSolid) {
        final stationPlatformTopY = other.position.y + (53 * 2);
        if (position.y > stationPlatformTopY) {
          position.y = stationPlatformTopY;
        }
      }
    }
  }
}
