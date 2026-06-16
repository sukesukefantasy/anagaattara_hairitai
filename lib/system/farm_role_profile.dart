import 'automation_shop_grade.dart';
import 'storage/game_runtime_state.dart';

/// ファーム主軸ロール（§ ファーム駆け引き v0.1）。プレイヤーは1つだけ選択。
enum FarmPrimaryRole {
  none,
  harvest,
  ward,
  upkeep,
}

/// 主軸ごとの副次モジュール（各2択・1つのみ）。
enum FarmSubModule {
  none,
  harvestWide,
  harvestRefine,
  wardMelee,
  wardRanged,
  upkeepIntegrity,
  upkeepCalm,
}

/// 自動化ショップ Tier（A/B/C）と主軸の相性。
enum FarmShopTier { a, b, c }

extension FarmRoleProfile on GameRuntimeState {
  static const double affinityTierBonus = 0.15;

  FarmPrimaryRole get farmPrimaryRole =>
      FarmPrimaryRole.values[farmPrimaryRoleIndex.clamp(0, 3)];

  FarmSubModule get farmSubModule =>
      FarmSubModule.values[farmSubModuleIndex.clamp(0, 6)];

  void setFarmPrimaryRole(FarmPrimaryRole role) {
    farmPrimaryRoleIndex = role.index;
    notifyRuntimeChanged();
    saveGame();
  }

  void setFarmSubModule(FarmSubModule mod) {
    farmSubModuleIndex = mod.index;
    notifyRuntimeChanged();
    saveGame();
  }

  String get farmPrimaryRoleLabel => switch (farmPrimaryRole) {
        FarmPrimaryRole.harvest => '収穫',
        FarmPrimaryRole.ward => '防衛',
        FarmPrimaryRole.upkeep => '整備',
        FarmPrimaryRole.none => '未設定',
      };

  double get farmCycleOutputMultiplier {
    if (farmPrimaryRole == FarmPrimaryRole.none) return 1.0;

    var m = switch (farmPrimaryRole) {
      FarmPrimaryRole.harvest => 1.28,
      FarmPrimaryRole.ward => 0.92,
      FarmPrimaryRole.upkeep => 1.05,
      FarmPrimaryRole.none => 1.0,
    };

    m *= switch (farmSubModule) {
      FarmSubModule.harvestRefine => 1.12,
      FarmSubModule.harvestWide => 1.05,
      FarmSubModule.upkeepIntegrity => 1.04,
      FarmSubModule.upkeepCalm => 1.04,
      _ => 1.0,
    };

    if (farmInterventionWindowSeconds > 0) m *= 1.08;
    if (farmDoubleCycleRemaining > 0) m *= 2.0;
    return m;
  }

  double get farmContactStressMultiplier {
    if (farmPrimaryRole != FarmPrimaryRole.ward) return 1.0;
    return farmSubModule == FarmSubModule.wardMelee ? 0.72 : 0.88;
  }

  double get farmAutoPickupRangeBonus {
    if (farmPrimaryRole != FarmPrimaryRole.harvest) return 0;
    return farmSubModule == FarmSubModule.harvestWide ? 36.0 : 12.0;
  }

  double shopTabMultiplierFor(AutomationShopTab tab) {
    if (farmPrimaryRole == FarmPrimaryRole.none) return 1.0;
    return isShopTabAligned(tab) ? 1.0 + affinityTierBonus : 1.0;
  }

  bool isShopTabAligned(AutomationShopTab tab) => switch (tab) {
        AutomationShopTab.harvest => farmPrimaryRole == FarmPrimaryRole.harvest,
        AutomationShopTab.upkeep => farmPrimaryRole == FarmPrimaryRole.upkeep,
        AutomationShopTab.ward => farmPrimaryRole == FarmPrimaryRole.ward,
        AutomationShopTab.common => false,
      };

  double shopTierMultiplierFor(FarmShopTier tier) => shopTabMultiplierFor(
        switch (tier) {
          FarmShopTier.a => AutomationShopTab.harvest,
          FarmShopTier.b => AutomationShopTab.upkeep,
          FarmShopTier.c => AutomationShopTab.ward,
        },
      );

  bool isShopTierAligned(FarmShopTier tier) =>
      shopTierMultiplierFor(tier) > 1.05;

