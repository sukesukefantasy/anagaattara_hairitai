import 'automation_shop_grade.dart';
import 'farm_role_profile.dart';
import 'storage/game_runtime_state.dart';

/// 自動化ショップ各項目の表示状態。
enum AutomationShopEntryStatus {
  purchased,
  available,
  locked,
  insufficient,
}

/// HUD ショップ1行分の表示データ（購入処理は [AutomationShopCatalog] 側）。
class AutomationShopEntry {
  const AutomationShopEntry({
    required this.id,
    required this.title,
    required this.costLabel,
    required this.status,
    this.statusDetail,
    this.affinityTab,
    this.aligned = false,
  });

  final String id;
  final String title;
  final String costLabel;
  final AutomationShopEntryStatus status;
  final String? statusDetail;
  final AutomationShopTab? affinityTab;
  final bool aligned;

  String get statusLabel => switch (status) {
        AutomationShopEntryStatus.purchased => '購入済',
        AutomationShopEntryStatus.available => '購入可',
        AutomationShopEntryStatus.locked => '未解放',
        AutomationShopEntryStatus.insufficient => '不足',
      };

  bool get canTapPurchase =>
      status == AutomationShopEntryStatus.available ||
      status == AutomationShopEntryStatus.insufficient;

  bool get canTapLockedHint => status == AutomationShopEntryStatus.locked;
}

String _costLabelForSpec(GameRuntimeState state, AutomationShopGradeSpec spec) {
  final tab = spec.tab;
  final parts = <String>[];
  if (spec.costLife > 0) {
    parts.add('生命${state.farmDiscountedCostForTab(spec.costLife, tab)}');
  }
  if (spec.costHistory > 0) {
    parts.add('歴史${state.farmDiscountedCostForTab(spec.costHistory, tab)}');
  }
  if (spec.costInorganic > 0) {
    parts.add('無機${state.farmDiscountedCostForTab(spec.costInorganic, tab)}');
  }
  if (spec.costCurrency > 0) {
    parts.add('通貨${state.farmDiscountedCostForTab(spec.costCurrency, tab)}');
  }
  if (spec.costWillpower > 0) {
    final pay = spec.costWillpower / state.shopTabMultiplierFor(tab);
    parts.add('意志力${pay.toStringAsFixed(1)}');
  }
  if (spec.costWillCore > 0) {
    parts.add('最大核${spec.costWillCore.toStringAsFixed(0)}消費');
  }
  if (parts.isEmpty) return '—';
  final joined = parts.join('・');
  if (state.isShopTabAligned(tab)) return '$joined（主軸お得）';
  return joined;
}

/// 購入前の dry-run。UI はこの一覧だけで状態別表示できる。
List<AutomationShopEntry> buildAutomationShopEntries(GameRuntimeState state) {
  return [
    for (final spec in kAutomationShopGradeSpecs)
      if (state.isShopEntryVisible(spec)) _buildEntry(state, spec),
  ];
}

List<AutomationShopEntry> buildAutomationShopEntriesForTab(
  GameRuntimeState state,
  AutomationShopTab tab,
) {
  return buildAutomationShopEntries(state)
      .where((e) => shopSpecById(e.id)?.tab == tab)
      .toList();
}

AutomationShopEntry _buildEntry(
  GameRuntimeState state,
  AutomationShopGradeSpec spec,
) {
  final tab = spec.tab;
  final aligned = state.isShopTabAligned(tab);
  final costLabel = _costLabelForSpec(state, spec);

  if (spec.id == 'common_6' && state.automationContractC2) {
    return AutomationShopEntry(
      id: spec.id,
      title: spec.title,
      costLabel: costLabel,
      status: AutomationShopEntryStatus.purchased,
      affinityTab: tab,
      aligned: aligned,
    );
  }

  if (state.shopGrade(tab) >= spec.gradeLevel) {
    return AutomationShopEntry(
      id: spec.id,
      title: spec.title,
      costLabel: costLabel,
      status: AutomationShopEntryStatus.purchased,
      affinityTab: tab,
      aligned: aligned,
    );
  }

  final lockHint = state.shopGradePrerequisiteHint(spec);
  if (lockHint != null) {
    return AutomationShopEntry(
      id: spec.id,
      title: spec.title,
      costLabel: costLabel,
      status: AutomationShopEntryStatus.locked,
      statusDetail: lockHint,
      affinityTab: tab,
      aligned: aligned,
    );
  }

  final shortage = _shortageDetail(state, spec);
  if (shortage != null) {
    return AutomationShopEntry(
      id: spec.id,
      title: spec.title,
      costLabel: costLabel,
      status: AutomationShopEntryStatus.insufficient,
      statusDetail: shortage,
      affinityTab: tab,
      aligned: aligned,
    );
  }

  return AutomationShopEntry(
    id: spec.id,
    title: spec.title,
    costLabel: costLabel,
    status: AutomationShopEntryStatus.available,
    affinityTab: tab,
    aligned: aligned,
  );
}

String? _shortageDetail(
  GameRuntimeState state,
  AutomationShopGradeSpec spec,
) {
  final tab = spec.tab;
  if (spec.costLife > 0) {
    final cost = state.farmDiscountedCostForTab(spec.costLife, tab);
    if (state.cargoLifeCount < cost) {
      return '生命 $cost 必要（現在 ${state.cargoLifeCount}）';
    }
  }
  if (spec.costHistory > 0) {
    final cost = state.farmDiscountedCostForTab(spec.costHistory, tab);
    if (state.cargoHistoryCount < cost) {
      return '歴史 $cost 必要（現在 ${state.cargoHistoryCount}）';
    }
  }
  if (spec.costInorganic > 0) {
    final cost = state.farmDiscountedCostForTab(spec.costInorganic, tab);
    if (state.cargoInorganicCount < cost) {
      return '無機 $cost 必要（現在 ${state.cargoInorganicCount}）';
    }
  }
  if (spec.costCurrency > 0) {
    final cost = state.farmDiscountedCostForTab(spec.costCurrency, tab);
    if (state.currency < cost) {
      return '通貨 $cost 必要（現在 ${state.currency}）';
    }
  }
  if (spec.costWillpower > 0) {
    final pay = spec.costWillpower / state.shopTabMultiplierFor(tab);
    if (state.currentWillpower < pay) {
      return '意志力 ${pay.toStringAsFixed(1)} 必要（現在 ${state.currentWillpower.toStringAsFixed(1)}）';
    }
  }
  if (spec.costWillCore > 0 &&
      state.maxWillCoreValue <=
          GameRuntimeState.willCoreUnit * spec.costWillCore + 1e-9) {
    return '意志の核の余裕が不足';
  }
  return null;
}
