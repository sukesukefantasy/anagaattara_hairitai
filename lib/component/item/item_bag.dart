import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'item.dart';
import '../../system/storage/game_runtime_state.dart';
import '../player.dart';

/// 収集したアイテムを管理するクラス
class ItemBag extends ChangeNotifier {
  /// アイテムの名前ごとの数を保持
  final Map<String, int> _itemCounts = {};

  /// アイテムのインスタンス（詳細情報用、各アイテムタイプにつき1つ）
  final Map<String, Item> _itemDetails = {};

  final GameRuntimeState _gameRuntimeState;

  ItemBag({required GameRuntimeState gameRuntimeState})
      : _gameRuntimeState = gameRuntimeState {
    _loadFromSaveData(); // 初期化時にセーブデータからロード
  }

  /// 全ての収集済みアイテムの情報を取得
  Map<String, Item> get items => _itemDetails; // UIが詳細にアクセスできるようにゲッターを提供

  /// 特定のアイテムの数を取得
  int getItemCount(String itemName) {
    return _itemCounts[itemName] ?? 0;
  }

  /// セーブデータからアイテムバッグをロードする
  void _loadFromSaveData() {
    _itemCounts.clear();
    _itemDetails.clear();
    _gameRuntimeState.itemCounts.forEach((name, count) {
      _itemCounts[name] = count;
      // ItemFactoryを使用してアイテムを再構築
      final item = ItemFactory.createItemByName(name, Vector2.zero()); // positionはダミー
      if (item != null) {
        _itemDetails[name] = item;
      }
    });
    notifyListeners();
  }

  /// アイテムを取得し、バッグに追加するメソッド
  void addItem(Item item) {
    debugPrint('ItemBag.addItem: ${item.name} を追加します。現在のカウント: ${_itemCounts[item.name] ?? 0}');
    // 名前をキーとしてカウントを増やす
    _itemCounts.update(
      item.name,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    // 初めて取得するアイテムの場合、詳細情報を保存
    if (!_itemDetails.containsKey(item.name)) {
      _itemDetails[item.name] = item; // 実際のアイテムインスタンスを保存
      debugPrint('ItemBag.addItem: ${item.name} の詳細を保存しました。');
    }
    debugPrint('ItemBag.addItem: ${item.name} 追加後、現在のカウント: ${_itemCounts[item.name]}');
    _saveItemBagData(); // データ変更後に保存
    notifyListeners(); // UIの更新を通知
  }

  /// アイテムを削除するメソッド（将来的な拡張用）
  void removeItem(String itemName, {int count = 1}) {
    debugPrint('ItemBag.removeItem: $itemName を $count 個削除します。現在のカウント: ${_itemCounts[itemName] ?? 0}');
    if (!_itemCounts.containsKey(itemName)) {
      debugPrint('ItemBag.removeItem: $itemName はインベントリにありません。');
      return;
    }

    _itemCounts.update(itemName, (value) => value - count);
    if (_itemCounts[itemName]! <= 0) {
      debugPrint('ItemBag.removeItem: $itemName のカウントが0以下になったため、インベントリから削除します。');
      _itemCounts.remove(itemName);
      _itemDetails.remove(itemName);
    }
    debugPrint('ItemBag.removeItem: $itemName 削除後、現在のカウント: ${_itemCounts[itemName] ?? 0}');
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