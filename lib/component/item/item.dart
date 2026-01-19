// インベントリ内のアイテム管理、生成する責任。

import 'package:flame/components.dart';
import 'dart:math'; // Random用にインポート
import 'package:flutter/material.dart';
import '../player.dart';
import '../../main.dart';
import '../common/physics/physics_behavior.dart';
import 'package:anagaattara_hairitai/component/common/hitboxes/physics_hitbox.dart';
import 'item_effect_resolver/powerup_item_effect_resolver.dart';
import 'item_effect_resolver/custom_item_effect_resolver.dart';
import '../../deb/debug_paint.dart'; // DebugPaintMixinをインポート

/// アイテムの種類を定義する列挙型
enum ItemType {
  // 資産 ------------
  currency, // 通貨
  gem, // 宝石
  // 食品、飲料、薬 ------------
  health, // health回復アイテム
  stress, // stress回復アイテム
  powerUp, // パワーアップアイテム
  // 装備アイテム ------------
  tool, // 道具アイテム
  // その他 ------------
  placeable, // 配置アイテム
  custom, // カスタムアイテム
}

enum BagWindowActionType { consume, carry, equip, unequip, dismantle, view, custom }

/// アイテムの基底クラス
abstract class Item extends SpriteComponent
    with HasGameReference
    implements HasPhysicsBehavior {
  final String name;
  final ItemType type;
  final String description;
  final int value;
  final String spritePath;
  bool isCollected = false;
  @override
  late PhysicsBehavior physicsBehavior; // late に変更

  Item({
    required this.name,
    required this.type,
    required this.description,
    required this.value,
    required this.spritePath,
    required super.position,
    required super.size,
    super.anchor = Anchor.center,
    super.priority = 100,
  }) : super(); // 初期化リストから physicsBehavior の初期化を削除

  @override
  Future<void> onLoad() async {
    await super.onLoad(); // debugPaintMixinのonLoad
    // スプライトをロード
    if (spritePath.isNotEmpty) {
      sprite = await game.loadSprite(spritePath);
    }

    // アイテムがロードされた時にPhysicsBehaviorを初期化し、自身をparentとして設定
    physicsBehavior = PhysicsBehavior(parent: this); // ここで初期化

    // PhysicsHitboxを生成してPhysicsBehaviorにセットし、コンポーネントに追加
    final itemHitbox = PhysicsHitbox(parent: this, size: size);
    add(itemHitbox);
    physicsBehavior.setHitbox(itemHitbox);

    // アイテム固有の初期化処理
    await onItemLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    physicsBehavior?.applyPhysics(dt);
  }

  Future<void> onItemLoad() async {}

  /// アイテムを収集する処理 (フィールドで拾われた時)
  void collectItemByPlayer(Player player) {
    if (isCollected) return;

    isCollected = true;

    // PlayerのItemBagにアイテムを追加
    player.collectItem(this);

    // アイテムをゲームワールドから削除
    removeFromParent();

    debugPrint('アイテム収集: $name (価値: $value)');
  }

  /// アイテムが使用された時の処理（サブクラスで実装）
  void onUse(Player player);

  /// アイテムの名前を取得
  String getName() => name;

  /// アイテムの種類を取得
  ItemType getType() => type;

  /// アイテムの説明文を取得
  String getDescription() => description;

  /// アイテムの価値を取得
  int getValue() => value;

  /// アイテムのスプライトを取得
  Sprite? getSprite() => sprite;

  /// テスト用アイテムを生成する
  static Future<void> spawnTestItems(MyGame myGame, Player player) async {
    // 全てのアイテム名を取得
    final itemNames = ItemFactory._itemDefinitions.keys.toList();
    // ランダムなアイテムを1つ選択
    final randomItemName = itemNames[Random().nextInt(itemNames.length)];

    // プレイヤーの現在位置と向きに基づいて生成位置を決定
    final spawnX =
        player.position.x + player.facingDirection.x * 50; // プレイヤーの50px前方に
    final spawnY = player.position.y - 100; // プレイヤーの100px上方に

    final newItem = ItemFactory.createItemByName(
      randomItemName,
      Vector2(spawnX, spawnY),
    );

    if (newItem != null) {
      myGame.world.add(newItem);
      await newItem.loaded; // アイテムのロードが完了するまで待機
      newItem.physicsBehavior.setEnabled(true); // 物理挙動を有効化
      debugPrint(
        'テスト用アイテム "$randomItemName" をプレイヤーの前方上（$spawnX, $spawnY）に配置しました',
      );
    } else {
      debugPrint('テスト用アイテム "$randomItemName" の生成に失敗しました。このアイテムは存在しません。');
    }
  }
}

/// 通貨アイテム
class CurrencyItem extends Item {
  final int currencyValue;

  CurrencyItem({
    required this.currencyValue,
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
  }) : super(type: ItemType.currency);

