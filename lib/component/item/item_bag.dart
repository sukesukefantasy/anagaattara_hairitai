import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'item.dart';
import '../../main.dart' show MyGame;
import '../../system/item_pickup_feed.dart';
import '../../system/storage/game_runtime_state.dart';
import '../../UI/widgets/item_pickup_feed_overlay.dart';

/// 収集したアイテムを管理するクラス
class ItemBag extends ChangeNotifier {
  /// アイテムの名前ごとの数を保持
  final Map<String, int> _itemCounts = {};

  /// アイテムのインスタンス（詳細情報用、各アイテムタイプにつき1つ）
  final Map<String, Item> _itemDetails = {};

  final GameRuntimeState _gameRuntimeState;

  /// 入手ログ（HUD）用。
  final ItemPickupFeedController pickupFeed = ItemPickupFeedController();

  /// バッグ内 [Item] はワールドに乗らないため [HasGameReference.game] を明示設定する。
  MyGame? _boundGame;

  bool _suppressPickupFeed = false;

  ItemBag({required GameRuntimeState gameRuntimeState})
    : _gameRuntimeState = gameRuntimeState {
    _loadFromSaveData(); // 初期化時にセーブデータからロード
  }

  /// [MyGame.onLoad] など、ゲームインスタンスが有効になった直後に一度呼ぶ。
  void bindToGame(MyGame game) {
    _boundGame = game;
    _attachGameToAllDetails();
  }

  /// アイテムを自動使用すべきかどうかを判定する。
  /// 将来的に「財布」などのストック用アイテムがある場合は、ここで false を返すロジックを追加できる。
  bool _shouldAutoUse(Item item) {
    if (!item.autoUse) return false;
    // 例: if (item.type == ItemType.currency && hasWallet) return false;
    return true;
  }

  void _attachGameToAllDetails() {
    final g = _boundGame;
    if (g == null) return;
    for (final item in _itemDetails.values) {
      item.game = g;
    }
  }

  /// 全ての収集済みアイテムの情報を取得
  Map<String, Item> get items => _itemDetails; // UIが詳細にアクセスできるようにゲッターを提供

  /// 装備中のアイテム名を取得
  String? get equippedItemName => _gameRuntimeState.equippedItemName;

  /// 特定のアイテムの数を取得
  int getItemCount(String itemName) {
    return _itemCounts[itemName] ?? 0;
  }

  /// セーブデータからアイテムバッグをロードする
  void _loadFromSaveData() {
    _suppressPickupFeed = true;
    _itemCounts.clear();
    _itemDetails.clear();
    _gameRuntimeState.itemCounts.forEach((name, count) {
      _itemCounts[name] = count;
      // ItemFactoryを使用してアイテムを再構築
      final item = ItemFactory.createItemByName(
        name,
        Vector2.zero(),
      ); // positionはダミー
      if (item != null) {
        _itemDetails[name] = item;
      }
    });
    _attachGameToAllDetails();
    _suppressPickupFeed = false;
    notifyListeners();
  }

  /// アイテムを取得し、バッグに追加するメソッド
  void addItem(
    Item item, {
    bool silent = false,
    Offset? flyStartGlobal,
    Vector2? flyStartWorld,
  }) {
    if (_boundGame != null) {
      // サウンドを再生
      _boundGame!.audioManager.playEffectSound(
        'actions/Pickup9.wav',
        volume: 0.35,
      );
      item.game = _boundGame;
    }
    final isFirstAcquisition =
        !(_itemCounts[item.name] != null && _itemCounts[item.name]! > 0);

    // 自動使用の判定
    if (_shouldAutoUse(item)) {
      if (_boundGame != null) {
        item.onUse(_boundGame!.player);
        _boundGame!.gameRuntimeState.codexIncrementItemUsed(item.name);
      }
      
      // 自動使用された場合でも、取得ログは出す（必要なら）
      if (!silent && !_suppressPickupFeed) {
        pickupFeed.enqueue(
          ItemPickupFeedEvent(
            itemName: item.name,
            displayName: '${item.displayName} (自動使用)',
            spritePath: item.spritePath,
            stackCount: 1,
            isFirstAcquisition: isFirstAcquisition,
            borderColor: pickupFeedBorderForItemName(item.name),
            flyStartGlobal: flyStartGlobal,
            flyStartWorld: flyStartWorld,
          ),
        );
      }
      return; // バッグには追加しない
    }

    // 名前をキーとしてカウントを増やす
    _itemCounts.update(item.name, (value) => value + 1, ifAbsent: () => 1);

    // ガソリン缶を取得した際、燃料をフルにする（v8.5 アクション用）
    if (item.name == 'ガソリン缶') {
      _gameRuntimeState.gasolineCanFuel = GameRuntimeState.maxGasolineCanFuel;
    }

    // 詳細は定義からのプロトタイプを優先（ワールド拾得の LanternItem 等を正規化）
    final prototype = ItemFactory.createItemByName(item.name, Vector2.zero());
    if (prototype != null) {
      if (_boundGame != null) {
        prototype.game = _boundGame;
      }
      _itemDetails[item.name] = prototype;
    } else if (!_itemDetails.containsKey(item.name)) {
      _itemDetails[item.name] = item;
    }
    _saveItemBagData(); // データ変更後に保存
    notifyListeners(); // UIの更新を通知

    if (!silent && !_suppressPickupFeed) {
      final detail = _itemDetails[item.name] ?? item;
      pickupFeed.enqueue(
        ItemPickupFeedEvent(
          itemName: item.name,
          displayName: pickupFeedDisplayName(detail),
          spritePath: detail.spritePath,
          stackCount: _itemCounts[item.name] ?? 1,
          isFirstAcquisition: isFirstAcquisition,
          borderColor: pickupFeedBorderForItemName(item.name),
          flyStartGlobal: flyStartGlobal,
          flyStartWorld: flyStartWorld,
        ),
      );
    }
  }

  /// アイテムを削除するメソッド
  void removeItem(String itemName, {int count = 1}) {
    if (!_itemCounts.containsKey(itemName)) {
      return;
    }
    // count が 0 の場合は、所持数すべてを削除対象とする
    final removeAmount = count == 0 ? _itemCounts[itemName]! : count;
    _itemCounts.update(itemName, (value) => value - removeAmount);
    if (_itemCounts[itemName]! <= 0) {
      debugPrint(
        'ItemBag.removeItem: $itemName のカウントが0以下になったため、インベントリから削除します。',
      );
      _itemCounts.remove(itemName);
      _itemDetails.remove(itemName);

      // 削除したアイテムが装備中だった場合、装備を解除する
      if (equippedItemName == itemName) {
        unequipItem();
      }
    }
    _saveItemBagData();
    notifyListeners();
  }

  void equipItem(String itemName) {
    _gameRuntimeState.equippedItemName = itemName;
    _saveItemBagData();
    notifyListeners();
  }

  void unequipItem() {
    _gameRuntimeState.equippedItemName = null;
    _saveItemBagData();
    notifyListeners();
  }

  /// アイテムバッグの内容をクリアするメソッド
  void clear() {
    _itemCounts.clear();
    _itemDetails.clear();
    _saveItemBagData();
    notifyListeners();
  }

  /// アイテムバッグのデータをセーブデータに保存するプライベートメソッド
  void _saveItemBagData() {
    _gameRuntimeState.itemCounts = Map.from(_itemCounts);
    _gameRuntimeState.saveGame();
  }
}
