import 'package:flame/components.dart';

import '../component/item/item.dart';
import '../component/item/item_bag.dart';
import 'storage/game_runtime_state.dart';

/// §5 自動化ショップ — 数値は実装側TBDの範囲で [GameRuntimeState] を更新する。
extension AutomationShopCatalog on GameRuntimeState {
  String? tryPurchaseShopTierA1() {
    if (automationShopTierA >= 1) return null;
    if (cargoLifeCount < 40) {
      return '生命カーゴが不足しています（必要: 40）';
    }
    cargoLifeCount = GameRuntimeState.clampCargoKindCount(cargoLifeCount - 40);
    automationShopTierA = 1;
    codexIncrementAutomationOps();
    saveGame();
    notifyRuntimeChanged();
    return null;
  }

  String? tryPurchaseShopTierA2() {
    if (automationShopTierA < 1) return '先に A-1 を解放してください';
    if (automationShopTierA >= 2) return null;
    if (cargoLifeCount < 25 || cargoHistoryCount < 12) {
      return '残滓が不足しています（生命25・歴史12）';
    }
    cargoLifeCount = GameRuntimeState.clampCargoKindCount(cargoLifeCount - 25);
    cargoHistoryCount = GameRuntimeState.clampCargoKindCount(cargoHistoryCount - 12);
    automationShopTierA = 2;
    saveGame();
    notifyRuntimeChanged();
    return null;
  }

  String? tryPurchaseShopTierA3() {
    if (automationShopTierA < 2) return '先に A-2 を解放してください';
    if (automationShopTierA >= 3) return null;
    if (cargoInorganicCount < 30) {
      return '無機カーゴが不足しています（必要: 30）';
    }
    cargoInorganicCount =
        GameRuntimeState.clampCargoKindCount(cargoInorganicCount - 30);
    automationShopTierA = 3;
    saveGame();
    notifyRuntimeChanged();
    return null;
  }

  String? tryPurchaseShopTierB1() {
    if (automationShopTierB >= 1) return null;
    if (currentWillpower < 2.5) {
      return '意志力が足りません（2.5 支払い）';
    }
    currentWillpower -= 2.5;
    clampCurrentWillpowerToCapacity();
    automationShopTierB = 1;
    saveGame();
    notifyRuntimeChanged();
    return null;
  }

  /// B-2: 通貨＋自動意志力支払い基盤（§5 暫定：通貨コストはプレイバランス用）。
  String? tryPurchaseShopTierB2() {
    if (automationShopTierB < 1) return '先に B-1 を解放してください';
    if (automationShopTierB >= 2) return null;
    if (currency < 60) return '通貨が不足しています（必要: 60）';
    currency -= 60;
    automationShopTierB = 2;
    automationShopWillpowerAutoPay = true;
    saveGame();
    notifyRuntimeChanged();
    return null;
  }

  /// C-1: 強力シールドとして最大核を一時預け（=max を1単位削る）。
  String? tryPurchaseShopTierC1Shield() {
    if (automationShopTierC >= 1) return null;
    if (maxWillCoreValue <= GameRuntimeState.willCoreUnit * 1.25) {
      return '意志の核の余裕がありません（C-1 には余剰コアが必要）';
    }
    maxWillCoreValue -= GameRuntimeState.willCoreUnit;
    clampCurrentWillpowerToCapacity();
    automationShopTierC = 1;
    saveGame();
    notifyRuntimeChanged();
    return null;
  }

  /// B-3 の一部: 報酬として火炎瓶（ドキュメントの数は10だが開発中は少なめ）。
  String? tryPurchaseShopTierB3Preview(ItemBag bag) {
    if (automationShopTierB < 2) return '先に B-2 を解放してください';
    if (automationShopTierB >= 3) return null;
    if (currentWillpower < 3.5) return '意志力が足りません';
    currentWillpower -= 3.5;
    clampCurrentWillpowerToCapacity();
    automationShopTierB = 3;
    for (var i = 0; i < 3; i++) {
      final it = ItemFactory.createItemByName('火炎瓶', Vector2.zero());
      if (it != null) {
        bag.addItem(it);
      }
    }
    saveGame();
    notifyRuntimeChanged();
    return null;
  }

  /// C-2: 意志の核を差し込み Nourishment 確定（キットと同効）。
  String? tryPurchaseShopTierC2Contract(ItemBag bag) {
    if (automationContractC2) return 'すでに C-2 契約済みです';
    if (maxWillCoreValue <= GameRuntimeState.willCoreUnit + 1e-9) {
      return '意志の核が足りません（余剰コアが必要）';
    }
    maxWillCoreValue -= GameRuntimeState.willCoreUnit;
    clampCurrentWillpowerToCapacity();
    registerAutomationContractC2();
    final it = ItemFactory.createItemByName('火炎放射器', Vector2.zero());
    if (it != null) bag.addItem(it);
    automationKitStage =
        automationKitStage < 4 ? 4 : automationKitStage;
    saveGame();
    notifyRuntimeChanged();
    return null;
  }

  /// D-1: 母星人間性を代償に核と意志力（§10 トーン）。
  String? tryPurchaseShopTierD1() {
    if (automationShopTierD >= 1) return null;
    if (homePlanetHumanity < 18.0) {
      return '母星人間性が足りません（§14 正解なし — 要: 18）';
    }
    homePlanetHumanity = (homePlanetHumanity - 18.0).clamp(0.0, 100.0);
    maxWillCoreValue += GameRuntimeState.willCoreUnit;
    currentWillpower += GameRuntimeState.willCoreUnit * 0.5;
    clampCurrentWillpowerToCapacity();
    automationShopTierD = 1;
    saveGame();
    notifyRuntimeChanged();
    return null;
  }

  /// D-2: さらに母星の代償（1時間ルールは省略し一回購入で表現）。
  String? tryPurchaseShopTierD2() {
    if (automationShopTierD < 1) return '先に D-1 を解放してください';
    if (automationShopTierD >= 2) return null;
    if (homePlanetHumanity < 12.0) {
      return '母星人間性が足りません（要: 12）';
    }
    homePlanetHumanity = (homePlanetHumanity - 12.0).clamp(0.0, 100.0);
    maxWillCoreValue += GameRuntimeState.willCoreUnit;
    currentWillpower += GameRuntimeState.willCoreUnit;
    clampCurrentWillpowerToCapacity();
    automationShopTierD = 2;
    saveGame();
    notifyRuntimeChanged();
    return null;
  }

  /// D-3: 母星代償の極致＋象徴アイテム。
  String? tryPurchaseShopTierD3(ItemBag bag) {
    if (automationShopTierD < 2) return '先に D-2 を解放してください';
    if (automationShopTierD >= 3) return null;
    if (homePlanetHumanity < 22.0) return '母星人間性が足りません（要: 22）';
    homePlanetHumanity = (homePlanetHumanity - 22.0).clamp(0.0, 100.0);
    automationShopTierD = 3;
    final it = ItemFactory.createItemByName('高出力電源', Vector2.zero());
    if (it != null) bag.addItem(it);
    saveGame();
    notifyRuntimeChanged();
    return null;
  }
}
