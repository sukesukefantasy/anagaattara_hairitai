import 'farm_role_profile.dart';
import 'automation_shop_grade.dart';
import 'storage/game_runtime_state.dart';

/// ファーム／自動化 UI 用のコスト内訳（表示専用）。
class FarmResourceCost {
  const FarmResourceCost({
    this.life = 0,
    this.history = 0,
    this.inorganic = 0,
    this.currency = 0,
    this.willpower = 0,
    this.willCoreSpend = 0.0,
    this.humanitySpend = 0.0,
    this.affinityAligned = false,
    this.note,
  });

  final int life;
  final int history;
  final int inorganic;
  final int currency;
  final double willpower;
  final double willCoreSpend;
  final double humanitySpend;
  final bool affinityAligned;
  final String? note;

  bool get hasResidue => life > 0 || history > 0 || inorganic > 0;

  bool get hasStandardCost =>
      hasResidue ||
      currency > 0 ||
      willpower > 0 ||
      willCoreSpend > 0 ||
      humanitySpend > 0;

  FarmResourceCost withAffinityTab(
    AutomationShopTab tab,
    GameRuntimeState state,
  ) =>
      FarmResourceCost(
        life: life,
        history: history,
        inorganic: inorganic,
        currency: currency,
        willpower: willpower,
        willCoreSpend: willCoreSpend,
        humanitySpend: humanitySpend,
        affinityAligned: state.isShopTabAligned(tab),
        note: note,
      );
}

FarmResourceCost _tabCost(
  GameRuntimeState state,
  AutomationShopTab tab, {
  int lifeBase = 0,
  int historyBase = 0,
  int inorganicBase = 0,
  int currencyBase = 0,
  double willBase = 0,
  double willCoreSpend = 0,
  String? note,
}) {
  return FarmResourceCost(
    life: lifeBase > 0 ? state.farmDiscountedCostForTab(lifeBase, tab) : 0,
    history:
        historyBase > 0 ? state.farmDiscountedCostForTab(historyBase, tab) : 0,
    inorganic: inorganicBase > 0
        ? state.farmDiscountedCostForTab(inorganicBase, tab)
        : 0,
    currency: currencyBase > 0
        ? state.farmDiscountedCostForTab(currencyBase, tab)
        : 0,
    willpower: willBase > 0 ? willBase / state.shopTabMultiplierFor(tab) : 0,
    willCoreSpend: willCoreSpend,
    affinityAligned: state.isShopTabAligned(tab),
    note: note,
  );
}

/// ショップ項目 ID からコスト内訳を解決。
FarmResourceCost resolveShopEntryCost(String id, GameRuntimeState state) {
  final spec = shopSpecById(id);
  if (spec == null) return const FarmResourceCost();
  return _tabCost(
    state,
    spec.tab,
    lifeBase: spec.costLife,
    historyBase: spec.costHistory,
    inorganicBase: spec.costInorganic,
    currencyBase: spec.costCurrency,
    willBase: spec.costWillpower,
    willCoreSpend: spec.costWillCore,
    note: spec.id == 'common_6' ? '火炎放射器' : null,
  );
}
