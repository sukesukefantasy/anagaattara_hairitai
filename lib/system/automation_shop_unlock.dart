import 'automation_shop_grade.dart';
import 'automation_tool_kind.dart';
import 'automation_tool_state.dart';
import 'storage/game_runtime_state.dart';

/// 共通タブ・C-2 契約の段階解禁。
extension AutomationShopUnlock on GameRuntimeState {
  static const double c2MinFarmCostWillpower = 25.0;
  static const int c2MinFarmResidueCostTotal = 100;

  bool get shouldShowAutomationContractC2Entry =>
      automationShopGradeCommon >= 5 || automationShopGradeUpkeep >= 2;

  bool get isCommon5Unlocked {
    if (automationShopGradeCommon >= 5) return true;
    if (automationShopGradeHarvest < 2) return false;
    if (automationShopGradeUpkeep < 2) return false;
    if (automationShopGradeWard < 2) return false;
    if (automationShopGradeCommon < 4) return false;
    if (automationUpgradeStageTier < 3) return false;
    return true;
  }

  String? common5LockHint() {
    if (automationShopGradeCommon >= 5) return null;
    if (isCommon5Unlocked) return null;
    if (automationShopGradeCommon < 4) {
      return '先に共通 段階4（燃費改善）を解放してください';
    }
    if (automationShopGradeHarvest < 2) {
      return '収穫 段階2 を解放してください';
    }
    if (automationShopGradeUpkeep < 2) {
      return '整備 段階2 を解放してください';
    }
    if (automationShopGradeWard < 2) {
      return '防衛 段階2 を解放してください';
    }
    if (automationUpgradeStageTier < 3) {
      return '調査ステージ outdoor_3 相当まで進めてください';
    }
    return '終盤条件を満たしていません';
  }

  bool get isAutomationContractC2Unlocked {
    if (automationContractC2) return true;
    if (automationShopGradeHarvest < 3) return false;
    if (automationShopGradeUpkeep < 2) return false;
    if (automationShopGradeWard < 1) return false;
    if (hunterToolsGranted.length < AutomationToolKind.values.length) {
      return false;
    }
    for (final k in AutomationToolKind.values) {
      if (!hasToolPlaced(k)) return false;
    }
    if (automationKitStage < 3) return false;
    if (automationUpgradeStageTier < 4) return false;
    if (lastAlertHunterSpawnTier < 2) return false;
    final residueTotal =
        farmCostLife + farmCostHistory + farmCostInorganic;
    if (farmCostWillpower < c2MinFarmCostWillpower &&
        residueTotal < c2MinFarmResidueCostTotal) {
      return false;
    }
    return true;
  }

  /// 未解禁時の次の一手（1件のみ）。
  String? automationContractC2LockHint() {
    if (automationContractC2) return null;
    if (isAutomationContractC2Unlocked) return null;
    if (automationShopGradeHarvest < 3) {
      return '収穫 段階3（残滓フィルタ）を解放してください';
    }
    if (automationShopGradeUpkeep < 2) {
      return '整備 段階2（自動サイクル）を解放してください';
    }
    if (automationShopGradeWard < 1) {
      return '防衛 段階1（近接）を先に開放してください';
    }
    if (hunterToolsGranted.length < AutomationToolKind.values.length) {
      return '警戒狩人から3種の装置をすべて取得してください';
    }
    for (final k in AutomationToolKind.values) {
      if (!hasToolPlaced(k)) {
        return '${k.displayLabel}を設置してください';
      }
    }
    if (automationKitStage < 3) {
      return '整備ツールの稼働段階を上げてください（自動サイクル運用）';
    }
    if (automationUpgradeStageTier < 4) {
      return '調査ステージ outdoor_4 相当まで進めてください';
    }
    if (lastAlertHunterSpawnTier < 2) {
      return '警戒ティア2以上の狩人と戦ってください';
    }
    final residueTotal =
        farmCostLife + farmCostHistory + farmCostInorganic;
    if (farmCostWillpower < c2MinFarmCostWillpower &&
        residueTotal < c2MinFarmResidueCostTotal) {
      return '自動化への支払いが足りません（残滓合計${c2MinFarmResidueCostTotal}または意志力${c2MinFarmCostWillpower.toStringAsFixed(0)}）';
    }
    return '前提条件を満たしていません';
  }
}
