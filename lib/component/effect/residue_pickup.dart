import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import '../common/collision/collision_family.dart';
import '../common/physics/physics_step_obstacle.dart';
import '../player.dart';
import 'residue_effect.dart';

/// 触れてカーゴへ回収する残滓微粒子（粉状ドット）。
/// 弱い重力のみ受け、地形（[CollisionFamily.terrain]）で足場に載る。
/// 星はカーゴ**本体**を緩やかに引きつけるが、地上に残したときの可視・回収性のため加速度は
/// 重力（1/6）を大きく超えないようクリップする。物質が勢いよく散る見た目は
/// [ResidueEffect.spawnShimmerGlint] のみ（光学まがいの演出）で表現する。
///
/// **警戒度 `starAlertLevel`（§4）**  
/// 通常、スポーン時に種別・量に応じて [GameRuntimeState.addStarAlertLevel] が **上乗せ**され、
/// 寿命で [_absorbByStar] されたとき **同じ量だけ減算**される。プレイヤーがカーゴ回収した場合は
/// 減算が起きないため、出現時の上乗せ分が残り「奪還」として効く（回収時に再度足さない）。
/// 生命残滓の係数が最大で、歴史・無機は緩やか。
///
/// [addStarAlertWhenSpawned] / [subtractStarAlertWhenAbsorbed]（[spawnSingle]）で片側だけの会計にできる（拡張:
/// カーゴからの解き放ち等）。既定は両方 `true` で対称。吸収側は [subtractStarAlertWhenAbsorbed] をインスタンスが保持。
///
/// [collectibleByPlayer] が false のときは接触してもカーゴに入らず（§4 回収不能メモ）、短命で星へ吸われる。
class ResiduePickup extends PositionComponent
    with CollisionCallbacks, HasGameReference<MyGame>, HasCollisionFamily {
  @override
  CollisionFamily get collisionFamily => CollisionFamily.collectibleResidue;

  final ResidueType type;
  final int cargoValue;

  /// false のときプレイヤーは拾えず、演出上「掠め取られた」粒子として星側へ流れる。
  final bool collectibleByPlayer;

  /// 星吸収までの秒数（回収不能粒子は短めが効果的）。
  final double lifetimeSeconds;

  /// true のとき、[render] で寿命に応じて不透明度を落とす（被ダメ粒子など）。
  final bool fadeOpacityOverLifetime;

  /// 星吸収時にスポーン時と同量を [GameRuntimeState.addStarAlertLevel] から減算するか。
  final bool subtractStarAlertWhenAbsorbed;

  static const double _gravityScale = 1.0 / 6.0;

  Vector2 _velocity = Vector2.zero();
  double _age = 0;
  static const double _defaultMaxAge = 18.0;
  static const double snatchWindowSeconds = 0.4;
  static const double snatchValueBonus = 1.12;
  static final Random _rng = Random();

  bool _snatchApplied = false;

  /// 粉のオフセット（[onLoad] で決定）
  late List<Offset> _dustOffsets;

  ResiduePickup({
    required Vector2 position,
    required this.type,
    required this.cargoValue,
    this.collectibleByPlayer = true,
    this.lifetimeSeconds = _defaultMaxAge,
    this.fadeOpacityOverLifetime = false,
    this.subtractStarAlertWhenAbsorbed = true,
  }) : super(
          position: position,
          size: Vector2(14, 14),
          anchor: Anchor.center,
          priority: 58,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final rnd = _rng;
    _velocity = Vector2(
      rnd.nextDouble() * 70 - 35,
      rnd.nextDouble() * -50 - 15,
    );

    _dustOffsets = [
      Offset.zero,
      Offset(rnd.nextDouble() * 2.2 - 1.1, rnd.nextDouble() * 2.2 - 1.1),
      Offset(rnd.nextDouble() * 2.4 - 1.2, rnd.nextDouble() * 2.4 - 1.2),
    ];

    add(
      RectangleHitbox(
        size: Vector2(11, 11),
        anchor: Anchor.center,
        position: size / 2,
        collisionType: CollisionType.active,
      ),
    );
  }

  Color _colorForType(ResidueType t, double opacity) {
    switch (t) {
      case ResidueType.life:
        return Colors.redAccent.withValues(alpha: opacity);
      case ResidueType.history:
        return Colors.lightBlueAccent.withValues(alpha: opacity);
      case ResidueType.inorganic:
        return const Color(0xFF6a7a88).withValues(alpha: opacity);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final fade = fadeOpacityOverLifetime
        ? (1.0 - (_age / lifetimeSeconds)).clamp(0.0, 1.0)
        : 1.0;
    final base = _colorForType(type, 0.95 * fade);
    final soft = _colorForType(type, 0.55 * fade);
    final p = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _dustOffsets.length; i++) {
      final o = _dustOffsets[i];
      p.color = i == 0 ? base : soft;
      final s = i == 0 ? 4.0 : 3.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: o, width: s, height: s * 0.88),
          const Radius.circular(0.6),
        ),
        p,
      );
    }
    if (_age < snatchWindowSeconds) {
      final flash = Paint()
        ..color = Colors.white.withValues(alpha: 0.85 * fade.clamp(0.0, 1.0));
      canvas.drawCircle(Offset.zero, 3.2, flash);
    }
    if (type == ResidueType.inorganic) {
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color =
            Colors.blueGrey.shade200.withValues(alpha: 0.55 * fade.clamp(0.0, 1.0));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 4.8, height: 4.0),
          const Radius.circular(0.85),
        ),
        edge,
      );
    }
  }

  bool _isTerrainHierarchy(PositionComponent o) {
    PositionComponent walk = PhysicsStepQueries.solidRoot(o);
    final Object any = walk;
    if (any is HasCollisionFamily) {
      return any.collisionFamily == CollisionFamily.terrain;
    }
    for (final child in walk.children.whereType<ShapeHitbox>()) {
      if (collisionFamilyOf(child) == CollisionFamily.terrain) {
        return true;
      }
    }
    return false;
  }

  void _resolveTerrainContact(PositionComponent other) {
    if (!_isTerrainHierarchy(other)) return;

    final root = PhysicsStepQueries.solidRoot(other);
    final slab = PhysicsStepQueries.absoluteAabb(root);
    final mine = PhysicsStepQueries.absoluteAabb(this);

    final ox = PhysicsStepQueries.axisOverlap(
      mine.left,
      mine.right,
      slab.left,
      slab.right,
    );
    if (ox <= 0 || !mine.overlaps(slab)) return;

    final penFromTop = mine.bottom - slab.top;
    if (penFromTop >= -1.5 && penFromTop <= 48 && _velocity.y >= -80) {
      final fix = penFromTop.clamp(0.0, 48.0);
      if (fix > 0.2) {
        position.y -= fix;
        if (_velocity.y > 0) {
          _velocity.y = 0;
        }
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age > lifetimeSeconds) {
      _absorbByStar();
      return;
    }

    _velocity.y += Player.gravity * _gravityScale * dt;

    // 星への引力。仕様上は「吸い上げ」だが、素値だと通常プレイでも重力を上回り
    // 粒子が一貫して上へ流れ、地上に留まらず回収しづらい。地上ドロップ感を優先し上限をかける。
    final pullRaw = game.gameRuntimeState.starResiduePullAcceleration;
    final gResidue = Player.gravity * _gravityScale;
    final pull = min(pullRaw, gResidue * 0.88);
    _velocity.y -= pull * dt;

    position += _velocity * dt;
  }

  /// 単一粒子が `starAlertLevel` に寄与する絶対値（スポーン＋と吸収−で共通）。
  static double _starAlertMagnitude(ResidueType type, int cargoValue) {
    final w = cargoValue.clamp(1, 99).toDouble();
    switch (type) {
      case ResidueType.life:
        return 0.035 * w;
      case ResidueType.history:
        return 0.012 * w;
      case ResidueType.inorganic:
        return 0.016 * w;
    }
  }

  void _absorbByStar() {
    if (!isMounted) return;
    final s = game.gameRuntimeState;
    if (subtractStarAlertWhenAbsorbed) {
      s.addStarAlertLevel(-_starAlertMagnitude(type, cargoValue));
    }
    removeFromParent();
  }

  int _resolvedCargoValue() {
    if (_snatchApplied || _age > snatchWindowSeconds) return cargoValue;
    _snatchApplied = true;
    return (cargoValue * snatchValueBonus).ceil().clamp(1, 99);
  }

  void _collectByPlayer() {
    if (!isMounted) return;
    final s = game.gameRuntimeState;
    final origin = absolutePosition.clone();
    final value = _resolvedCargoValue();
    switch (type) {
      case ResidueType.life:
        s.accumulateCargo(life: value, pickupWorldPoint: origin);
        break;
      case ResidueType.history:
        s.accumulateCargo(history: value, pickupWorldPoint: origin);
        break;
      case ResidueType.inorganic:
        s.accumulateCargo(inorganic: value, pickupWorldPoint: origin);
        break;
    }
    removeFromParent();
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player && collectibleByPlayer) {
      _collectByPlayer();
    }
  }

  @override
  void onCollision(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollision(intersectionPoints, other);
    if (other is Player) return;
    _resolveTerrainContact(other);
  }

  /// 発生源の AABB 中央付近のワールド座標。
  ///
  /// `Anchor.bottomCenter` の NPC・オブジェクトでは [absolutePosition] が足元になるため、
  /// そのままだと残滓が地形にめり込みやすい。ドロップアイテムと同様に「本体の真ん中」から出す。
  static Vector2 worldEmitOrigin(PositionComponent source) {
    final a = source.anchor;
    return source.absolutePosition.clone() +
        Vector2(
          source.size.x * (0.5 - a.x),
          source.size.y * (0.5 - a.y),
        );
  }

  /// カーゴ整数を分割して微粒子化（合計カーゴ量は従来と同じ）。
  static void emitCargo(
    MyGame game,
    Vector2 origin, {
    int life = 0,
    int history = 0,
    int inorganic = 0,
  }) {
    void emitUnits(ResidueType t, int units) {
      if (units <= 0) return;
      const maxP = 8;
      final n = min(units, maxP);
      var left = units;
      for (var k = 0; k < n; k++) {
        final partsLeft = n - k;
        final chunk = (left / partsLeft).ceil().clamp(1, left);
        final take = chunk > left ? left : chunk;
        left -= take;
        spawnSingle(game, origin, t, take);
        if (left <= 0) break;
      }
    }

    emitUnits(ResidueType.life, life);
    emitUnits(ResidueType.history, history);
    emitUnits(ResidueType.inorganic, inorganic);
  }

  static void spawnSingle(
    MyGame game,
    Vector2 origin,
    ResidueType type,
    int cargoValue, {
    bool collectibleByPlayer = true,
    double lifetimeSeconds = _defaultMaxAge,
    bool fadeOpacityOverLifetime = false,
    bool addStarAlertWhenSpawned = true,
    bool subtractStarAlertWhenAbsorbed = true,
  }) {
    final rnd = _rng;
    final offset = Vector2(
      rnd.nextDouble() * 22 - 11,
      rnd.nextDouble() * 16 - 8,
    );
    final pos = origin + offset;
    if (addStarAlertWhenSpawned) {
      game.gameRuntimeState
          .addStarAlertLevel(_starAlertMagnitude(type, cargoValue));
    }
    game.world.add(
      ResiduePickup(
        position: pos,
        type: type,
        cargoValue: cargoValue,
        collectibleByPlayer: collectibleByPlayer,
        lifetimeSeconds: lifetimeSeconds,
        fadeOpacityOverLifetime: fadeOpacityOverLifetime,
        subtractStarAlertWhenAbsorbed: subtractStarAlertWhenAbsorbed,
      ),
    );
    ResidueEffect.spawnShimmerGlint(game, pos, type);
  }

  /// [origin] 付近に [count] 個、[valueEach] ずつの微粒子をばらまく。
  static void spawnBurst(
    MyGame game,
    Vector2 origin,
    ResidueType type, {
    required int count,
    required int valueEach,
  }) {
    for (var i = 0; i < count; i++) {
      spawnSingle(game, origin, type, valueEach);
    }
  }

  /// 被ダメ・敵接触などで「掠め取られた」粒子をばらまく（プレイヤー回収不可・短命）。
  static void spawnCaptureResistantBurst(
    MyGame game,
    Vector2 origin, {
    double intensity = 1.0,
  }) {
    final rnd = _rng;
    const types = [
      ResidueType.life,
      ResidueType.history,
      ResidueType.inorganic,
    ];
    final count = (2 + intensity * 5).round().clamp(2, 12);
    for (var i = 0; i < count; i++) {
      final t = types[rnd.nextInt(types.length)];
      spawnSingle(
        game,
        origin,
        t,
        1,
        collectibleByPlayer: false,
        lifetimeSeconds: 1.2,
        fadeOpacityOverLifetime: true,
      );
    }
  }
}
