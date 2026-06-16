import '../component/item/item.dart';
import '../component/item/item_bag.dart';
import 'package:flame/components.dart';

import 'automation_ability_catalog.dart';
import 'automation_fuel_rank.dart';
import 'automation_shop_grade.dart';
import 'automation_tool_kind.dart';
import 'automation_tool_state.dart';
import 'farm_role_profile.dart';
import 'storage/game_runtime_state.dart';

/// 全装置共通の燃料・意志力ランニングコスト。
extension AutomationFuel on GameRuntimeState {
  static const double minWillpowerFloor = 0.5;
  static const double defaultFuelPerKind = 40.0;
  static const double c2OperationalWillPerSecond = 0.04;
  static const double fuelPerWillComposite = 40.0;
  static const double weightedResiduePerFuel = 2.5;
  static const double autoRefuelCooldownSeconds = 3.0;
  static const double autoRefuelWillPay = 0.2;

  double fuelForKind(AutomationToolKind kind) => switch (kind) {
        AutomationToolKind.harvest => harvestToolFuel,
        AutomationToolKind.upkeep => upkeepToolFuel,
        AutomationToolKind.ward => wardToolFuel,
      };

  AutomationFuelRank? tankFuelRankForKind(AutomationToolKind kind) {
    final raw = switch (kind) {
      AutomationToolKind.harvest => harvestTankFuelRank,
      AutomationToolKind.upkeep => upkeepTankFuelRank,
      AutomationToolKind.ward => wardTankFuelRank,
    };
    return AutomationFuelRank.fromJson(raw);
  }

  void setTankFuelRankForKind(AutomationToolKind kind, AutomationFuelRank? rank) {
    final json = rank?.toJson();
    switch (kind) {
      case AutomationToolKind.harvest:
        harvestTankFuelRank = json;
      case AutomationToolKind.upkeep:
        upkeepTankFuelRank = json;
      case AutomationToolKind.ward:
        wardTankFuelRank = json;
    }
  }

  void setFuelForKind(AutomationToolKind kind, double value) {
    final max = maxFuelForKind(kind);
    final v = value.clamp(0.0, max);
    switch (kind) {
      case AutomationToolKind.harvest:
        harvestToolFuel = v;
        if (v <= 0) harvestTankFuelRank = null;
      case AutomationToolKind.upkeep:
        upkeepToolFuel = v;
        if (v <= 0) upkeepTankFuelRank = null;
      case AutomationToolKind.ward:
        wardToolFuel = v;
        if (v <= 0) wardTankFuelRank = null;
    }
  }

  double maxFuelForKind(AutomationToolKind kind) {
    if (kind == AutomationToolKind.upkeep) return upkeepMaxFuel();
    return defaultFuelPerKind;
  }

  bool get toolsRunWithoutFuelTank => automationContractC2;

  String? tankFuelRankLabel(AutomationToolKind kind) {
    if (toolsRunWithoutFuelTank) return '核接続';
    final rank = tankFuelRankForKind(kind);
    if (fuelForKind(kind) <= 0) return '空';
    return rank?.shortLabel ?? '不明';
  }

  /// タンク内燃料ランクに応じた燃費倍率（相性 −15% / 不一致 +10%）。
  double fuelCompatibilityCostMultiplier(
    AutomationToolKind kind,
    AutomationFuelRank? rank,
  ) {
    if (rank == null || toolsRunWithoutFuelTank) return 1.0;
    final preferred = rank.preferredTool;
    if (preferred == kind) return 0.85;
    if (preferred != null) return 1.10;
    return rank.burnCostMultiplier;
  }

  bool canToolOperate(AutomationToolKind kind) {
    if (toolsRunWithoutFuelTank) {
      return currentWillpower > minWillpowerFloor + 1e-6;
    }
    return fuelForKind(kind) > 0;
  }

  void tickToolFuel(AutomationToolKind kind, double dt) {
    if (automationAutoRefuelCooldownRemaining > 0) {
      automationAutoRefuelCooldownRemaining =
          (automationAutoRefuelCooldownRemaining - dt).clamp(0.0, 999.0);
    }

    if (toolsRunWithoutFuelTank) {
      _tickC2OperationalWill(dt);
      return;
    }

    var fuel = fuelForKind(kind);
    if (fuel <= 0) {
      if (automationAutoWillRefuel && canAutoRefuelFromWill) {
        _tryAutoRefuelFromWillpower(
          kind,
          minFuel: runningCostPerSecond(kind) * dt * 2,
        );
      }
      return;
    }

    final burn = runningCostPerSecond(kind) * dt;
    fuel = (fuel - burn).clamp(0.0, maxFuelForKind(kind));
    setFuelForKind(kind, fuel);

    if (fuelForKind(kind) <= 0 &&
        automationAutoWillRefuel &&
        canAutoRefuelFromWill) {
      _tryAutoRefuelFromWillpower(kind, minFuel: burn * 2);
    }
  }

  void _tickC2OperationalWill(double dt) {
    final pay = c2OperationalWillPerSecond * dt;
    if (currentWillpower <= minWillpowerFloor + pay) return;
    currentWillpower = (currentWillpower - pay).clamp(
      minWillpowerFloor,
      maxWillCoreValue,
    );
    notifyRuntimeChanged();
  }

