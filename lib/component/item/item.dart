import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../common/collision/collision_family.dart';
import '../common/hitboxes/physics_hitbox.dart';
import '../common/physics/entity_physics_mixin.dart';
import '../common/physics/physics_behavior.dart';
import '../game_stage/lighting/lantern_strip_light_registry.dart';
import '../game_stage/lighting/light_receiver.dart';
import '../game_stage/lighting/lighting_participation.dart';
import '../game_stage/lighting/lighting_participant.dart';
import '../player.dart';
import 'item_sprite_sheet.dart';
import 'lantern_item.dart';
import 'item_effect_resolver/currency_item_effect_resolver.dart';
import 'item_effect_resolver/custom_item_effect_resolver.dart';
import 'item_effect_resolver/health_item_effect_resolver.dart';
import 'item_effect_resolver/placeable_item_effect_resolver.dart';
import 'item_effect_resolver/powerup_item_effect_resolver.dart';
import 'item_effect_resolver/stress_item_effect_resolver.dart';
import 'item_effect_resolver/tool_item_effect_resolver.dart';

enum ItemType {
  currency, // 通貨
  gem, // 宝石・換金アイテム
  health, // 回復アイテム
  stress, // ストレス軽減
  powerUp, // 永続パワーアップ
  tool, // 道具（投擲など）
  placeable, // 設置アイテム（家具など）
  custom, // 特殊効果
  collection, // コレクション（メインアイテム）
}

enum ResourceType {
  life, // 生命資源 (Life Data)
  history, // 歴史資源 (History Resources)
  inorganic, // 無機資源 (Inorganic Resources)
  none, // 資源ではない
}

enum BagWindowActionType {
  consume, // 消費
  carry, // 持ち運ぶ
  equip, // 装備
  unequip, // 解除
  dispose, // 廃棄
  view, // 眺める
  custom, // 特殊
  place, // 配置（確定時に消費）
  none, // なし
}