  int farmDiscountedCostForTab(int base, AutomationShopTab tab) {
    if (base <= 0) return 0;
    final mult = shopTabMultiplierFor(tab);
    if (mult <= 1.0) return base;
    return (base / mult).ceil().clamp(1, base);
  }

  double get farmInterventionProcChance {
    var base = 0.10 + automationShopGradeUpkeep * 0.02;
    if (farmPrimaryRole == FarmPrimaryRole.harvest) base += 0.04;
    if (farmPrimaryRole == FarmPrimaryRole.upkeep) base += 0.03;
    return base.clamp(0.08, 0.22);
  }

  void openFarmInterventionWindow({double seconds = 12.0}) {
    if (farmInterventionWindowSeconds < seconds) {
      farmInterventionWindowSeconds = seconds;
    }
  }

  void tickFarmInterventionWindow(double dt) {
    if (farmInterventionWindowSeconds > 0) {
      farmInterventionWindowSeconds -= dt;
      if (farmInterventionWindowSeconds < 0) farmInterventionWindowSeconds = 0;
    }
    if (farmDoubleCycleRemaining > 0) {
      farmDoubleCycleRemaining -= dt;
      if (farmDoubleCycleRemaining < 0) farmDoubleCycleRemaining = 0;
    }
  }

  void recordFarmCost({
    int life = 0,
    int history = 0,
    int inorganic = 0,
    double willpower = 0,
    int currency = 0,
  }) {
    farmCostLife += life;
    farmCostHistory += history;
    farmCostInorganic += inorganic;
    farmCostWillpower += willpower;
    farmCostCurrency += currency;
    _refreshFarmRoiMultiplier();
  }

  void recordFarmOutput({
    int currency = 0,
    int mining = 0,
    int cargoLife = 0,
    int cargoHistory = 0,
    int cargoInorganic = 0,
  }) {
    farmOutputCurrency += currency;
    farmOutputMining += mining;
    farmOutputCargoLife += cargoLife;
    farmOutputCargoHistory += cargoHistory;
    farmOutputCargoInorganic += cargoInorganic;
    _refreshFarmRoiMultiplier();
  }

  void _refreshFarmRoiMultiplier() {
    final cost = farmCostLife +
        farmCostHistory +
        farmCostInorganic +
        (farmCostWillpower * 4).round() +
        (farmCostCurrency / 5).round();
    final output = farmOutputCurrency +
        farmOutputMining +
        farmOutputCargoLife +
        farmOutputCargoHistory +
        farmOutputCargoInorganic;
    if (cost <= 0 && output <= 0) {
      farmRoiMultiplier = 1.0;
      return;
    }
    if (cost <= 0) {
      farmRoiMultiplier = 1.5;
      return;
    }
    farmRoiMultiplier = (output / cost).clamp(0.5, 3.0);
    notifyRuntimeChanged();
  }

  /// 主軸と該当タブが一致すると支払いが実質15%お得（切り上げで最低1）。
  int farmDiscountedCost(int base, FarmShopTier tier) =>
      farmDiscountedCostForTab(
        base,
        switch (tier) {
          FarmShopTier.a => AutomationShopTab.harvest,
          FarmShopTier.b => AutomationShopTab.upkeep,
          FarmShopTier.c => AutomationShopTab.ward,
        },
      );

  void applyFarmCycleSideEffects() {
    switch (farmPrimaryRole) {
      case FarmPrimaryRole.upkeep:
        final integrityGain =
            farmSubModule == FarmSubModule.upkeepIntegrity ? 3.0 : 1.5;
        final stressDrop =
            farmSubModule == FarmSubModule.upkeepCalm ? 4.0 : 2.0;
        currentIntegrity = GameRuntimeState.quantizeIntegrityHalf(
          (currentIntegrity + integrityGain).clamp(0.0, maxIntegrity),
        );
        currentStress = (currentStress - stressDrop).clamp(0.0, maxStress);
        break;
      case FarmPrimaryRole.ward:
        if (farmSubModule == FarmSubModule.wardRanged) {
          addStarAlertLevel(-0.025);
        }
        break;
      default:
        break;
    }
    notifyRuntimeChanged();
  }

  int scaledFarmInt(int base, double multiplier) {
    final v = (base * multiplier).round();
    return v < 1 && base > 0 ? 1 : v;
  }
}
