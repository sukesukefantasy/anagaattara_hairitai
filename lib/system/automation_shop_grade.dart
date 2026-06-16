import 'automation_ability_catalog.dart';
import 'automation_shop_unlock.dart';
import 'storage/game_runtime_state.dart';

/// 自動化ショップのタブ（装置3 + 共通）。
enum AutomationShopTab {
  harvest,
  upkeep,
  ward,
  common,
}

/// 1 項目の定義（購入で tab の grade が +1）。
class AutomationShopGradeSpec {
  const AutomationShopGradeSpec({
    required this.id,
    required this.tab,
    required this.gradeLevel,
    required this.title,
    this.costLife = 0,
    this.costHistory = 0,
    this.costInorganic = 0,
    this.costCurrency = 0,
    this.costWillpower = 0,
    this.costWillCore = 0.0,
    this.requiresBagReward = false,
    this.showWhen,
  });

  final String id;
  final AutomationShopTab tab;
  final int gradeLevel;
  final String title;
  final int costLife;
  final int costHistory;
  final int costInorganic;
  final int costCurrency;
  final double costWillpower;
  final double costWillCore;
  final bool requiresBagReward;

  /// null = 常に一覧に出す（未達は locked）。
  final bool Function(GameRuntimeState state)? showWhen;
}

const kAutomationShopGradeSpecs = <AutomationShopGradeSpec>[
  AutomationShopGradeSpec(
    id: 'harvest_1',
    tab: AutomationShopTab.harvest,
    gradeLevel: 1,
    title: '段階1 — ドロップ吸引',
    costLife: 40,
  ),
  AutomationShopGradeSpec(
    id: 'harvest_2',
    tab: AutomationShopTab.harvest,
    gradeLevel: 2,
    title: '段階2 — 自動吸引ルート',
    costLife: 25,
    costHistory: 12,
  ),
  AutomationShopGradeSpec(
    id: 'harvest_3',
    tab: AutomationShopTab.harvest,
    gradeLevel: 3,
    title: '段階3 — 残滓フィルタ強化',
    costInorganic: 30,
  ),
  AutomationShopGradeSpec(
    id: 'upkeep_1',
    tab: AutomationShopTab.upkeep,
    gradeLevel: 1,
    title: '段階1 — 装置回復系',
    costWillpower: 2.5,
  ),
  AutomationShopGradeSpec(
    id: 'upkeep_2',
    tab: AutomationShopTab.upkeep,
    gradeLevel: 2,
    title: '段階2 — 自動サイクル＋火炎瓶',
    costWillpower: 3.5,
    requiresBagReward: true,
  ),
  AutomationShopGradeSpec(
    id: 'ward_1',
    tab: AutomationShopTab.ward,
    gradeLevel: 1,
    title: '段階1 — 近接攻撃（核1消費）',
    costWillCore: 1.0,
  ),
  AutomationShopGradeSpec(
    id: 'ward_2',
    tab: AutomationShopTab.ward,
    gradeLevel: 2,
    title: '段階2 — 遠距離攻撃',
    costInorganic: 20,
  ),
  AutomationShopGradeSpec(
    id: 'ward_3',
    tab: AutomationShopTab.ward,
    gradeLevel: 3,
    title: '段階3 — 拘束デバフ',
    costHistory: 15,
  ),
  AutomationShopGradeSpec(
    id: 'common_1',
    tab: AutomationShopTab.common,
    gradeLevel: 1,
    title: '共通 — 生命馏分燃料',
    costLife: 20,
  ),
  AutomationShopGradeSpec(
    id: 'common_2',
    tab: AutomationShopTab.common,
    gradeLevel: 2,
    title: '共通 — 歴史胶质燃料',
    costHistory: 18,
  ),
  AutomationShopGradeSpec(
    id: 'common_3',
    tab: AutomationShopTab.common,
    gradeLevel: 3,
    title: '共通 — 無機基油燃料＋燃料中継',
    costInorganic: 22,
  ),
  AutomationShopGradeSpec(
    id: 'common_4',
    tab: AutomationShopTab.common,
    gradeLevel: 4,
    title: '共通 — 燃費改善 I',
    costInorganic: 35,
    costHistory: 10,
  ),
  AutomationShopGradeSpec(
    id: 'common_5',
    tab: AutomationShopTab.common,
    gradeLevel: 5,
    title: '共通 — 意志力自動補給契約',
    costWillpower: 4.0,
    costCurrency: 80,
    showWhen: _showCommon5Outline,
  ),
  AutomationShopGradeSpec(
    id: 'common_6',
    tab: AutomationShopTab.common,
    gradeLevel: 6,
    title: '共通 — C-2 契約（不可逆）',
    costWillCore: 1.0,
    showWhen: _showCommon6Outline,
  ),
];

bool _showCommon5Outline(GameRuntimeState state) =>
    state.automationShopGradeCommon >= 4 ||
    state.automationShopGradeUpkeep >= 2;

bool _showCommon6Outline(GameRuntimeState state) =>
    state.automationShopGradeCommon >= 5 ||
    state.automationContractC2;

AutomationShopGradeSpec? shopSpecById(String id) {
  for (final s in kAutomationShopGradeSpecs) {
    if (s.id == id) return s;
  }
  return null;
}

List<AutomationShopGradeSpec> shopSpecsForTab(AutomationShopTab tab) =>
    kAutomationShopGradeSpecs.where((s) => s.tab == tab).toList();

