import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../../main.dart';
import '../common/hitboxes/interact_hitbox.dart';
import '../common/physics/entity_physics_mixin.dart';
import '../common/physics/knockback_config.dart';
import '../common/physics/physics_body_queries.dart';
import '../common/collision/collision_family.dart';
import '../item/item.dart';
import '../effect/residue_pickup.dart';
import '../game_stage/lighting/light_receiver.dart';
import '../game_stage/lighting/lighting_participation.dart';
import '../game_stage/lighting/lighting_participant.dart';

class Npc extends SpriteComponent
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

  /// 物理ヒットボックスより広げるインタラクト領域（各辺へのパディング、px）。
  static const double defaultInteractPaddingW = 12;
  static const double defaultInteractPaddingH = 8;

  final String name;
  final List<String> talkMessages;
  final String giftResponse;
  final String uniqueId; // 永続化用のID
  final void Function()? onTalkOverride; // 会話ロジックのオーバーライド
  bool isSatisfied = false;

  // スプライト指定用のパラメータd
  final String spritePath;
  final Vector2? srcPosition;
  final Vector2? srcSize;

  late final SpriteComponent _speechBubble;
  bool _hasMission = true; // とりあえず全てのNPCがミッションを持っていると仮定

  /// 接触ノックバック用の質量（デフォルトはプレイヤーと同程度）。
  final double mass;

  Npc({
    required this.name,
    required this.talkMessages,
    required this.giftResponse,
    required this.uniqueId,
    required super.position,
    this.onTalkOverride,
    this.spritePath = 'CITY_MEGA.png',
    this.srcPosition,
    this.srcSize,
    this.mass = KnockbackConfig.playerMass,
  }) : super(size: Vector2(1.0, 1.0)) {
    anchor = Anchor.bottomCenter;
  }

  @override
  double get contactMass => mass;

  @override
  Vector2 get contactVelocity => velocity.clone()..add(knockbackVelocity);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 永続化データの適用
    if (game.gameRuntimeState.satisfiedNpcIds.contains(uniqueId)) {
      isSatisfied = true;
      _hasMission = false;
      game.gameRuntimeState.codexEnsureConnectionSeen(uniqueId, satisfied: true);
    }

    // TODO: 画像挿入 (NPC本体)
    // CITY_MEGA.png かつ 指定がない場合のみ、従来のデフォルト値を使用
    Vector2? effectivePos = srcPosition;
    Vector2? effectiveSize = srcSize;
    if (spritePath == 'CITY_MEGA.png' && srcPosition == null) {
      effectivePos = Vector2(102, 162);
      effectiveSize = Vector2(21, 30);
    }

    try {
      sprite = await Sprite.load(
        spritePath,
        srcPosition: effectivePos,
        srcSize: effectiveSize,
      );
      if (sprite != null) {
        size = sprite!.srcSize.clone();
      }
    } catch (e) {
      debugPrint('Error loading NPC sprite ($spritePath): $e');
      if (effectiveSize != null) {
        size = effectiveSize.clone();
      }
    }

    // デバッグ用の背景色（スプライトが見えない場合の対策）
    /* add(RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.orange.withOpacity(0.5),
      priority: -1,
    )); */

    // 吹き出しアイコン（簡易版としてSpriteで実装、必要に応じて画像を用意）
    // TODO: 画像挿入 (吹き出し)
    final speechSprite = await Sprite.load(
      'CITY_MEGA.png',
      srcPosition: Vector2(1381, 403),
      srcSize: Vector2(16, 16),
    );
    _speechBubble = SpriteComponent(
      sprite: speechSprite, // 白い吹き出し
      position: Vector2(0, -size.y + 12),
      size: speechSprite.srcSize.clone(),
      anchor: Anchor.bottomCenter,
      priority: 10, // 親（NPC）より前面に
    );
    add(_speechBubble);

    // インタラクト用のヒットボックス（本体より広めに取る）
    const pw = defaultInteractPaddingW;
    const ph = defaultInteractPaddingH;
    add(InteractHitbox(
      position: Vector2(-pw, -ph),
      size: Vector2(size.x + (pw * 2), size.y + (ph * 2)),
      onInteract: _onTalk,
      icon: Icons.chat,
    ));

    // 物理用ヒットボックス（重力・着地検知専用、isSolid=false でプレイヤーをブロックしない）
    final hb = PhysicsBodyQueries.feetAlignedHitbox(
      size,
      widthRatio: 0.45,
      heightRatio: 0.85,
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
  void update(double dt) {
    super.update(dt);

    // 重力・着地物理
    updatePhysics(dt);

    // 満足したNPCやミッションがない場合は吹き出しを消す
    _speechBubble.opacity = _hasMission ? 1.0 : 0.0;
    
    // 吹き出しをふわふわさせる (base: -size.y + 12)
    if (_hasMission) {
      _speechBubble.position.y = -size.y + 12 + sin(game.timeService.totalPlayTime * 3) * 2;
    }

    // 依存ルートの演出：行動予測補完（要求を先回りして表示）
    if (game.gameRuntimeState.isDependencyOverloadForUi && _hasMission && !isSatisfied) {
      final playerDist = (game.player.absolutePosition - absolutePosition).length;
      if (playerDist < 100) {
        if (children.whereType<TextComponent>().isEmpty) {
          final prediction = name == '住人' ? '要求：希少な鉱石' : '要求：対話';
          add(TextComponent(
            text: prediction,
            position: Vector2(0, -size.y - 20),
            anchor: Anchor.bottomCenter,
            textRenderer: TextPaint(
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 10,
                fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
              ),
            ),
          ));
        }
      } else {
        children.whereType<TextComponent>().forEach((c) => c.removeFromParent());
      }
    } else {
      children.whereType<TextComponent>().forEach((c) => c.removeFromParent());
    }
  }

  void _onTalk() {
    if (onTalkOverride != null) {
      onTalkOverride!();
      return;
    }
    final state = game.gameRuntimeState;
    
    // ステージ4の特殊処理
    if (state.currentOutdoorSceneId == 'outdoor_4') {
      if (isSatisfied) {
        game.windowManager.showDialog(["[$name]", "「希少な鉱石のおかげで助かったよ、ありがとう。」"]);
        return;
      }

      final hasStone = game.player.itemBag.getItemCount('希少な鉱石') > 0 || game.player.itemBag.getItemCount('石') > 0;
      
      if (hasStone) {
        game.windowManager.showDialog(
          ["[$name]", "「おや、君。もしかして『希少な鉱石』を持っていないかい？」", "「このあたりでは貴重な資源なんだ。1つ分けてくれないか？」"],
          options: ["あげる", "あげない"],
          onSelect: (index) {
            if (index == 0) {
              _onGiveStone();
            }
          }
        );
      } else {
        game.windowManager.showDialog(["[$name]", "「この世界は荒廃してしまった……。『希少な鉱石』一つ見つからないよ。」"]);
      }
      return;
    }

    // 通常の会話
    game.windowManager.showDialog(
      [
        "[$name]",
        ...talkMessages,
      ],
      onClosed: () async {
        // 汎用的な共感ルートの進行（以前の仕様）
        if (state.currentOutdoorSceneId == 'outdoor_4' && !isSatisfied) {
          // TODO: 共感トリガーの再設計
        }
      },
    );
  }

  void _onGiveStone() {
    final state = game.gameRuntimeState;
    if (game.player.itemBag.getItemCount('希少な鉱石') > 0) {
      game.player.itemBag.removeItem('希少な鉱石');
    } else {
      game.player.itemBag.removeItem('石');
    }
    isSatisfied = true;
    state.satisfiedNpcIds.add(uniqueId);
    state.codexEnsureConnectionSeen(uniqueId, satisfied: true);
    
    game.windowManager.showDialog(
      ["[$name]", "「おお、ありがとう！ これで少しはマシな生活ができそうだ。」"],
    );
  }

  void dieAndDropItem() {
    // 即死 + アイテムドロップ
    final dropItem = ItemFactory.createItemByName('希少な鉱石', absolutePosition.clone());
    if (dropItem != null) {
      game.world.add(dropItem);
      dropItem.physicsBehavior.setEnabled(true);
      dropItem.physicsBehavior.velocity = Vector2(0, -100);
    }
    
    // NPCを消去
    removeFromParent();
    
    // 破壊ポイントを加算
    game.gameRuntimeState.destructionPointsInStage += 1;

    game.gameRuntimeState.codexBlackedConnection(uniqueId);
    game.gameRuntimeState.noteMicroCategoryExplore(5);

    // 残滓微粒子のスポーン時に starAlertLevel が上乗せされる（NPC 専用の二重加算は避ける）。
    ResiduePickup.emitCargo(game, ResiduePickup.worldEmitOrigin(this), life: 6);
    ResiduePickup.emitCargo(game, ResiduePickup.worldEmitOrigin(this), history: 4);
    ResiduePickup.emitCargo(game, ResiduePickup.worldEmitOrigin(this), inorganic: 4);
  }

  @override
  void render(Canvas canvas) {
    renderWithComponentLighting(canvas, super.render);
  }
}
