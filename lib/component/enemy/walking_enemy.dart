import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../main.dart';
import '../../system/stage_combat_profile.dart';
import '../player.dart';
import '../common/physics/physics_body_queries.dart';
import '../game_stage/building/station.dart';
import 'enemy_base.dart';

class WalkingEnemy extends EnemyBase {
  /// walkingEnemy.png: 52×52 / 4列×6行 (208×312)
  static const double _frameSize = 52.0;
  static const int _walkFrameCount = 2;
  /// 歩行は1・2列目（0-indexed: col 0–1）、キャラは1–5行目（0-indexed: row 0–4）
  static const int _characterRowCount = 5;

  /// 警戒狩人（AlertHunter）用スプライト行（0-indexed 3 = 4行目）。
  static const int alertHunterSpriteRowIndex = 3;

  final int? _fixedSpriteRowIndex;
  final bool _offScreenDespawn;
  final bool _chasePlayer;

  double _walkCycleTime = 0.0;
  static const double _bounceHeight = 5.0;
  final double _walkCycleSpeed;
  bool _readyToPlaySound = true;
  double _footstepSoundCooldown = 0.0;
  static const double _footstepCooldownDuration = 0.2;

  static const double _telegraphRange = 118.0;
  double _telegraphTimer = 0.0;
  bool _telegraphPrimed = false;

  WalkingEnemy({
    required super.position,
    required super.direction,
    required super.mass,
    double walkCycleSpeed = 5.0,
    super.priority = 45,
    int? fixedSpriteRowIndex,
    bool offScreenDespawn = true,
    bool chasePlayer = false,
  })  : _walkCycleSpeed = walkCycleSpeed,
        _fixedSpriteRowIndex = fixedSpriteRowIndex,
        _offScreenDespawn = offScreenDespawn,
        _chasePlayer = chasePlayer {
    anchor = Anchor.bottomCenter;
  }

  @override
  double get speed => 50.0 + random.nextDouble() * 50.0;

  static const double _baseAttackStress = 5.0;

  /// 接近テレグラフ演出（中ボスは無効化可能）。
  bool get useAttackTelegraph => true;

  @override
  double get attackStress =>
      _telegraphPrimed ? _baseAttackStress * 1.35 : _baseAttackStress;

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
    final rowIndex =
        _fixedSpriteRowIndex ?? random.nextInt(_characterRowCount);

    animation = createWalkAnimation(
      walkingEnemyImage,
      rowIndex: rowIndex,
      walkCycleSpeed: _walkCycleSpeed,
    );

    size = animation!.frames.first.sprite.srcSize.clone();
    stepOverBasisSpeed = 75;
    await super.onLoad();

    // walkingEnemy スプライトは右向き基準のため、EnemyBase と反転して移動方向に合わせる
    scale.x = direction == 1.0 ? 1.0 : -1.0;

    // バウンス・足音と位相を揃えるため、_walkCycleTime から手動でフレーム更新
    animationTicker?.paused = true;

    final hb = PhysicsBodyQueries.feetAlignedHitbox(
      size,
      widthRatio: 0.3,
      heightRatio: 0.5,
      centerXRatio: 0.5,
    );
    add(
      RectangleHitbox(
        size: hb.size,
        position: hb.position,
        collisionType: CollisionType.active,
        isSolid: false,
      ),
    );
  }

  @override
  int get stepOverHorizontalIntent => direction.sign.toInt();

  double _telegraphRequiredSeconds() {
    final profile = StageCombatProfile.forScene(
      game.gameRuntimeState.currentOutdoorSceneId,
    );
    final tier = game.gameRuntimeState.starAlertHudTier;
    return (profile.telegraphBaseSeconds * (1.0 - tier * 0.06))
        .clamp(0.22, 0.55);
  }

  void _updateTelegraph(double dt) {
    if (!useAttackTelegraph) {
      _telegraphTimer = 0.0;
      _telegraphPrimed = false;
      return;
    }
    final player = game.player;
    final dist = (player.absolutePosition - absolutePosition).length;
    if (dist > _telegraphRange || player.isHiding) {
      _telegraphTimer = 0.0;
      _telegraphPrimed = false;
      refreshCombatTierVisuals();
      return;
    }

    _telegraphTimer += dt;
    final required = _telegraphRequiredSeconds();
    final progress = (_telegraphTimer / required).clamp(0.0, 1.0);
    paint.colorFilter = ColorFilter.mode(
      Color.lerp(
        const Color(0xFFFF8888),
        const Color(0xFFFF2222),
        progress,
      )!
          .withValues(alpha: 0.35 + progress * 0.25),
      BlendMode.srcATop,
    );
    _telegraphPrimed = _telegraphTimer >= required;
  }

  @override
  void preparePhysicsVelocity(double dt) {
    if (_chasePlayer && !isPhysicsSteppingOver) {
      final player = game.player;
      direction = player.absoluteCenter.x >= absoluteCenter.x ? 1.0 : -1.0;
      scale.x = direction == 1.0 ? 1.0 : -1.0;
    }
    if (!isPhysicsSteppingOver) {
      final tier = game.gameRuntimeState.effectiveEnemyCombatTier;
      final alert = game.gameRuntimeState.starAlertLevel;
      final runScale = StageCombatProfile.enemyRunScaleForTier(tier, alert);
      final telegraphSlow = useAttackTelegraph &&
              _telegraphTimer > 0 &&
              !_telegraphPrimed
          ? 0.72
          : 1.0;
      velocity.x = speed * runScale * telegraphSlow * direction;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updateTelegraph(dt);
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

    if (_offScreenDespawn) {
      if (direction == -1.0) {
        if (position.x < -MyGame.worldWidth - size.x) {
          removeFromParent();
        }
      } else {
        if (position.x > game.camera.visibleWorldRect.right + size.x) {
          removeFromParent();
        }
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