  double runningCostPerSecond(AutomationToolKind kind) {
    if (toolsRunWithoutFuelTank) return 0;
    var cost = switch (kind) {
      AutomationToolKind.harvest => 0.18,
      AutomationToolKind.upkeep => 0.28,
      AutomationToolKind.ward => 0.20,
    };
    for (final spec in upgradeSpecsForKind(kind)) {
      cost += automationUpgradeLevel(spec.id) * 0.07;
    }
    if (automationKitStage >= 3) cost += 0.15;
    if (automationKitStage >= 4) cost += 0.2;
    cost *= fuelCompatibilityCostMultiplier(kind, tankFuelRankForKind(kind));
    if (automationFuelEfficiencyTier >= 1) cost *= 0.9;
    return cost;
  }

  double _willToFuelGain(double pay) {
    final tierBonus = 1.0 + (automationUpgradeStageTier - 1) * 0.05;
    return pay * fuelPerWillComposite * tierBonus.clamp(1.0, 1.35);
  }

  /// 残滓を圧縮して燃料アイテムをバッグへ（整備＝スタンド）。
  String? produceFuelItemFromResidue(
    ItemBag bag,
    AutomationFuelRank rank, {
    int life = 0,
    int history = 0,
    int inorganic = 0,
  }) {
    if (toolsRunWithoutFuelTank) return 'C-2 契約中は燃料補給不要です';
    if (!isFuelRankUnlocked(rank)) return '${rank.shortLabel} は未解放です';

    final total = life + history + inorganic;
    if (total <= 0) return '残滓を指定してください';

    if (!_validateDistillRatio(rank, life, history, inorganic)) {
      return _distillRatioHint(rank);
    }

    if (cargoLifeCount < life ||
        cargoHistoryCount < history ||
        cargoInorganicCount < inorganic) {
      return 'カーゴが不足しています';
    }

    cargoLifeCount = GameRuntimeState.clampResidueCount(cargoLifeCount - life);
    cargoHistoryCount =
        GameRuntimeState.clampResidueCount(cargoHistoryCount - history);
    cargoInorganicCount =
        GameRuntimeState.clampResidueCount(cargoInorganicCount - inorganic);

    final item = ItemFactory.createItemByName(rank.itemName, Vector2.zero());
    if (item == null) return '燃料アイテムを生成できません';

    bag.addItem(item);
    recordFarmCost(life: life, history: history, inorganic: inorganic);
    if (rank == AutomationFuelRank.r1Life && life > 0) {
      addStarAlertLevel(0.05);
    }
    saveGame();
    notifyRuntimeChanged();
    return null;
  }

  bool _validateDistillRatio(
    AutomationFuelRank rank,
    int life,
    int history,
    int inorganic,
  ) {
    return switch (rank) {
      AutomationFuelRank.r0Crude => life + history + inorganic >= 1,
      AutomationFuelRank.r1Life => life >= 2 && life >= history && life >= inorganic,
      AutomationFuelRank.r2History =>
        history >= 2 && history >= life && history >= inorganic,
      AutomationFuelRank.r3Inorganic =>
        inorganic >= 2 && inorganic >= life && inorganic >= history,
      AutomationFuelRank.s1Solid => false,
    };
  }

  String _distillRatioHint(AutomationFuelRank rank) => switch (rank) {
        AutomationFuelRank.r1Life => '生命残滓を2以上、かつ最多にしてください',
        AutomationFuelRank.r2History => '歴史残滓を2以上、かつ最多にしてください',
        AutomationFuelRank.r3Inorganic => '無機残滓を2以上、かつ最多にしてください',
        _ => '残滓量が不足しています',
      };

  /// 粗製燃料の簡易変換（R0・残滓1単位）。
  String? produceCrudeFuelFromResidue(ItemBag bag, {int units = 1}) {
    return produceFuelItemFromResidue(
      bag,
      AutomationFuelRank.r0Crude,
      life: units,
    );
  }

  /// 意志力を凝固燃料アイテムへ（整備＝スタンド）。
  String? produceSolidFuelFromWillpower(ItemBag bag, {double pay = 2.0}) {
    if (toolsRunWithoutFuelTank) return 'C-2 契約中は燃料補給不要です';
    if (!isFuelRankUnlocked(AutomationFuelRank.s1Solid)) {
      return '意志凝固は未解放です';
    }
    if (currentWillpower < pay + minWillpowerFloor) {
      return '意志力が不足しています（下限 ${minWillpowerFloor.toStringAsFixed(1)} を維持）';
    }
    currentWillpower -= pay;
    clampCurrentWillpowerToCapacity();
    final item = ItemFactory.createItemByName(
      AutomationFuelRank.s1Solid.itemName,
      Vector2.zero(),
    );
    if (item == null) return '燃料アイテムを生成できません';
    bag.addItem(item);
    recordFarmCost(willpower: pay);
    notifyRuntimeChanged();
    saveGame();
    return null;
  }

