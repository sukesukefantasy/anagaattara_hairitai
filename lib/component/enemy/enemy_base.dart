import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../../main.dart';
import '../../UI/window_manager.dart';
import '../../system/rogue_weapon_profile.dart';
import '../../system/stage_combat_profile.dart';
import '../player.dart';

import 'package:flutter/material.dart';
import '../item/item.dart';
import '../effect/residue_effect.dart' show ResidueType;
import '../effect/residue_pickup.dart';
import '../common/physics/entity_physics_mixin.dart';
import '../common/collision/collision_family.dart';
import '../game_stage/lighting/light_receiver.dart';
import '../game_stage/lighting/lighting_participation.dart';
import '../game_stage/lighting/lighting_participant.dart';

abstract class EnemyBase extends SpriteAnimationComponent
    with
        CollisionCallbacks,
        HasGameReference<MyGame>,
        EntityPhysicsMixin,
        ContactKnockbackSource,
        HasCollisionFamily,
        LightingParticipant,
        LightReceiver {
  @override
  CollisionFamily get collisionFamily => CollisionFamily.entity;

  @override
  LightingParticipation get lightingParticipation =>
      LightingParticipation.full;

  final Random random = Random();
  late double direction; // 進行方向: 1.0 (右) or -1.0 (左)

  double get speed;
  double get attackStress;
  final double mass;

  /// 戦闘ティア HP に掛ける倍率（中ボス等）。
  double get maxHealthMultiplier => 1.0;

  /// ティア0でも HP バーを常時表示する（中ボス等）。
  bool get alwaysShowHealthBar => false;

  // 体力システム
  double maxHealth = 30.0;
  late double currentHealth;

  // 体力バー（starAlertLevel >= 2 で表示）
  RectangleComponent? _healthBarBg;
  RectangleComponent? _healthBarFill;

  int _lastAppliedCombatTier = -1;

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

  Color _tintForCombatTier(int tier) {
    return switch (tier) {
      3 => const Color(0xFF4a003a),
      2 => const Color(0xFF2a0040),
      1 => Colors.grey.shade700,
      _ => Colors.grey.shade600,
    };
  }

  /// テレグラフ演出後など、ティア色を再適用する。
  void refreshCombatTierVisuals() {
    _lastAppliedCombatTier = -1;
    _applyCombatTierVisuals();
  }

  /// ステージ上限込みの戦闘ティアで外見・HP を適用。
  void _applyCombatTierVisuals() {
    final tier = game.gameRuntimeState.effectiveEnemyCombatTier;
    if (tier == _lastAppliedCombatTier) return;
    _lastAppliedCombatTier = tier;

    maxHealth =
        StageCombatProfile.maxHealthForTier(tier) * maxHealthMultiplier;
    if (currentHealth > maxHealth) {
      currentHealth = maxHealth;
    }

    final tint = _tintForCombatTier(tier);
    paint.colorFilter =
        ColorFilter.mode(tint.withValues(alpha: 0.4), BlendMode.srcATop);

    final showBar = alwaysShowHealthBar || tier >= 1;
    _healthBarBg?.opacity = showBar ? 1.0 : 0.0;
    _healthBarFill?.opacity = showBar ? 1.0 : 0.0;
    if (showBar) _updateHealthBar();
  }

  /// ノックバックを適用する（[EntityPhysicsMixin.knockbackVelocity] に加算）
  void applyKnockback(Vector2 impulse) {
    applyKnockbackImpulse(impulse, mass: mass);
  }

  @override
  double get contactMass => mass;

  @override
  Vector2 get contactVelocity => velocity.clone()..add(knockbackVelocity);

  @override
  double get contactFallbackDirectionX => -direction;

  @override
  void update(double dt) {
    super.update(dt);

    updatePhysics(dt);

    _applyCombatTierVisuals();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    scale.x = direction == 1.0 ? -1.0 : 1.0;

    // 物理ヒットボックスは WalkingEnemy / CarEnemy が個別に追加する

    // 体力バー（初期は非表示）
    final barWidth = size.x * 0.8;
    const barHeight = 4.0;
    final barX = size.x * 0.1;
    const barY = -10.0;

    _healthBarBg = RectangleComponent(
      position: Vector2(barX, barY),
      size: Vector2(barWidth, barHeight),
      paint: Paint()..color = Colors.black.withValues(alpha: 0.6),
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

    _applyCombatTierVisuals();
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
    final weapon = RogueWeaponProfile.forEquipped(
      game.player.itemBag.equippedItemName,
    );
    final particleMul = weapon.particleCargoValueMultiplier;
    final lifeCount = 2 + weapon.bonusParticlesOnKill;
    final inorganicCount = 1 + (weapon.bonusParticlesOnKill > 1 ? 1 : 0);

    game.gameRuntimeState.registerLifetimeEnemyKill();

    removeFromParent();

    game.gameRuntimeState.destructionPointsInStage += 1;

    for (var i = 0; i < lifeCount; i++) {
      ResiduePickup.spawnSingle(
        game,
        deathPos,
        ResidueType.life,
        (1 * particleMul).ceil().clamp(1, 99),
      );
    }
    for (var i = 0; i < inorganicCount; i++) {
      ResiduePickup.spawnSingle(
        game,
        deathPos,
        ResidueType.inorganic,
        (1 * particleMul).ceil().clamp(1, 99),
      );
    }

    if (random.nextDouble() < 0.15) {
      ResiduePickup.spawnSingle(
        game,
        deathPos,
        ResidueType.history,
        (1 * particleMul).ceil().clamp(1, 99),
      );

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

  @override
  void render(Canvas canvas) {
    renderWithComponentLighting(canvas, super.render);
  }
}
