import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../common/hitboxes/physics_hitbox.dart';
import '../common/physics/physics_behavior.dart';
import '../player.dart';

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
  bool isCollected = false;

  @override
  late final PhysicsBehavior physicsBehavior;

  Item({
    required this.name,
    required this.description,
    required this.value,
    required this.spritePath,
    required this.type,
    required super.position,
    required super.size,
  }) {
    priority = 10;
    physicsBehavior = PhysicsBehavior(parent: this);
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
  String get displayName => game.missionManager.getItemDisplayName(name);

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
  }) : super(type: ItemType.currency);

  @override
  void onUse(Player player) {
    game.gameRuntimeState.currency += currencyValue;
    player.itemBag.removeItem(name);
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
  }) : super(type: ItemType.health);

  @override
  void onUse(Player player) {
    player.recoveryHp(healAmount);
    player.itemBag.removeItem(name);
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
  }) : super(type: ItemType.stress);

  @override
  void onUse(Player player) {
    player.updateStress(max(0, player.currentStress - stressReduction));
    player.itemBag.removeItem(name);
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
  }) : super(type: ItemType.powerUp);

  @override
  void onUse(Player player) {
    powerUpEffect?.call(game);
    player.itemBag.removeItem(name);
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
  }) : super(type: ItemType.placeable);
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
  }) : super(type: ItemType.custom);

  @override
  void onUse(Player player) {
    customEffect(game);
    if (customActionType == BagWindowActionType.consume) {
      player.itemBag.removeItem(name);
    }
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
  }) : super(type: ItemType.collection);
}

/// パワーアップ効果のレゾルバ
class PowerUpEffectResolver {
  static void Function(MyGame)? resolve(String? effectName) {
    switch (effectName) {
      case 'increaseMaxHealth':
        return (game) {
          game.gameRuntimeState.hpBonus += 20;
          game.player.recoveryHp(20);
        };
      case 'addMaxStress':
        return (game) {
          game.gameRuntimeState.stressBonus += 20;
          game.player.updateStress(max(0, game.player.currentStress - 20));
        };
      default:
        return null;
    }
  }
}

/// 道具効果のレゾルバ
class ToolEffectResolver {
  static void Function(MyGame)? resolve(String? effectName) {
    switch (effectName) {
      case 'swing':
        return (game) {
          game.player.performMeleeAttack();
        };
      case 'throw':
        return (game) {
          final itemName = game.player.itemBag.equippedItemName;
          if (itemName != null) {
            final item = ItemFactory.createItemByName(itemName, Vector2.zero());
            if (item != null) {
              game.player.throwWorldObject(item);
              game.player.itemBag.removeItem(itemName, count: 1);
            }
          }
        };
      default:
        return null;
    }
  }
}

/// 設置効果のレゾルバ
class PlaceableEffectResolver {
  static void Function(MyGame)? resolve(String? effectName) {
    return null;
  }
}