extension AutomationShopGrade on GameRuntimeState {
  int shopGrade(AutomationShopTab tab) => switch (tab) {
        AutomationShopTab.harvest => automationShopGradeHarvest,
        AutomationShopTab.upkeep => automationShopGradeUpkeep,
        AutomationShopTab.ward => automationShopGradeWard,
        AutomationShopTab.common => automationShopGradeCommon,
      };

  void setShopGrade(AutomationShopTab tab, int value) {
    final v = value.clamp(0, 99);
    switch (tab) {
      case AutomationShopTab.harvest:
        automationShopGradeHarvest = v;
      case AutomationShopTab.upkeep:
        automationShopGradeUpkeep = v;
      case AutomationShopTab.ward:
        automationShopGradeWard = v;
      case AutomationShopTab.common:
        automationShopGradeCommon = v;
    }
    syncLegacyShopTiersFromGrades();
  }

  /// 旧 tier フィールドを grade から再計算（外部参照の互換用）。
  void syncLegacyShopTiersFromGrades() {
    automationShopTierA = automationShopGradeHarvest.clamp(0, 3);
    automationShopTierB = automationShopGradeUpkeep.clamp(0, 3);
    automationShopTierC = automationShopGradeWard.clamp(0, 3);
    if (automationContractC2 && automationShopTierC < 2) {
      automationShopTierC = 2;
    }
  }

  void migrateLegacyShopTiersToGrades() {
    if (automationShopGradeHarvest > 0 ||
        automationShopGradeUpkeep > 0 ||
        automationShopGradeWard > 0 ||
        automationShopGradeCommon > 0) {
      syncUnlocksFromShopGrades();
      return;
    }

    automationShopGradeHarvest =
        automationShopTierA.clamp(0, 3);
    automationShopGradeUpkeep = switch (automationShopTierB) {
      >= 3 => 2,
      >= 1 => 1,
      _ => 0,
    };
    automationShopGradeWard = automationShopTierC >= 1
        ? (isAutomationUnlocked(AutomationUnlockIds.wardSlow)
            ? 3
            : isAutomationUnlocked(AutomationUnlockIds.wardRanged)
                ? 2
                : 1)
        : 0;

    var common = 0;
    if (automationShopTierA >= 2) common = common < 2 ? 2 : common;
    if (automationShopTierA >= 3 ||
        isAutomationUnlocked(AutomationUnlockIds.upkeepFuelRelay)) {
      common = common < 3 ? 3 : common;
    }
    if (automationFuelEfficiencyTier >= 1) common = common < 4 ? 4 : common;
    if (automationShopWillpowerAutoPay || automationShopTierB >= 2) {
      common = common < 5 ? 5 : common;
    }
    if (automationContractC2) common = common < 6 ? 6 : common;
    automationShopGradeCommon = common;

    syncUnlocksFromShopGrades();
    syncLegacyShopTiersFromGrades();
  }

  void syncUnlocksFromShopGrades() {
    if (automationShopGradeHarvest >= 1) {
      unlockAutomation(AutomationUnlockIds.harvestVacuum);
    }
    if (automationShopGradeHarvest >= 2) {
      unlockAutomation(AutomationUnlockIds.harvestStorage);
    }
    if (automationShopGradeHarvest >= 3) {
      unlockAutomation(AutomationUnlockIds.harvestFilterResidue);
    }
    if (automationShopGradeUpkeep >= 1) {
      unlockAutomation(AutomationUnlockIds.upkeepRepair);
    }
    if (automationShopGradeUpkeep >= 2) {
      unlockAutomation(AutomationUnlockIds.upkeepManualCycle);
    }
    if (automationShopGradeCommon >= 3) {
      unlockAutomation(AutomationUnlockIds.upkeepFuelRelay);
    }
    if (automationShopGradeWard >= 1) {
      unlockAutomation(AutomationUnlockIds.wardMelee);
    }
    if (automationShopGradeWard >= 2) {
      unlockAutomation(AutomationUnlockIds.wardRanged);
    }
    if (automationShopGradeWard >= 3) {
      unlockAutomation(AutomationUnlockIds.wardSlow);
    }
    if (automationShopGradeCommon >= 5) {
      automationShopWillpowerAutoPay = true;
    }
  }

  bool get canAutoRefuelFromWill =>
      automationShopWillpowerAutoPay && automationShopGradeCommon >= 5;

  bool isShopEntryVisible(AutomationShopGradeSpec spec) {
    if (spec.showWhen != null && !spec.showWhen!(this)) return false;
    return true;
  }

  String? shopGradePrerequisiteHint(AutomationShopGradeSpec spec) {
    if (shopGrade(spec.tab) >= spec.gradeLevel) return null;
    if (shopGrade(spec.tab) < spec.gradeLevel - 1) {
      final prev = spec.gradeLevel - 1;
      return '先に${spec.tab.label} 段階$prev を解放してください';
    }
    if (spec.id == 'common_5') return common5LockHint();
    if (spec.id == 'common_6') return automationContractC2LockHint();
    return null;
  }
}

extension AutomationShopTabX on AutomationShopTab {
  String get label => switch (this) {
        AutomationShopTab.harvest => '収穫',
        AutomationShopTab.upkeep => '整備',
        AutomationShopTab.ward => '防衛',
        AutomationShopTab.common => '共通',
      };
}