/// アイテムの基底クラス。
abstract class Item extends SpriteComponent
    with
        HasGameReference<MyGame>,
        CollisionCallbacks,
        EntityPhysicsMixin,
        ItemPhysicsMixin,
        HasCollisionFamily,
        LightingParticipant,
        LightReceiver
    implements HasPhysicsBehavior {
  final String name;
  final String description;
  final int value;
  final String spritePath;
  final ItemType type;
  final double attackPower; // 攻撃力（ツール等で使用）
  final double mass; // 質量（ダメージ計算や物理挙動で使用）
  final bool autoUse; // 取得時に自動使用するかどうか
  ResourceType resourceType;
  bool isCollected = false;

  @override
  CollisionFamily get collisionFamily => CollisionFamily.item;

  @override
  int get stepOverHorizontalIntent => 0;

  @override
  LightingParticipation get lightingParticipation =>
      LightingParticipation.full;

  @override
  late final PhysicsBehavior physicsBehavior;

  /// ワールド・運搬・UI 表示で共通の anchor。
  static const Anchor displayAnchor = Anchor.center;

  /// [Anchor.center] 用のコンポーネント位置（配置プレビュー矩形の中心）。
  static Vector2 positionForWorldRect(Rect rect) =>
      Vector2(rect.center.dx, rect.center.dy);

  /// 親ローカル座標で anchor が載る位置（子 SAC の position 用）。
  Vector2 displayAnchorLocalOffset([Anchor? value]) {
    final a = value ?? anchor;
    return Vector2(size.x * a.x, size.y * a.y);
  }

  Item({
    required this.name,
    required this.description,
    required this.value,
    required this.spritePath,
    required this.type,
    this.attackPower = 0.0,
    this.mass = 1.0,
    this.autoUse = false,
    this.resourceType = ResourceType.none,
    required super.position,
    required super.size,
    super.anchor = displayAnchor,
  }) {
    priority = 10;
    physicsBehavior = PhysicsBehavior(parent: this, mass: mass);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await ItemFactory.loadDisplaySprite(game, name, spritePath);

    final hitbox = PhysicsHitbox(parent: this, size: size);
    add(hitbox);
    physicsBehavior.setHitbox(hitbox);
  }

  /// 親とスプライトシート子の anchor を [displayAnchor]（または指定値）に揃える。
  void syncDisplayAnchor([Anchor? value]) {
    final resolved = value ?? displayAnchor;
    anchor = resolved;
    final localOffset = displayAnchorLocalOffset(resolved);
    for (final child in children.whereType<SpriteAnimationComponent>()) {
      child
        ..anchor = resolved
        ..position = localOffset;
    }
  }

  /// スプライトシート定義がある場合、ワールド表示用アニメーション子を付与する。
  Future<void> attachWorldAnimationIfNeeded() async {
    final meta = ItemFactory.spriteSheetMetaForName(name);
    if (meta == null) return;

    for (final child in children.whereType<SpriteAnimationComponent>().toList()) {
      child.removeFromParent();
    }

    paint.color = Colors.transparent;

    final image = sprite!.image;
    add(
      SpriteAnimationComponent(
        animation: meta.createAnimation(image),
        size: size,
        anchor: displayAnchor,
        position: displayAnchorLocalOffset(),
      )..paint.filterQuality = FilterQuality.none,
    );
    syncDisplayAnchor();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!physicsBehavior.isEnabled) return;

    updatePhysics(dt);

    if (physicsBehavior.hitbox?.hasSupportFromBelow == true) {
      final micro = PhysicsHitbox.itemMicroVelocityThreshold;
      if (velocity.length2 <= micro * micro) {
        velocity.setZero();
        isOnGround = true;
      } else if (velocity.y >= 0 && velocity.y.abs() < micro) {
        velocity.y = 0;
        isOnGround = true;
      }
    } else if (!isOnGround && physicsBehavior.hitbox?.isColliding != true) {
      if (velocity.x.abs() > 0) {
        velocity.x *= (1 - 0.1 * dt).clamp(0.0, 1.0);
        if (velocity.x.abs() < 0.1) velocity.x = 0;
      }
      if (velocity.y.abs() > 0) {
        velocity.y *= (1 - 0.1 * dt).clamp(0.0, 1.0);
        if (velocity.y.abs() < 0.1) velocity.y = 0;
      }
    }
  }

  /// 下の支持が外れたときに [PhysicsHitbox.onCollisionEnd] から呼ばれる。
  void refreshStackSupportState() {
    if (!physicsBehavior.isEnabled) return;
    if (physicsBehavior.hitbox?.hasSupportFromBelow == true) return;
    isOnGround = false;
  }

  /// UI等で表示する際の名称
  String get displayName => name;

  /// UI等で表示する際の説明
  String getDescription() {
    if (game.player.inUnderGround) return description;
    return description;
  }

  /// 使用時のデフォルト動作
  void onUse(Player player) {
    debugPrint('Using item: $name');
  }

  /// 押しっぱなし操作に対応する使用動作（ツール等）
  void Function(Player player, bool isPressed)? get onToggleUse => null;

  /// プレイヤーによる収集
  void collectItemByPlayer(Player player) {
    if (isCollected) return;
    isCollected = true;
    player.collectItem(this, worldPosition: absoluteCenter);
    removeFromParent();
  }

  bool get isMemoItem => name.contains('メモ') || name.contains('LOG');

  @override
  void render(Canvas canvas) {
    renderWithComponentLighting(canvas, super.render);
  }
}

/// 通貨アイテム
class CurrencyItem extends Item {
  final int currencyValue;
  CurrencyItem({
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
    required this.currencyValue,
    super.mass,
    super.autoUse = true,
  }) : super(type: ItemType.currency);

  @override
  void onUse(Player player) {
    CurrencyItemEffectResolver.apply(game, currencyValue);
  }
}

/// 宝石アイテム
class GemItem extends Item {
  GemItem({
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
    super.mass,
  }) : super(type: ItemType.gem);
}

/// 回復アイテム
class HealthItem extends Item {
  final double healAmount;
  HealthItem({
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
    required this.healAmount,
    super.mass,
  }) : super(type: ItemType.health);

  @override
  void onUse(Player player) {
    HealthItemEffectResolver.apply(game, healAmount);
  }
}

/// ストレス軽減アイテム
class StressItem extends Item {
  final double stressReduction;
  StressItem({
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
    required this.stressReduction,
    super.mass,
  }) : super(type: ItemType.stress);

  @override
  void onUse(Player player) {
    StressItemEffectResolver.apply(game, stressReduction);
  }
}

/// パワーアップアイテム
class PowerUpItem extends Item {
  final void Function(MyGame game)? powerUpEffect;
  PowerUpItem({
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
    this.powerUpEffect,
    super.mass,
  }) : super(type: ItemType.powerUp);

