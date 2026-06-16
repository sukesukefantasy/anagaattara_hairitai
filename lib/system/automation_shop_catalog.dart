import 'package:flame/components.dart';

import '../component/item/item.dart';
import '../component/item/item_bag.dart';
import 'automation_ability_catalog.dart';
import 'automation_shop_grade.dart';
import 'automation_shop_unlock.dart';
import 'farm_role_profile.dart';
import 'storage/game_runtime_state.dart';

/// 自動化ショップ — 装置別 grade 購入。
extension AutomationShopCatalog on GameRuntimeState {
  String? tryPurchaseShopEntry(String id, ItemBag bag) {
    final spec = shopSpecById(id);
    if (spec == null) return '不明な項目です';

    if (shopGrade(spec.tab) >= spec.gradeLevel) return null;

    final prereq = shopGradePrerequisiteHint(spec);
    if (prereq != null) return prereq;

    if (spec.id == 'common_5' && !isCommon5Unlocked) {
      return common5LockHint() ?? '終盤条件を満たしていません';
    }

    if (spec.id == 'common_6') {
      return tryPurchaseCommon6Contract(bag);
    }

    if (spec.id == 'ward_1') {
      if (maxWillCoreValue <= GameRuntimeState.willCoreUnit * 1.25) {
        return '意志の核の余裕がありません（余剰コアが必要）';
      }
    }

    final tab = spec.tab;
    final lifeCost =
        spec.costLife > 0 ? farmDiscountedCostForTab(spec.costLife, tab) : 0;
    final histCost = spec.costHistory > 0
        ? farmDiscountedCostForTab(spec.costHistory, tab)
        : 0;
    final inoCost = spec.costInorganic > 0
        ? farmDiscountedCostForTab(spec.costInorganic, tab)
        : 0;
    final currencyCost = spec.costCurrency > 0
        ? farmDiscountedCostForTab(spec.costCurrency, tab)
        : 0;
    final willPay = spec.costWillpower > 0
        ? spec.costWillpower / shopTabMultiplierFor(tab)
        : 0.0;

    if (cargoLifeCount < lifeCost) {
      return '生命カーゴが不足しています（必要: $lifeCost）';
    }
    if (cargoHistoryCount < histCost) {
      return '歴史カーゴが不足しています（必要: $histCost）';
    }
    if (cargoInorganicCount < inoCost) {
      return '無機カーゴが不足しています（必要: $inoCost）';
    }
    if (currency < currencyCost) {
      return '通貨が不足しています（必要: $currencyCost）';
    }
    if (willPay > 0 && currentWillpower < willPay) {
      return '意志力が足りません（${willPay.toStringAsFixed(1)} 支払い）';
    }
    if (spec.costWillCore > 0 &&
        maxWillCoreValue <= GameRuntimeState.willCoreUnit * spec.costWillCore) {
      return '意志の核が不足しています';
    }

    if (lifeCost > 0) {
      cargoLifeCount =
          GameRuntimeState.clampResidueCount(cargoLifeCount - lifeCost);
    }
    if (histCost > 0) {
      cargoHistoryCount =
          GameRuntimeState.clampResidueCount(cargoHistoryCount - histCost);
    }
    if (inoCost > 0) {
      cargoInorganicCount =
          GameRuntimeState.clampResidueCount(cargoInorganicCount - inoCost);
    }
    if (currencyCost > 0) currency -= currencyCost;
    if (willPay > 0) {
      currentWillpower -= willPay;
      clampCurrentWillpowerToCapacity();
    }
    recordFarmCost(
      life: lifeCost,
      history: histCost,
      inorganic: inoCost,
      currency: currencyCost,
      willpower: willPay,
    );

    if (spec.id == 'ward_1') {
      maxWillCoreValue -= GameRuntimeState.willCoreUnit;
      clampCurrentWillpowerToCapacity();
      recordFarmCost(willpower: GameRuntimeState.willCoreUnit);
    }

    setShopGrade(spec.tab, spec.gradeLevel);
    syncUnlocksFromShopGrades();

    switch (spec.id) {
      case 'common_4':
        automationFuelEfficiencyTier = 1;
      case 'common_5':
        automationShopWillpowerAutoPay = true;
      case 'upkeep_2':
        if (automationKitStage < 2) automationKitStage = 2;
        for (var i = 0; i < 3; i++) {
          final it = ItemFactory.createItemByName('火炎瓶', Vector2.zero());
          if (it != null) bag.addItem(it);
        }
      default:
        break;
    }

    codexIncrementAutomationOps();
    saveGame();
    notifyRuntimeChanged();
    return null;
  }

  String? tryPurchaseCommon6Contract(ItemBag bag) {
    if (automationContractC2) return null;
    final spec = shopSpecById('common_6');
    if (spec == null) return '不明な項目です';
    final prereq = shopGradePrerequisiteHint(spec);
    if (prereq != null) return prereq;
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
    unlockAutomation(AutomationUnlockIds.upkeepManualCycle);
    saveGame();
    notifyRuntimeChanged();
    return null;
  }
}