  @override
  Future<void> onItemLoad() async {
    if (spritePath.isNotEmpty) {
      sprite = await game.loadSprite(spritePath);
    }
  }

  @override
  void onUse(Player player) {
    // お金を増やす
    player.updateMoneyPoints(currencyValue);
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

  @override
  Future<void> onItemLoad() async {
    if (spritePath.isNotEmpty) {
      sprite = await game.loadSprite(spritePath);
    }
  }

  @override
  void onUse(Player player) {
    // 後々眺められるようにする
  }
}

/// 回復アイテム
class HealthItem extends Item {
  final double healAmount;

  HealthItem({
    required this.healAmount,
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
  }) : super(type: ItemType.health);

  @override
  Future<void> onItemLoad() async {
    if (spritePath.isNotEmpty) {
      sprite = await game.loadSprite(spritePath);
    }
  }

  @override
  void onUse(Player player) {
    // HPを回復
    player.recoveryHp(healAmount);
  }
}

/// ストレス回復アイテム
class StressItem extends Item {
  final double stressReduction;

  StressItem({
    required this.stressReduction,
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
  }) : super(type: ItemType.stress);

  @override
  Future<void> onItemLoad() async {
    if (spritePath.isNotEmpty) {
      sprite = await game.loadSprite(spritePath);
    }
  }

  @override
  void onUse(Player player) {
    // ストレスを軽減
    player.updateStress(player.currentStress - stressReduction);
  }
}

/// パワーアップアイテム
class PowerUpItem extends Item {
  final Function(Player)? powerUpEffect;

  PowerUpItem({
    this.powerUpEffect,
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
  }) : super(type: ItemType.powerUp);

  @override
  Future<void> onItemLoad() async {
    if (spritePath.isNotEmpty) {
      sprite = await game.loadSprite(spritePath);
    }
  }

  @override
  void onUse(Player player) {
    // パワーアップ効果を実行
    powerUpEffect?.call(player);
  }
}

/// 道具アイテム
class ToolItem extends Item {
  ToolItem({
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
  }) : super(type: ItemType.tool);

  @override
  Future<void> onItemLoad() async {
    if (spritePath.isNotEmpty) {
      sprite = await game.loadSprite(spritePath);
    }
  }

  @override
  void onUse(Player player) {}
}

/// 配置アイテム
class PlaceableItem extends Item {
  PlaceableItem({
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    required super.size,
  }) : super(type: ItemType.placeable);

  @override
  Future<void> onItemLoad() async {
    if (spritePath.isNotEmpty) {
      sprite = await game.loadSprite(spritePath);
    }
  }

  @override
  Future<void> onUse(Player player) async {
    print('$name を使用してワールドに配置を試みます。');

    // プレイヤーがアイテムを運搬開始
    await player.startCarrying(this);
    debugPrint('Item.onUse: $name の運搬を開始しました。');

    // アイテムメニューを閉じる
    (game as MyGame).windowManager.hideWindow();
  }
}

/// カスタムアイテム（独自の効果を持つアイテム用）
class CustomItem extends Item {
  final Function(Player) customEffect;
  final BagWindowActionType customActionType;

  CustomItem({
    required this.customEffect,
    this.customActionType = BagWindowActionType.consume,
    required super.name,
    required super.description,
    required super.value,
    required super.spritePath,
    required super.position,
    Vector2? size,
  }) : super(type: ItemType.custom, size: size ?? Vector2.all(30));

  @override
  Future<void> onItemLoad() async {
    if (spritePath.isNotEmpty) {
      sprite = await game.loadSprite(spritePath);
    }
  }

  @override
  void onUse(Player player) {
    // カスタム効果を実行
    customEffect(player);
  }
}

/// アイテム生成用のファクトリークラス
class ItemFactory {
  /* static final Random _random = Random(); */