  @override
  void onUse(Player player) {
    powerUpEffect?.call(game);
  }
}

/// 道具アイテム
class ToolItem extends Item {
  final void Function(MyGame game)? toolEffect;
  ToolItem({
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
    this.toolEffect,
    super.attackPower,
    super.mass,
  }) : super(type: ItemType.tool);

  @override
  void onUse(Player player) {
    toolEffect?.call(player.game);
  }

  @override
  void Function(Player player, bool isPressed)? get onToggleUse {
    final itemData = ItemFactory._itemDefinitions[name];
    if (itemData == null) return null;
    final effectName = itemData['toolEffect'] as String?;
    return ToolEffectResolver.resolveToggle(effectName);
  }
}

/// 設置アイテム
class PlaceableItem extends Item {
  final void Function(MyGame game)? placeableEffect;

  /// true のとき [Player.inUnderGround] でないと配置モードを開始できない。
  final bool requiresUnderGround;

  PlaceableItem({
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
    this.placeableEffect,
    this.requiresUnderGround = false,
    super.mass,
  }) : super(type: ItemType.placeable);

  bool canBeginPlacement(MyGame game) =>
      !requiresUnderGround || game.player.inUnderGround;

  @override
  void onUse(Player player) {
    ItemFactory.tryStartPlaceablePlacement(player.game, this);
  }
}

/// カスタムアイテム
class CustomItem extends Item {
  final void Function(MyGame game) customEffect;
  final BagWindowActionType customActionType;

  CustomItem({
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
    required this.customEffect,
    this.customActionType = BagWindowActionType.consume,
    super.mass,
    super.autoUse = false,
  }) : super(type: ItemType.custom);

  @override
  void onUse(Player player) {
    customEffect(game);
  }
}

/// コレクションアイテム
class CollectionItem extends Item {
  CollectionItem({
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
    super.mass,
  }) : super(type: ItemType.collection);
}