  /// バッグの燃料を装置タンクへ入れる。
  String? loadFuelFromBag(
    ItemBag bag,
    AutomationToolKind kind,
    AutomationFuelRank rank, {
    int count = 1,
  }) {
    if (toolsRunWithoutFuelTank) return 'C-2 契約中はタンク不要です';
    if (count <= 0) return '個数を指定してください';

    final have = bag.getItemCount(rank.itemName);
    if (have < count) return '${rank.itemName}が不足しています';

    final gain = rank.fuelUnitsPerItem * count;
    final max = maxFuelForKind(kind);
    if (fuelForKind(kind) >= max) return 'タンクが満杯です';

    bag.removeItem(rank.itemName, count: count);
    final next = (fuelForKind(kind) + gain).clamp(0.0, max);
    setFuelForKind(kind, next);
    if (fuelForKind(kind) > 0) {
      setTankFuelRankForKind(kind, rank);
    }
    notifyRuntimeChanged();
    saveGame();
    return null;
  }

  /// 手動：意志力を直接タンクへ（v8.5 調和比）。
  String? refuelToolFromWillpower(AutomationToolKind kind, {double pay = 2.0}) {
    if (toolsRunWithoutFuelTank) return 'C-2 契約中は燃料補給不要です';
    if (currentWillpower < pay + minWillpowerFloor) {
      return '意志力が不足しています（下限 ${minWillpowerFloor.toStringAsFixed(1)} を維持）';
    }
    currentWillpower -= pay;
    clampCurrentWillpowerToCapacity();
    final gain = _willToFuelGain(pay);
    setFuelForKind(kind, fuelForKind(kind) + gain);
    setTankFuelRankForKind(kind, AutomationFuelRank.s1Solid);
    recordFarmCost(willpower: pay);
    notifyRuntimeChanged();
    saveGame();
    return null;
  }

  /// レガシー互換：残滓を加重換算して直接タンクへ。
  @Deprecated('Use produceFuelItemFromResidue + loadFuelFromBag')
  String? refuelToolFromResidue(
    AutomationToolKind kind, {
    int life = 0,
    int history = 0,
    int inorganic = 0,
  }) {
    if (toolsRunWithoutFuelTank) return 'C-2 契約中は燃料補給不要です';
    final total = life + history + inorganic;
    if (total <= 0) return '残滓を指定してください';

    if (cargoLifeCount < life ||
        cargoHistoryCount < history ||
        cargoInorganicCount < inorganic) {
      return 'カーゴが不足しています';
    }

    cargoLifeCount = GameRuntimeState.clampResidueCount(cargoLifeCount - life);
    cargoHistoryCount =
        GameRuntimeState.clampResidueCount(cargoHistoryCount - history);
    cargoInorganicCount =
        GameRuntimeState.clampResidueCount(cargoInorganicCount - inorganic);

    final weighted = life * 4 + history * 1 + inorganic * 6;
    final fuelGain =
        (weighted / weightedResiduePerFuel).clamp(1.0, maxFuelForKind(kind));
    setFuelForKind(kind, fuelForKind(kind) + fuelGain);
    setTankFuelRankForKind(kind, AutomationFuelRank.r0Crude);
    recordFarmCost(life: life, history: history, inorganic: inorganic);
    saveGame();
    notifyRuntimeChanged();
    return null;
  }

  void _tryAutoRefuelFromWillpower(
    AutomationToolKind kind, {
    required double minFuel,
  }) {
    if (!canAutoRefuelFromWill) return;
    if (automationAutoRefuelCooldownRemaining > 0) return;
    const pay = autoRefuelWillPay;
    if (currentWillpower < pay + minWillpowerFloor) return;
    currentWillpower -= pay;
    clampCurrentWillpowerToCapacity();
    final gain = _willToFuelGain(pay);
    if (gain < minFuel * 0.5) return;
    setFuelForKind(kind, fuelForKind(kind) + gain);
    setTankFuelRankForKind(kind, AutomationFuelRank.s1Solid);
    recordFarmCost(willpower: pay);
    automationAutoRefuelCooldownRemaining = autoRefuelCooldownSeconds;
    notifyRuntimeChanged();
  }

  void grantManualCycleFuel(ItemBag bag) {
    for (final k in AutomationToolKind.values) {
      if (!hasToolPlaced(k)) continue;
      final item = ItemFactory.createItemByName(
        AutomationFuelRank.r0Crude.itemName,
        Vector2.zero(),
      );
      if (item != null) bag.addItem(item, silent: true);
    }
    notifyRuntimeChanged();
  }

  /// 整備が近くの装置へ燃料を送る。
  void relayFuelToTool(AutomationToolKind target, double amount) {
    if (toolsRunWithoutFuelTank) return;
    if (upkeepToolFuel < amount) return;
    upkeepToolFuel = (upkeepToolFuel - amount).clamp(0.0, upkeepMaxFuel());
    setFuelForKind(target, fuelForKind(target) + amount);
    final donorRank = tankFuelRankForKind(AutomationToolKind.upkeep);
    if (donorRank != null && fuelForKind(target) > 0) {
      setTankFuelRankForKind(target, donorRank);
    }
    notifyRuntimeChanged();
  }
}
