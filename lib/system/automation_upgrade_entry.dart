import 'automation_ability_catalog.dart';
import 'automation_shop_grade.dart';
import 'automation_tool_kind.dart';
import 'farm_resource_cost.dart';
import 'farm_role_profile.dart';
import 'storage/game_runtime_state.dart';

/// 装置強化1行の表示状態（ショップ [AutomationShopEntryStatus] と同系）。
enum AutomationUpgradeEntryStatus {
  /// ショップ未開放
  locked,

  /// 強化可能・コスト充足
  available,

  /// 強化可能だがコスト不足（タップで理由表示）
  insufficient,

  /// 現在の調査ステージ上限（次ステージで cap 上昇）
  stageCap,

  /// 絶対最大レベル
  maxed,
}

class AutomationUpgradeEntry {
  const AutomationUpgradeEntry({
    required this.upgradeId,
    required this.title,
    required this.costLabel,
    required this.cost,
    required this.status,
    required this.currentLevel,
    required this.effectiveMaxLevel,
    required this.absoluteMaxLevel,
    this.statusDetail,
    this.effectDescription,
  });

  final String upgradeId;
  final String title;
  final String costLabel;
  final FarmResourceCost cost;
  final AutomationUpgradeEntryStatus status;
  final int currentLevel;
  final int effectiveMaxLevel;
  final int absoluteMaxLevel;
  final String? statusDetail;
  final String? effectDescription;

  String get statusLabel => switch (status) {
        AutomationUpgradeEntryStatus.locked => '未開放',
        AutomationUpgradeEntryStatus.available => '強化可',
        AutomationUpgradeEntryStatus.insufficient => '不足',
        AutomationUpgradeEntryStatus.stageCap => '段階上限',
        AutomationUpgradeEntryStatus.maxed => 'MAX',
      };

  bool get canTapUpgrade =>
      status == AutomationUpgradeEntryStatus.available ||
      status == AutomationUpgradeEntryStatus.insufficient;

  bool get canTapOpenShop => status == AutomationUpgradeEntryStatus.locked;

  bool get canTapLockedHint => status == AutomationUpgradeEntryStatus.locked;
}

List<AutomationUpgradeEntry> buildAutomationUpgradeEntries(
  GameRuntimeState state,
  AutomationToolKind kind,
) {
  return state
      .upgradeSpecsForKind(kind)
      .map((spec) => _entryForSpec(state, spec))
      .toList();
}

AutomationUpgradeEntry _entryForSpec(
  GameRuntimeState state,
  AutomationUpgradeSpec spec,
) {
  final tier = state.automationUpgradeStageTier;
  final cap = state.automationUpgradeEffectiveMaxLevel(spec);
  final absMax = spec.maxLevel;
  final lv = state.automationUpgradeLevel(spec.id);
  final unlocked = state.isAutomationUnlocked(spec.requiredUnlockId);
  final shopTab = state.shopTabForToolKind(spec.kind);

  final lifeCost = state.farmDiscountedCostForTab(spec.costLife, shopTab);
  final histCost = state.farmDiscountedCostForTab(spec.costHistory, shopTab);
  final inoCost = state.farmDiscountedCostForTab(spec.costInorganic, shopTab);
  final curCost = state.farmDiscountedCostForTab(spec.costCurrency, shopTab);
  final willCost = spec.costWillpower > 0
      ? spec.costWillpower / state.shopTabMultiplierFor(shopTab)
      : 0.0;

  final costLabel = _formatCostLabel(
    state,
    shopTab,
    life: lifeCost,
    history: histCost,
    inorganic: inoCost,
    currency: curCost,
    willpower: willCost,
  );
  final cost = FarmResourceCost(
    life: lifeCost,
    history: histCost,
    inorganic: inoCost,
    currency: curCost,
    willpower: willCost,
    affinityAligned: state.isShopTabAligned(shopTab),
  );

  if (!unlocked) {
    return AutomationUpgradeEntry(
      upgradeId: spec.id,
      title: spec.title,
      costLabel: costLabel,
      cost: cost,
      status: AutomationUpgradeEntryStatus.locked,
      currentLevel: lv,
      effectiveMaxLevel: cap,
      absoluteMaxLevel: absMax,
      effectDescription: spec.effectDescription,
      statusDetail: 'ショップで能力を開放',
    );
  }

  if (lv >= absMax) {
    return AutomationUpgradeEntry(
      upgradeId: spec.id,
      title: spec.title,
      costLabel: costLabel,
      cost: cost,
      status: AutomationUpgradeEntryStatus.maxed,
      currentLevel: lv,
      effectiveMaxLevel: cap,
      absoluteMaxLevel: absMax,
      effectDescription: spec.effectDescription,
      statusDetail: '絶対最大 Lv$absMax',
    );
  }

  if (lv >= cap) {
    return AutomationUpgradeEntry(
      upgradeId: spec.id,
      title: spec.title,
      costLabel: costLabel,
      cost: cost,
      status: AutomationUpgradeEntryStatus.stageCap,
      currentLevel: lv,
      effectiveMaxLevel: cap,
      absoluteMaxLevel: absMax,
      effectDescription: spec.effectDescription,
      statusDetail: _nextStageCapHint(state, tier, cap),
    );
  }

  final canPay = state.cargoLifeCount >= lifeCost &&
      state.cargoHistoryCount >= histCost &&
      state.cargoInorganicCount >= inoCost &&
      state.currency >= curCost &&
      state.currentWillpower >= willCost;

  return AutomationUpgradeEntry(
    upgradeId: spec.id,
    title: spec.title,
    costLabel: costLabel,
    cost: cost,
    status: canPay
        ? AutomationUpgradeEntryStatus.available
        : AutomationUpgradeEntryStatus.insufficient,
    currentLevel: lv,
    effectiveMaxLevel: cap,
    absoluteMaxLevel: absMax,
    effectDescription: spec.effectDescription,
    statusDetail: canPay ? 'Lv$lv → ${lv + 1}' : 'コストが足りない',
  );
}

String _nextStageCapHint(GameRuntimeState state, int tier, int cap) {
  final nextCap = state.automationUpgradeLevelCapForStageTier(tier + 1);
  if (nextCap <= cap) {
    return 'Lv$cap まで（調査ステージ $tier）';
  }
  return 'Lv$cap まで — 次ステージで Lv$nextCap まで';
}

String _formatCostLabel(
  GameRuntimeState state,
  AutomationShopTab tab, {
  required int life,
  required int history,
  required int inorganic,
  required int currency,
  required double willpower,
}) {
  final parts = <String>[];
  if (life > 0) parts.add('生命$life');
  if (history > 0) parts.add('歴史$history');
  if (inorganic > 0) parts.add('無機$inorganic');
  if (currency > 0) parts.add('通貨$currency');
  if (willpower > 0) parts.add('意志力${willpower.toStringAsFixed(1)}');
  if (parts.isEmpty) return 'コストなし';
  final joined = parts.join('・');
  if (state.isShopTabAligned(tab)) {
    return '$joined（主軸お得）';
  }
  return joined;
}