  // 全てのアイテムの定義をここに集中させる
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
      'value': 10,
      'size': [25.0, 25.0],
    },
    '石': {
      'type': ItemType.placeable,
      'description': 'この星を構成している何か',
      'spritePath': 'stone.png',
      'value': 10,
      'size': [25.0, 25.0],
    },
    '採掘の気力': {
      'type': ItemType.custom,
      'description': '採掘ポイントを5増やします',
      'actionType': BagWindowActionType.consume,
      'spritePath': 'shovel.png',
      'value': 120,
      'effect': 'updateMiningPoints5',
      'size': [25.0, 25.0],
    },
  };

  /// 通貨を生成
  static CurrencyItem createCurrency(Vector2 position, {int value = 10}) {
    final itemData = _itemDefinitions['通貨']!;
    final name = itemData['name'] as String;
    final description = itemData['description'] as String;
    final spritePath = itemData['spritePath'] as String;
    final currencyValue = itemData['value'] as int;
    final size = Vector2(
      (itemData['size'] as List<dynamic>)[0].toDouble(),
      (itemData['size'] as List<dynamic>)[1].toDouble(),
    );

    return CurrencyItem(
      position: position,
      currencyValue: value, // 引数で渡されたvalueを使用
      name: name,
      description: description,
      value: currencyValue, // _itemDefinitionsから取得したvalueを使用
      spritePath: spritePath,
      size: size,
    );
  }

  /// 宝石を生成
  static GemItem createGem(Vector2 position, {int value = 50}) {
    final itemData = _itemDefinitions['宝石']!;
    final name = itemData['name'] as String;
    final description = itemData['description'] as String;
    final spritePath = itemData['spritePath'] as String;
    final gemValue = itemData['value'] as int;
    final size = Vector2(
      (itemData['size'] as List<dynamic>)[0].toDouble(),
      (itemData['size'] as List<dynamic>)[1].toDouble(),
    );

    return GemItem(
      position: position,
      name: name,
      description: description,
      value: gemValue,
      spritePath: spritePath,
      size: size,
    );
  }

  /// 回復アイテムを生成
  static HealthItem createHealthItem(
    Vector2 position, {
    double healAmount = 100.0,
  }) {
    final itemData = _itemDefinitions['栄養剤']!;
    final name = itemData['name'] as String;
    final description = itemData['description'] as String;
    final spritePath = itemData['spritePath'] as String;
    final value = itemData['value'] as int;
    final size = Vector2(
      (itemData['size'] as List<dynamic>)[0].toDouble(),
      (itemData['size'] as List<dynamic>)[1].toDouble(),
    );

    return HealthItem(
      position: position,
      healAmount: healAmount,
      name: name,
      description: description,
      value: value,
      spritePath: spritePath,
      size: size,
    );
  }

  /// パワーアップアイテムを生成
  static PowerUpItem createPowerUpItem(
    Vector2 position, {
    required Function(Player) powerUpEffect,
  }) {
    final itemData = _itemDefinitions['レッド・ブリ']!;
    final name = itemData['name'] as String;
    final description = itemData['description'] as String;
    final spritePath = itemData['spritePath'] as String;
    final value = itemData['value'] as int;
    final size = Vector2(
      (itemData['size'] as List<dynamic>)[0].toDouble(),
      (itemData['size'] as List<dynamic>)[1].toDouble(),
    );

    return PowerUpItem(
      position: position,
      powerUpEffect: powerUpEffect,
      name: name,
      description: description,
      value: value,
      spritePath: spritePath,
      size: size,
    );
  }

  /// 道具アイテムを生成
  static ToolItem createToolItem({
    required Vector2 position,
    required String name,
    required String description,
    required int value,
    required String spritePath,
    required Vector2 size,
  }) {
    return ToolItem(
      position: position,
      name: name,
      description: description,
      value: value,
      spritePath: spritePath,
      size: size,
    );
  }

  /// 配置アイテムを生成
  static PlaceableItem createPlaceableItem({
    required Vector2 position,
    required String name,
    required String description,
    required int value,
    required String spritePath,
    required Vector2 size,
  }) {
    return PlaceableItem(
      position: position,
      name: name,
      description: description,
      value: value,
      spritePath: spritePath,
      size: size,
    );
  }

  /// カスタムアイテムを生成
  static CustomItem createCustomItem({
    required Vector2 position,
    required Function(Player) effect,
    required String spritePath,
    required String name,
    required String description,
    required int value,
    Vector2? size,
  }) {
    return CustomItem(
      position: position,
      customEffect: effect,
      spritePath: spritePath,
      name: name,
      description: description,
      value: value,
      size: size,
    );
  }

  /// ランダムなアイテムを生成 (test)
  /* static Item createRandomItem(Vector2 position) {
    switch (_random.nextInt(4)) {
      case 0:
        return createCurrency(position, value: 10 + _random.nextInt(20));
      case 1:
        return createGem(position, value: 30 + _random.nextInt(40));
      case 2:
        return createHealthItem(
          position,
          healAmount: 50.0 + _random.nextDouble() * 100.0,
        );
      case 3:
        return createPowerUpItem(
          position,
          stressReduction: 10.0 + _random.nextDouble() * 20.0,
        );
      default:
        return createCurrency(position);
    }
  } */

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
          healAmount: itemData['healAmount'] as double,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
        );
      case ItemType.stress:
        return StressItem(
          position: position,
          stressReduction: itemData['stressReduction'] as double,
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
        return ToolItem(
          position: position,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
        );
      case ItemType.placeable:
        return PlaceableItem(
          position: position,
          name: name,
          description: description,
          value: value,
          spritePath: spritePath,
          size: size,
        );
      case ItemType.custom:
        final effectName = itemData['effect'] as String?;
        final resolvedEffect = CustomItemEffectResolver.resolve(effectName);
        final customActionType =
            (itemData['actionType'] as BagWindowActionType?) ?? BagWindowActionType.consume;
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
    }
  }
}
