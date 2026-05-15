import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../../main.dart';
import '../../UI/window_manager.dart';
import '../player.dart';

import 'package:flutter/material.dart';
import '../item/item.dart';
import '../effect/residue_effect.dart' show ResidueType;
import '../effect/residue_pickup.dart';
import '../common/physics/entity_physics_mixin.dart';
import '../common/collision/collision_family.dart';

abstract class EnemyBase extends SpriteAnimationComponent
    with CollisionCallbacks, HasGameReference<MyGame>, EntityPhysicsMixin, HasCollisionFamily {
  @override
  CollisionFamily get collisionFamily => CollisionFamily.entity;

  final Random random = Random();
  late double direction; // 進行方向: 1.0 (右) or -1.0 (左)

  double get speed;
  double get attackStress;
  final double mass;

  // 体力システム
  double maxHealth = 30.0;
  late double currentHealth;

  // 体力バー（starAlertLevel >= 2 で表示）
  RectangleComponent? _healthBarBg;
  RectangleComponent? _healthBarFill;

  // 星の警戒度による見た目変化の最終適用値（毎フレーム更新を避けるためキャッシュ）
  double _lastAppliedAlertLevel = -1.0;

  EnemyBase({
    required super.position,
    Vector2? size,
    this.direction = -1.0, // デフォルトは左向き
    super.priority = 49,
    this.mass = 1.0, // デフォルトの質量
  }) : super(size: size ?? Vector2(1.0, 1.0)) {
    currentHealth = maxHealth;
  }

  /// ダメージを受ける
  void takeDamage(double damage, {Vector2? impulse}) {
    if (damage <= 0) return;

    currentHealth -= damage;
    debugPrint('Enemy took $damage damage. Remaining health: $currentHealth');

    if (impulse != null) {
      applyKnockback(impulse);
    }

    _showHitEffect();
    _updateHealthBar();

    if (currentHealth <= 0) {
      dieAndDropItem();
    }
  }

  /// 体力バーの幅を現在のHPに合わせて更新
  void _updateHealthBar() {
    if (_healthBarFill == null || _healthBarBg == null) return;
    final ratio = (currentHealth / maxHealth).clamp(0.0, 1.0);
    final maxWidth = (_healthBarBg!.size.x);
    _healthBarFill!.size = Vector2(maxWidth * ratio, _healthBarFill!.size.y);
    final g = ratio * 0.6;
    _healthBarFill!.paint.color =
        Color.fromARGB(255, 255, (g * 255).toInt(), 0);
  }

  /// starAlertLevel に応じた外見変化を適用
  void _applyAlertLevelVisuals() {
    final alertLevel = game.gameRuntimeState.starAlertLevel;
    if ((alertLevel - _lastAppliedAlertLevel).abs() < 0.1) return;
    _lastAppliedAlertLevel = alertLevel;

    Color tint;
    if (alertLevel >= 6.0) {
      tint = const Color(0xFF4a003a);
      maxHealth = 30.0;
    } else if (alertLevel >= 4.0) {
      final t = ((alertLevel - 4.0) / 2.0).clamp(0.0, 1.0);
      tint = Color.lerp(const Color(0xFF2a0040), const Color(0xFF4a003a), t)!;
      maxHealth = 20.0;
    } else if (alertLevel >= 2.0) {
      final t = ((alertLevel - 2.0) / 2.0).clamp(0.0, 1.0);
      tint = Color.lerp(Colors.grey.shade700, const Color(0xFF2a0040), t)!;
      maxHealth = 15.0;
    } else {
      tint = Colors.grey.shade700;
      maxHealth = 10.0;
    }

    paint.colorFilter =
        ColorFilter.mode(tint.withOpacity(0.4), BlendMode.srcATop);

    final showBar = alertLevel >= 2.0;
    _healthBarBg?.opacity = showBar ? 1.0 : 0.0;
    _healthBarFill?.opacity = showBar ? 1.0 : 0.0;
    if (showBar) _updateHealthBar();
  }

  /// ノックバックを適用する（velocity に直接加算）
  void applyKnockback(Vector2 impulse) {
    velocity.add(impulse / mass);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 物理（重力・着地・壁補正）を先に処理してから移動ロジックへ
    updatePhysics(dt);

    // velocity の水平減衰（ノックバックの摩擦）
    velocity.x *= max(0.0, 1.0 - 5.0 * dt);
    if (velocity.x.abs() < 2.0) velocity.x = 0.0;

    _applyAlertLevelVisuals();

    // Stage 2 でプレイヤーが近くにいる場合にマーカーを表示
    /* if (game.gameRuntimeState.currentOutdoorSceneId == 'outdoor_2') {
      final player = game.player;
      if (!player.isHiding) {
        final distance = (player.absolutePosition - absolutePosition).length;
        showTargetMarker(distance < 150);
      } else {
        showTargetMarker(false);
      }
    } else {
      showTargetMarker(false);
    } */
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    scale.x = direction == 1.0 ? -1.0 : 1.0;

    // フルサイズの物理ヒットボックス（重力・着地検知専用、isSolid=false でプレイヤー等をブロックしない）
    // ローカル座標系の原点はスプライト左上なので position = Vector2.zero() で全体を覆う
    add(
      RectangleHitbox(
        size: size,
        collisionType: CollisionType.active,
        isSolid: false,
      ),
    );

    // 体力バー（初期は非表示）
    final barWidth = size.x * 0.8;
    const barHeight = 4.0;
    final barX = size.x * 0.1;
    const barY = -10.0;

    _healthBarBg = RectangleComponent(
      position: Vector2(barX, barY),
      size: Vector2(barWidth, barHeight),
      paint: Paint()..color = Colors.black.withOpacity(0.6),
    );
    _healthBarFill = RectangleComponent(
      position: Vector2(barX, barY),
      size: Vector2(barWidth, barHeight),
      paint: Paint()..color = Colors.redAccent,
    );

    add(_healthBarBg!);
    add(_healthBarFill!);
    _healthBarBg!.opacity = 0;
    _healthBarFill!.opacity = 0;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    // EntityPhysicsMixin → CollisionCallbacks の順でスーパーコールが連鎖する
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      // 衝突処理は Player クラスで行う
    } else if (other is Item) {
      final item = other;
      if (item.physicsBehavior.isEnabled &&
          item.physicsBehavior.velocity.length > 10) {
        final itemVelocity = item.physicsBehavior.velocity;
        final itemSpeed = itemVelocity.length;
        final damage = (item.mass * itemSpeed * 0.05) + item.attackPower;
        final impulse =
            itemVelocity.clone()..multiply(Vector2.all(item.mass * 0.5));
        takeDamage(damage, impulse: impulse);
      }
    }
  }

  void hitByMelee(double damage, Vector2 impulse) {
    takeDamage(damage, impulse: impulse);
  }

  void dieAndDropItem() {
    _showHitEffect();

    final itemNames = ['通貨', 'クオーツ', 'エメラルド'];
    final dropItemName = itemNames[random.nextInt(itemNames.length)];

    final dropItem = ItemFactory.createItemByName(
      dropItemName,
      absolutePosition.clone() - Vector2(0, size.y / 2),
    );
    if (dropItem != null) {
      game.world.add(dropItem);
      dropItem.physicsBehavior.setEnabled(true);
      dropItem.physicsBehavior.velocity = Vector2(0, -100);
    }

    final deathPos = ResiduePickup.worldEmitOrigin(this);

    game.gameRuntimeState.registerLifetimeEnemyKill();

    removeFromParent();

    game.gameRuntimeState.destructionPointsInStage += 1;

    ResiduePickup.spawnBurst(game, deathPos, ResidueType.life,
        count: 2, valueEach: 1);
    ResiduePickup.spawnBurst(game, deathPos, ResidueType.inorganic,
        count: 1, valueEach: 1);

    if (random.nextDouble() < 0.15) {
      ResiduePickup.spawnBurst(game, deathPos, ResidueType.history,
          count: 1, valueEach: 1);

      if (game.gameRuntimeState.unlockedDiaryEntries.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!game.windowManager.isShowing(GameWindowType.message)) {
            game.windowManager.showDialog(['…何かが零れた。']);
          }
        });
      }
    }
  }

  void _showHitEffect() {
    debugPrint('Showing hit effect on enemy');
    final originalColor = paint.color;
    paint.colorFilter =
        const ColorFilter.mode(Colors.red, BlendMode.srcATop);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (isMounted) {
        paint.colorFilter = null;
        paint.color = originalColor;
      }
    });
  }
}