/// 特殊アイテム効果のレゾルバ
class CustomItemEffectResolver {
  static void Function(MyGame)? resolve(String? effectName) {
    switch (effectName) {
      case 'updateMiningPoints5':
        return (game) {
          game.player.updateMiningPoints(5);
        };
      default:
        return null;
    }
  }
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
    },
    'クオーツ': {
      'type': ItemType.gem,
      'description': 'カラフルな石です。',
      'spritePath': 'quartz.png',
      'value': 50,
      'size': [25.0, 25.0],
    },
    'エメラルド': {
      'type': ItemType.gem,
      'description': '緑色の石です。',
      'spritePath': 'emerald.png',
      'value': 50,
      'size': [25.0, 25.0],
    },
    '栄養剤': {
      'type': ItemType.health,
      'description': 'Health を100回復します',
      'spritePath': 'health_potion.png',
      'value': 50,
      'healAmount': 100.0,
      'size': [25.0, 25.0],
    },
    'お茶の力': {
      'type': ItemType.stress,
      'description': 'ストレスを20軽減し、最大ストレス値を増加します',
      'spritePath': 'green_cha.png',
      'value': 70,
      'stressReduction': 20.0,
      'size': [25.0, 25.0],
    },
    'レッド・ブリ': {
      'type': ItemType.powerUp,
      'description': '使用するとキマリます。1時間の間、ストレスを無効にします',
      'spritePath': 'blue_red.png',
      'value': 460,
      'powerUpEffect': 'addMaxStress',
      'size': [25.0, 25.0],
    },
    '棒': {
      'type': ItemType.tool,
      'description': 'この星を構成している何か',
      'spritePath': 'stick.png',
      'value': 1,
      'toolEffect': 'swing',
      'size': [25.0, 25.0],
    },
    '石': {
      'type': ItemType.tool,
      'description': 'この星の地層から採取された、未知の組成を持つ鉱石。',
      'spritePath': 'stone.png',
      'value': 1,
      'toolEffect': 'throw',
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
    },
    'はしご': {
      'type': ItemType.tool,
      'description': 'はしごは高いところに登るのに便利です。',
      'spritePath': 'ladder.png',
      'value': 10,
      'toolEffect': 'throw',
      'size': [25.0, 25.0],
    },
    'バルブ': {
      'type': ItemType.collection,
      'description': 'ロケットの部品。古いバルブです。',
      'spritePath': 'valve.png',
      'value': 100,
      'size': [30.0, 30.0],
    },
    '点火装置': {
      'type': ItemType.collection,
      'description': 'ロケットの部品。点火用のスパークユニットです。',
      'spritePath': 'igniter.png',
      'value': 100,
      'size': [30.0, 30.0],
    },
    'ノズル': {
      'type': ItemType.collection,
      'description': 'ロケットの部品。推進剤を噴射する出口です。',
      'spritePath': 'nozzle.png',
      'value': 100,
      'size': [30.0, 30.0],
    },

    // --- Stage 1-5 コレクションアイテム ---
    '生体サンプル': {
      'type': ItemType.collection,
      'description': '未知の生命体から採取された組織片。微かに脈動している。',
      'spritePath': 'heart.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    '高出力電源': {
      'type': ItemType.collection,
      'description': '都市の動力源から回収された、高密度のエネルギーセル。',
      'spritePath': 'energy_cube.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    '記録アーカイブ': {
      'type': ItemType.collection,
      'description': 'かつての居住者が残したと思われる、古いデータストレージ。',
      'spritePath': 'warm_memory.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    '中枢演算コア': {
      'type': ItemType.collection,
      'description': '高度な演算処理を司るモジュール。回路が複雑に絡み合っている。',
      'spritePath': 'player_icon.png',
      'value': 0,
      'size': [30.0, 30.0],
    },

    // --- Stage 6 用コレクションアイテム ---
    '最終調査報告書': {
      'type': ItemType.collection,
      'description': 'これまでの調査のすべてを記した、おじさんへの最後の報告。',
      'spritePath': 'doodle_book.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    '殲滅完了コード': {
      'type': ItemType.collection,
      'description': '全ノイズの消去が完了したことを示す、冷徹な実行結果。',
      'spritePath': 'forbidden_data.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    '心のバックアップ': {
      'type': ItemType.collection,
      'description': '彼らがここにいたという証。温かな光を放っている。',
      'spritePath': 'warm_memory.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    '真実へのアクセスキー': {
      'type': ItemType.collection,
      'description': '世界の「外側」へ繋がる、論理の亀裂をこじ開ける鍵。',
      'spritePath': 'ai_icon.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    '最適化完了ログ': {
      'type': ItemType.collection,
      'description': 'すべての演算が最短経路で終了したことを示すログ。',
      'spritePath': 'energy_cube.png',
      'value': 0,
      'size': [30.0, 30.0],
    },

    // 旧アイテム定義
    '赤い果実': {
      'type': ItemType.collection,
      'description': '赤い果実。',
      'spritePath': 'heart.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    '意味を忘れないためのメモ': {
      'type': ItemType.collection,
      'description': '「いつか私が私でなくなっても、この場所だけは私を覚えている。」そう記された、おじさんの古いメモ。',
      'spritePath': 'doodle_book.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    'おじさんの手書きノート': {
      'type': ItemType.collection,
      'description': '「ここはデータではなく記憶が溜まる場所だ」……震える文字で、この場所の真実が記されている。',
      'spritePath': 'warm_memory.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    '破損したメモリ': {
      'type': ItemType.collection,
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
    final description = itemData['description'] as String;
    final spritePath = itemData['spritePath'] as String;
    final value = itemData['value'] as int;
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
        );
      case ItemType.gem:
        return GemItem(
          position: position,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
        );
      case ItemType.health:
        return HealthItem(
          position: position,
          healAmount: (itemData['healAmount'] as num?)?.toDouble() ?? 0.0,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
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
        );
      case ItemType.powerUp:
        final effectName = itemData['powerUpEffect'] as String?;
        final resolvedPowerUpEffect = PowerUpEffectResolver.resolve(effectName);
        return PowerUpItem(
          powerUpEffect: resolvedPowerUpEffect,
          position: position,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
        );
      case ItemType.tool:
        final effectName = itemData['toolEffect'] as String?;
        final resolvedToolEffect = ToolEffectResolver.resolve(effectName);
        return ToolItem(
          toolEffect: resolvedToolEffect,
          position: position,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
        );
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
        );
      case ItemType.custom:
        final effectName = itemData['customEffect'] as String?;
        final resolvedEffect = CustomItemEffectResolver.resolve(effectName);
        final customActionType =
            (itemData['actionType'] as BagWindowActionType?) ??
            BagWindowActionType.consume;
        return CustomItem(
          position: position,
          customEffect: resolvedEffect!,
          customActionType: customActionType,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
        );
      case ItemType.collection:
        return CollectionItem(
          position: position,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
        );
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