/// アイテム生成用のファクトリークラス
class ItemFactory {
  static final Map<String, Map<String, dynamic>> _itemDefinitions = {
    '通貨': {
      'type': ItemType.currency,
      'description': 'お金を25増やします。使用すると財布に入ります。',
      'spritePath': 'money.png',
      'value': 25,
      'size': [25.0, 25.0],
      'mass': 0.1,
    },
    'クオーツ': {
      'type': ItemType.gem,
      'resourceType': ResourceType.inorganic,
      'description': 'カラフルな石です。',
      'spritePath': 'quartz.png',
      'value': 50,
      'size': [25.0, 25.0],
      'mass': 0.5,
    },
    'エメラルド': {
      'type': ItemType.gem,
      'resourceType': ResourceType.inorganic,
      'description': '緑色の石です。',
      'spritePath': 'emerald.png',
      'value': 50,
      'size': [25.0, 25.0],
      'mass': 0.5,
    },
    '栄養剤': {
      'type': ItemType.health,
      'description': 'Health を100回復します',
      'spritePath': 'health_potion.png',
      'value': 50,
      'healAmount': 100.0,
      'size': [25.0, 25.0],
      'mass': 0.3,
    },
    'お茶の力': {
      'type': ItemType.stress,
      'description': 'ストレスを20軽減し、最大ストレス値を増加します',
      'spritePath': 'green_cha.png',
      'value': 70,
      'stressReduction': 20.0,
      'size': [25.0, 25.0],
      'mass': 0.3,
    },
    'レッド・ブリ': {
      'type': ItemType.powerUp,
      'description': '使用するとキマリます。1時間の間、ストレスを無効にします',
      'spritePath': 'blue_red.png',
      'value': 460,
      'powerUpEffect': 'addMaxStress',
      'size': [25.0, 25.0],
      'mass': 0.3,
    },
    '棒': {
      'type': ItemType.tool,
      'description': 'この星を構成している何か',
      'spritePath': 'stick.png',
      'value': 1,
      'toolEffect': 'swing',
      'attackPower': 5.0,
      'mass': 0.8,
      'size': [25.0, 25.0],
    },
    '石': {
      'type': ItemType.tool,
      'resourceType': ResourceType.inorganic,
      'description': 'この星の地層から採取された、未知の組成を持つ鉱石。',
      'spritePath': 'stone.png',
      'value': 1,
      'toolEffect': 'throw',
      'attackPower': 2.0,
      'mass': 1.2,
      'size': [25.0, 25.0],
    },
    '採掘の気力': {
      'type': ItemType.custom,
      'description': '採掘ポイントを5増やします',
      'actionType': BagWindowActionType.consume,
      'spritePath': 'shovel.png',
      'value': 120,
      'customEffect': 'updateMiningPoints5',
      'size': [25.0, 25.0],
      'mass': 1.5,
      'autoUse': true,
    },
    '自動化キット': {
      'type': ItemType.placeable,
      'description': '（旧）自動整備ツールへ移行。設置すると整備装置になる。',
      'spritePath': 'valve.png',
      'value': 80,
      'placeableEffect': 'automationUpkeep',
      'size': [25.0, 25.0],
      'mass': 2.0,
    },
    '自動収穫ツール': {
      'type': ItemType.placeable,
      'description': '設置すると残滓やドロップを吸引して内蔵ストレージに貯める。',
      'spritePath': 'nozzle.png',
      'value': 80,
      'placeableEffect': 'automationHarvest',
      'size': [25.0, 25.0],
      'mass': 2.0,
    },
    '自動整備ツール': {
      'type': ItemType.placeable,
      'description': '設置すると燃料補給・自動サイクル・他装置の整備を行う。',
      'spritePath': 'valve.png',
      'value': 80,
      'placeableEffect': 'automationUpkeep',
      'size': [25.0, 25.0],
      'mass': 2.0,
    },
    '自動防衛ツール': {
      'type': ItemType.placeable,
      'description': '設置すると近くの敵を自動攻撃する。',
      'spritePath': 'igniter.png',
      'value': 80,
      'placeableEffect': 'automationWard',
      'size': [25.0, 25.0],
      'mass': 2.0,
    },
    '岩盤充填剤': {
      'type': ItemType.placeable,
      'description': '地下で掘った穴を選んだ位置に埋め戻す。地下にいるときだけ「配置」できる。',
      'spritePath': 'concrete_item.png',
      'value': 40,
      'placeableEffect': 'terrainFill',
      'requiresUnderGround': true,
      'size': [25.0, 25.0],
      'mass': 1.8,
    },
    '床板': {
      'type': ItemType.placeable,
      'description':
          '地下のトンネル内に水平な床を設置する。近くの床に高さが揃う。地下にいるときだけ「配置」できる。',
      'spritePath': 'concrete_item.png',
      'value': 35,
      'placeableEffect': 'floorPlate',
      'requiresUnderGround': true,
      'size': [25.0, 25.0],
      'mass': 1.5,
    },
    'ランタン': {
      'type': ItemType.placeable,
      'description': '暗い場所を照らす。持って運ぶか、足元に置ける。',
      'spritePath': 'lantern.png',
      'value': 150,
      'placeableEffect': 'furniture',
      'requiresUnderGround': true,
      'size': [25.0, 25.0],
      'mass': 1.0,
      'brightnessLevel': 600,
      'spriteSheet': {
        'frameWidth': 51.0,
        'frameHeight': 51.0,
        'frameCount': 3,
      },
    },
    'はしご': {
      'type': ItemType.tool,
      'description': 'はしごは高いところに登るのに便利です。',
      'spritePath': 'ladder.png',
      'value': 10,
      'toolEffect': 'throw',
      'attackPower': 1.0,
      'mass': 5.0,
      'size': [25.0, 25.0],
    },
    'バルブ': {
      'type': ItemType.collection,
      'description': 'ロケットの部品。古いバルブだ（設置用の自動化装置とは別物）。',
      'spritePath': 'valve.png',
      'value': 100,
      'size': [30.0, 30.0],
      'mass': 2.0,
    },
    '点火装置': {
      'type': ItemType.collection,
      'description': 'ロケットの部品。点火用のスパークユニットです。',
      'spritePath': 'igniter.png',
      'value': 100,
      'size': [30.0, 30.0],
      'mass': 1.0,
    },
    'ノズル': {
      'type': ItemType.collection,
      'description': 'ロケットの部品。推進剤を噴射する出口です。',
      'spritePath': 'nozzle.png',
      'value': 100,
      'size': [30.0, 30.0],
      'mass': 3.0,
    },

    // --- Stage 1-5 コレクションアイテム ---
    '生体サンプル': {
      'type': ItemType.collection,
      'resourceType': ResourceType.life,
      'description': '未知の生命体から採取された組織片。微かに脈動している。',
      'spritePath': 'heart.png',
      'value': 0,
      'size': [30.0, 30.0],
      'mass': 0.5,
    },
    '高出力電源': {
      'type': ItemType.collection,
      'resourceType': ResourceType.inorganic,
      'description': '都市の動力源から回収された、高密度のエネルギーセル。',
      'spritePath': 'energy_cube.png',
      'value': 0,
      'size': [30.0, 30.0],
      'mass': 4.0,
    },
    '記録アーカイブ': {
      'type': ItemType.collection,
      'resourceType': ResourceType.history,
      'description': 'かつての居住者が残したと思われる、古いデータストレージ。',
      'spritePath': 'warm_memory.png',
      'value': 0,
      'size': [30.0, 30.0],
      'mass': 1.0,
    },
    '中枢演算コア': {
      'type': ItemType.collection,
      'resourceType': ResourceType.inorganic,
      'description': '高度な演算処理を司るモジュール。回路が複雑に絡み合っている。',
      'spritePath': 'player_icon.png',
      'value': 0,
      'size': [30.0, 30.0],
      'mass': 2.5,
    },
    // ... (rest of the items)

    // --- Stage 6 用コレクションアイテム ---
    '最終調査報告書': {
      'type': ItemType.collection,
      'resourceType': ResourceType.history,
      'description': 'これまでの調査のすべてを記した、おじさんへの最後の報告。',
      'spritePath': 'doodle_book.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    '殲滅完了コード': {
      'type': ItemType.collection,
      'resourceType': ResourceType.inorganic,
      'description': '全ノイズの消去が完了したことを示す、冷徹な実行結果。',
      'spritePath': 'forbidden_data.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    '心のバックアップ': {
      'type': ItemType.collection,
      'resourceType': ResourceType.history,
      'description': '彼らがここにいたという証。温かな光を放っている。',
      'spritePath': 'warm_memory.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    '真実へのアクセスキー': {
      'type': ItemType.collection,
      'resourceType': ResourceType.inorganic,
      'description': '世界の「外側」へ繋がる、論理の亀裂をこじ開ける鍵。',
      'spritePath': 'ai_icon.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    '最適化完了ログ': {
      'type': ItemType.collection,
      'resourceType': ResourceType.inorganic,
      'description': 'すべての演算が最短経路で終了したことを示すログ。',
      'spritePath': 'energy_cube.png',
      'value': 0,
      'size': [30.0, 30.0],
    },

    // --- 合成アイテム ---
    '石付き棒': {
      'type': ItemType.tool,
      'description': '石を棒の先端に固定した武器。重みで威力が増した。',
      'spritePath': 'stick.png',
      'value': 5,
      'toolEffect': 'swing',
      'attackPower': 8.0,
      'mass': 2.0,
      'size': [25.0, 25.0],
    },
    '削岩棒': {
      'type': ItemType.tool,
      'description': 'この星の鉱石で強化された棒。敵を打つと地形にも亀裂が走る。',
      'spritePath': 'stick.png',
      'value': 20,
      'toolEffect': 'swing',
      'attackPower': 14.0,
      'mass': 3.0,
      'size': [25.0, 25.0],
    },
    '火炎瓶': {
      'type': ItemType.tool,
      'description': 'C-2/B-3 関連の投擲弾（プレースホルダーグラフィック）。',
      'spritePath': 'energy_cube.png',
      'value': 8,
      'toolEffect': 'throw',
      'attackPower': 9.0,
      'mass': 0.8,
      'size': [18.0, 22.0],
    },
    '火炎放射器': {
      'type': ItemType.tool,
      'description': 'C-2 契約報酬として与えられる簡易火炎兵器。',
      'spritePath': 'energy_cube.png',
      'value': 40,
      'toolEffect': 'swing',
      'attackPower': 12.0,
      'mass': 2.2,
      'size': [28.0, 20.0],
    },
    '鋭い石': {
      'type': ItemType.tool,
      'resourceType': ResourceType.inorganic,
      'description': '石同士を打ち合わせて作った刃。投げると刺さる。',
      'spritePath': 'stone.png',
      'value': 5,
      'toolEffect': 'throw',
      'attackPower': 4.0,
      'mass': 1.5,
      'size': [25.0, 25.0],
    },
    '長い棒': {
      'type': ItemType.tool,
      'description': '棒を2本繋いだ長い杖。リーチが長く、軽い。',
      'spritePath': 'stick.png',
      'value': 5,
      'toolEffect': 'swing',
      'attackPower': 7.0,
      'mass': 1.2,
      'size': [25.0, 25.0],
    },
    '広刃棒': {
      'type': ItemType.tool,
      'description': '幅のある打撃面。敵を倒すと残滓が多く散る。',
      'spritePath': 'stick.png',
      'value': 12,
      'toolEffect': 'swing',
      'attackPower': 6.0,
      'mass': 2.4,
      'size': [28.0, 25.0],
    },
    '簡易盾': {
      'type': ItemType.tool,
      'description': '石と棒で組んだ盾。接触ストレスを抑える。',
      'spritePath': 'stone.png',
      'value': 10,
      'toolEffect': 'swing',
      'attackPower': 3.0,
      'mass': 3.5,
      'size': [22.0, 26.0],
    },
    '軽装の足袋': {
      'type': ItemType.tool,
      'description': '足元を軽くする装備。装備中は移動が僅かに速い。',
      'spritePath': 'stick.png',
      'value': 8,
      'toolEffect': 'swing',
      'attackPower': 1.0,
      'mass': 0.5,
      'size': [18.0, 14.0],
    },

    'ガソリン缶': {
      'type': ItemType.tool,
      'description': '自動化装置に燃料を補充するための携行缶。装置の近くで使用する。',
      'spritePath': 'gasoline_can.png',
      'value': 100,
      'toolEffect': 'gasolinePour',
      'attackPower': 0.0,
      'mass': 1.5,
      'size': [22.0, 22.0],
    },
    // --- 装置燃料（残滓／意志の圧縮駆動熱）---
    '粗製燃料': {
      'type': ItemType.custom,
      'description': '残滓を整備装置で圧縮した駆動熱。装置タンクへ入れて使う。',
      'actionType': BagWindowActionType.none,
      'spritePath': 'cargo.png',
      'value': 0,
      'size': [22.0, 22.0],
      'mass': 0.4,
    },
    '生命馏分': {
      'type': ItemType.custom,
      'description': '生命残滓を偏らせて精製した液体燃料。防衛装置と相性が良い。',
      'actionType': BagWindowActionType.none,
      'spritePath': 'heart.png',
      'value': 0,
      'size': [22.0, 22.0],
      'mass': 0.35,
    },
    '歴史胶质': {
      'type': ItemType.custom,
      'description': '歴史残滓を偏らせて精製した粘稠燃料。収穫装置と相性が良い。',
      'actionType': BagWindowActionType.none,
      'spritePath': 'warm_memory.png',
      'value': 0,
      'size': [22.0, 22.0],
      'mass': 0.35,
    },
    '無機基油': {
      'type': ItemType.custom,
      'description': '無機残滓を偏らせて精製した基油。整備装置と相性が良い。',
      'actionType': BagWindowActionType.none,
      'spritePath': 'energy_cube.png',
      'value': 0,
      'size': [22.0, 22.0],
      'mass': 0.45,
    },
    '意志凝固': {
      'type': ItemType.custom,
      'description': '意志力を整備装置で固めた高効率燃料。',
      'actionType': BagWindowActionType.none,
      'spritePath': 'initiator_icon.png',
      'value': 0,
      'size': [22.0, 22.0],
      'mass': 0.5,
    },

    // 旧アイテム定義
    '赤い果実': {
      'type': ItemType.collection,
      'resourceType': ResourceType.life,
      'description': '赤い果実。',
      'spritePath': 'heart.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    '意味を忘れないためのメモ': {
      'type': ItemType.collection,
      'resourceType': ResourceType.history,
      'description': '「いつか私が私でなくなっても、この場所だけは私を覚えている。」そう記された、おじさんの古いメモ。',
      'spritePath': 'doodle_book.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    'おじさんの手書きノート': {
      'type': ItemType.collection,
      'resourceType': ResourceType.history,
      'description': '「ここはデータではなく記憶が溜まる場所だ」……震える文字で、この場所の真実が記されている。',
      'spritePath': 'warm_memory.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    '破損したメモリ': {
      'type': ItemType.collection,
      'resourceType': ResourceType.inorganic,
      'description': '壊れたデータ。',
      'spritePath': 'forbidden_data.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
  };

  /// スプライトシートメタデータ（アニメーションアイテム用）。
  static ItemSpriteSheetMeta? spriteSheetMetaForName(String name) {
    final itemData = _itemDefinitions[name];
    if (itemData == null) return null;
    final raw = itemData['spriteSheet'] as Map<String, dynamic>?;
    if (raw == null) return null;
    return ItemSpriteSheetMeta.fromMap(raw);
  }

  /// [spritePath] からスプライトシートメタデータを逆引きする。
  static ItemSpriteSheetMeta? spriteSheetMetaForSpritePath(String spritePath) {
    for (final entry in _itemDefinitions.entries) {
      if (entry.value['spritePath'] == spritePath &&
          entry.value['spriteSheet'] != null) {
        return spriteSheetMetaForName(entry.key);
      }
    }
    return null;
  }

  /// UI 等でメタデータを解決する（名前優先、なければ spritePath）。
  static ItemSpriteSheetMeta? resolveSpriteSheetMeta({
    required String itemName,
    required String spritePath,
  }) {
    return spriteSheetMetaForName(itemName) ??
        spriteSheetMetaForSpritePath(spritePath);
  }

  /// ランタン光源を持つアイテムか（設置・運搬どちらの型でも判定）。
  static bool isLanternLightItem(Item item) {
    return item is LanternItem || item.name == 'ランタン';
  }

  /// 設置済みランタンを登録し、punch ベイクが終わるまで待つ。
  static Future<void> registerPlacedLanternIfNeeded(
    Item? item,
    MyGame game,
  ) async {
    if (item is LanternItem) {
      await LanternStripLightRegistry.instance.register(item, game);
    }
  }

  /// ワールド設置後の表示（運搬から置く経路と同じアニメ子を付与）。
  static Future<void> applyPlacedWorldItemWorldDisplay(Item item) async {
    await item.loaded;
    await item.attachWorldAnimationIfNeeded();
  }

  /// バッグ/配置モードから placeable を開始（[LanternItem] 等でも名前で解決）。
  static bool tryStartPlaceablePlacement(MyGame game, Item item) {
    final itemData = _itemDefinitions[item.name];
    if (itemData == null) return false;
    if (itemData['type'] as ItemType != ItemType.placeable) return false;

    final effectName = itemData['placeableEffect'] as String?;
    final resolved = PlaceableEffectResolver.resolve(
      effectName,
      itemName: item.name,
      spritePath: item.spritePath,
    );
    if (resolved == null) return false;

    resolved(game);
    return game.placeablePlacement.isActive.value;
  }

  /// UI・運搬表示用スプライト（シートの場合は1フレーム目）。
  static Future<Sprite> loadDisplaySprite(
    MyGame game,
    String name,
    String spritePath,
  ) async {
    final meta = spriteSheetMetaForName(name);
    if (meta != null) {
      final image = await game.images.load(spritePath);
      return meta.firstFrameSprite(image);
    }
    return game.loadSprite(spritePath);
  }

  /// 配置プレビュー用サイズ（ワールド px）。
  static Vector2? previewSizeForName(String name) {
    final itemData = _itemDefinitions[name];
    if (itemData == null) return null;
    final raw = itemData['size'] as List<dynamic>?;
    if (raw == null || raw.length < 2) return null;
    return Vector2(
      raw[0].toDouble(),
      raw[1].toDouble(),
    );
  }

  /// 配置モード確定時にワールドへ置く実体（ランタンは [LanternItem] 等）。
  static Item? createPlacedWorldItemByName(String name, Vector2 position) {
    final itemData = _itemDefinitions[name];
    if (itemData == null) {
      debugPrint('Undefined item: $name');
      return null;
    }

    final description = itemData['description'] as String;
    final spritePath = itemData['spritePath'] as String;
    final value = itemData['value'] as int;
    final mass = (itemData['mass'] as num?)?.toDouble() ?? 1.0;
    final size = previewSizeForName(name) ?? Vector2(25, 25);

    if (name == 'ランタン') {
      return LanternItem(
        name: name,
        description: description,
        value: value,
        spritePath: spritePath,
        position: position,
        size: size,
        mass: mass,
      );
    }

    return createItemByName(name, position);
  }

  /// 名前からアイテムを生成
  static Item? createItemByName(String name, Vector2 position) {
    final itemData = _itemDefinitions[name];
    if (itemData == null) {
      debugPrint('Undefined item: $name');
      return null;
    }

    final type = itemData['type'] as ItemType;
    final resourceType = (itemData['resourceType'] as ResourceType?) ?? ResourceType.none;
    final description = itemData['description'] as String;
    final spritePath = itemData['spritePath'] as String;
    final value = itemData['value'] as int;
    final attackPower = (itemData['attackPower'] as num?)?.toDouble() ?? 0.0;
    final mass = (itemData['mass'] as num?)?.toDouble() ?? 1.0;
    final size = Vector2(
      (itemData['size'] as List<dynamic>)[0].toDouble(),
      (itemData['size'] as List<dynamic>)[1].toDouble(),
    );

    switch (type) {
      case ItemType.currency:
        return CurrencyItem(
          position: position,
          currencyValue: value,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
          mass: mass,
        );
      case ItemType.gem:
        return GemItem(
          position: position,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
          mass: mass,
        )..resourceType = resourceType;
      case ItemType.health:
        return HealthItem(
          position: position,
          healAmount: (itemData['healAmount'] as num?)?.toDouble() ?? 0.0,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
          mass: mass,
        );
      case ItemType.stress:
        return StressItem(
          position: position,
          stressReduction:
              (itemData['stressReduction'] as num?)?.toDouble() ?? 0.0,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
          mass: mass,
        );
      case ItemType.powerUp:
        final effectName = itemData['powerUpEffect'] as String?;
        final resolvedPowerUpEffect = PowerUpEffectResolver.resolve(effectName);
        if (resolvedPowerUpEffect == null) {
          debugPrint(
            'PowerUpItem: unknown powerUpEffect "$effectName" for $name',
          );
          return null;
        }
        return PowerUpItem(
          powerUpEffect: resolvedPowerUpEffect,
          position: position,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
          mass: mass,
        );
      case ItemType.tool:
        final effectName = itemData['toolEffect'] as String?;
        final resolvedToolEffect = ToolEffectResolver.resolve(effectName);
        if (resolvedToolEffect == null) {
          debugPrint('ToolItem: unknown toolEffect "$effectName" for $name');
          return null;
        }
        return ToolItem(
          toolEffect: resolvedToolEffect,
          position: position,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
          attackPower: attackPower,
          mass: mass,
        )..resourceType = resourceType;
      case ItemType.placeable:
        final effectName = itemData['placeableEffect'] as String?;
        final resolvedPlaceableEffect = PlaceableEffectResolver.resolve(
          effectName,
          itemName: name,
          spritePath: spritePath,
        );
        return PlaceableItem(
          placeableEffect: resolvedPlaceableEffect,
          requiresUnderGround:
              itemData['requiresUnderGround'] as bool? ?? false,
          position: position,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
          mass: mass,
        );
      case ItemType.custom:
        final effectName = itemData['customEffect'] as String?;
        final resolvedEffect = CustomItemEffectResolver.resolve(effectName);
        final customActionType =
            (itemData['actionType'] as BagWindowActionType?) ??
            BagWindowActionType.consume;
        final customAutoUse = itemData['autoUse'] as bool? ?? false;
        if (resolvedEffect == null) {
          debugPrint('CustomItem: unknown customEffect "$effectName" for $name');
          return null;
        }
        return CustomItem(
          position: position,
          customEffect: resolvedEffect,
          customActionType: customActionType,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
          mass: mass,
          autoUse: customAutoUse,
        );
      case ItemType.collection:
        return CollectionItem(
          position: position,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
          mass: mass,
        )..resourceType = resourceType;
    }
  }

  static List<String> getAllItemNames() {
    return _itemDefinitions.keys.toList();
  }

  /// テスト用にランダムなアイテムを生成してプレイヤーの近くに配置する
  static void spawnTestItems(MyGame game, Player player) {
    final random = Random();
    final allNames = getAllItemNames();

    // 5個のランダムなアイテムを生成
    for (int i = 0; i < 5; i++) {
      final name = allNames[random.nextInt(allNames.length)];
      // プレイヤーの周囲にランダムに配置
      final offset = Vector2(
        (random.nextDouble() - 0.5) * 200,
        -50 - random.nextDouble() * 100,
      );
      final item = createItemByName(name, player.position + offset);
      if (item != null) {
        game.world.add(item);
      }
    }
  }
}
