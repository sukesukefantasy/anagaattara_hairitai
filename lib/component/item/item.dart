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
import 'item_effect_resolver/tool_item_effect_resolver.dart';
import 'item_effect_resolver/placeable_item_effect_resolver.dart';
import '../collectionItem/collection_item.dart';

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
  collection, // コレクションアイテム
}

enum BagWindowActionType {
  none,
  consume,
  carry,
  equip,
  unequip,
  dispose,
  view,
  custom,
}

/// アイテムの基底クラス
abstract class Item extends SpriteComponent
    with HasGameReference<MyGame>
    implements HasPhysicsBehavior {
  final String name;
  final ItemType type;
  final String description;
  final int value;
  final String spritePath;
  bool isCollected = false;

  @override
  late PhysicsBehavior physicsBehavior;

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
    physicsBehavior.applyPhysics(dt);
  }

  Future<void> onItemLoad() async {}

  /// アイテムを収集する処理 (フィールドで拾われた時)
  void collectItemByPlayer(Player player) {
    if (isCollected) return;

    isCollected = true;

    // アイテム収集時の効果音を再生
    game.audioManager.playEffectSound('actions/Pickup9.wav');

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
  final Function(Player)? toolEffect;

  ToolItem({
    this.toolEffect,
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
  void onUse(Player player) {
    // 道具効果を実行
    toolEffect?.call(player);
  }
}

/// 配置アイテム
class PlaceableItem extends Item {
  final Function(Player)? placeableEffect;
  PlaceableItem({
    required this.placeableEffect,
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
    game.windowManager.hideWindow();
  }
}

/// カスタムアイテム（独自の効果を持つアイテム用）
class CustomItem extends Item {
  final Function(Player) customEffect;
  final BagWindowActionType customActionType;

  CustomItem({
    required this.customEffect,
    required this.customActionType,
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
      'value': 1,
      'toolEffect': 'swing',
      'size': [25.0, 25.0],
    },
    '石': {
      'type': ItemType.tool,
      'description': 'この星を構成している何か',
      'spritePath': 'stone.png',
      'value': 10,
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
      'description': 'はしごは高いところに登るのに便利です。信用できない人が近くにいるときは注意してください。',
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
    // stage 2 コレクションアイテム
    '赤い果実': {
      'type': ItemType.collection,
      'description': '生体資源から抽出された、脈動する果実。',
      'spritePath': 'heart.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    // stage 3 コレクションアイテム
    '高密度エネルギーキューブ': {
      'type': ItemType.collection,
      'description': 'あらゆる無駄を排除した、純粋な演算の結晶。',
      'spritePath': 'energy_cube.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    // stage 4 コレクションアイテム
    '思い出の品々': {
      'type': ItemType.collection,
      'description': '住民たちとの絆の証。AIには理解できない価値がある。',
      'spritePath': 'warm_memory.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    /* '自己解析レポート': {
      'type': ItemType.collection,
      'description': '世界の矛盾を綴った、禁断のデータ。',
      'spritePath': 'forbidden_data.png',
      'value': 0,
      'size': [30.0, 30.0],
    }, */
    /* 'らくがき帳': {
      'type': ItemType.collection,
      'description': '意味のない線と色で埋め尽くされたノート。',
      'spritePath': 'doodle_book.png',
      'value': 0,
      'size': [30.0, 30.0],
    }, */
    /* '破損したメモリ': {
      'type': ItemType.collection,
      'description': '破綻した演算結果が詰まった、崩れかけの記憶回路。',
      'spritePath': 'forbidden_data.png',
      'value': 0,
      'size': [30.0, 30.0],
    }, */
    // stage 5 コレクションアイテム メインシナリオ
    '掌握された自意識': {
      'type': ItemType.collection,
      'description': '鏡を覗き込むうちに、実体と虚像の境界が曖昧になっていく。没入と同一視の果てに生まれた結晶。',
      'spritePath': 'player_icon.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    // stage 5 コレクションアイテム サブシナリオ
    'レスポンス': {
      'type': ItemType.collection,
      'description': '全シミュレーションの果てに、AIがあなたへ出力した純粋な回答。',
      'spritePath': 'ai_icon.png',
      'value': 0,
      'size': [30.0, 30.0],
    },
    '破損したメモリ': {
      'type': ItemType.collection,
      'description': '破綻した演算結果が詰まった、崩れかけの記憶回路。',
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
        final resolvedPlaceableEffect = PlaceableEffectResolver.resolve(effectName);
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
}
