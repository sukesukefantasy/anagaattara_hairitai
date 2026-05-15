import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../common/hitboxes/physics_hitbox.dart';
import '../common/physics/physics_behavior.dart';
import '../player.dart';
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
  none, // なし
}

/// アイテムの基底クラス。
abstract class Item extends SpriteComponent
    with HasGameReference<MyGame>
    implements HasPhysicsBehavior {
  final String name;
  final String description;
  final int value;
  final String spritePath;
  final ItemType type;
  final double attackPower; // 攻撃力（ツール等で使用）
  final double mass; // 質量（ダメージ計算や物理挙動で使用）
  ResourceType resourceType;
  bool isCollected = false;

  @override
  late final PhysicsBehavior physicsBehavior;

  Item({
    required this.name,
    required this.description,
    required this.value,
    required this.spritePath,
    required this.type,
    this.attackPower = 0.0,
    this.mass = 1.0,
    this.resourceType = ResourceType.none,
    required super.position,
    required super.size,
  }) {
    priority = 10;
    physicsBehavior = PhysicsBehavior(parent: this, mass: mass);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load(spritePath);

    // ヒットボックスの追加
    add(PhysicsHitbox(parent: this, size: size));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isCollected) {
      physicsBehavior.applyPhysics(dt);
    }
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

  /// プレイヤーによる収集
  void collectItemByPlayer(Player player) {
    if (isCollected) return;
    isCollected = true;
    player.collectItem(this);
    removeFromParent();
  }

  bool get isMemoItem => name.contains('メモ') || name.contains('LOG');
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
}

/// 設置アイテム
class PlaceableItem extends Item {
  final void Function(MyGame game)? placeableEffect;
  PlaceableItem({
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
    this.placeableEffect,
    super.mass,
  }) : super(type: ItemType.placeable);

  @override
  void onUse(Player player) {
    placeableEffect?.call(game);
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
    },
    '自動化キット': {
      'type': ItemType.placeable,
      'description':
          '設置して手を動かすと通貨と採掘ポイントが貯まる。強化すると自動化できる。',
      'spritePath': 'energy_cube.png',
      'value': 80,
      'placeableEffect': 'automationKit',
      'size': [25.0, 25.0],
      'mass': 2.0,
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
      'description': 'ロケットの部品。古いバルブです。',
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
        );
        return PlaceableItem(
          placeableEffect: resolvedPlaceableEffect,
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
