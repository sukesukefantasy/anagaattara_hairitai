import 'automation_tool_kind.dart';
import 'farm_role_profile.dart';
import 'automation_shop_grade.dart';
import 'storage/game_runtime_state.dart';

/// ショップで開放する能力 ID。
class AutomationUnlockIds {
  static const harvestVacuum = 'harvest.vacuum';
  static const harvestStorage = 'harvest.storage';
  static const harvestFilterResidue = 'harvest.filter.residue';

  static const upkeepRepair = 'upkeep.repair';
  static const upkeepFuelRelay = 'upkeep.fuelRelay';
  static const upkeepManualCycle = 'upkeep.manualCycle';

  static const wardMelee = 'ward.melee';
  static const wardRanged = 'ward.ranged';
  static const wardSlow = 'ward.slow';
}

/// インタラクトで強化するパラメータ ID。
class AutomationUpgradeIds {
  static const harvestRange = 'harvest.vacuum.range';
  static const harvestCapacity = 'harvest.storage.capacity';
  static const harvestPullSpeed = 'harvest.vacuum.speed';

  static const upkeepFuelTank = 'upkeep.fuel.tank';
  static const upkeepRelayRadius = 'upkeep.relay.radius';
  static const upkeepRepairAmount = 'upkeep.repair.amount';

  static const wardDamage = 'ward.melee.damage';
  static const wardRange = 'ward.melee.range';
  static const wardCooldown = 'ward.attack.cooldown';
}

/// 強化1段階のコストと効果説明。
class AutomationUpgradeSpec {
  final String id;
  final String title;
  final AutomationToolKind kind;
  final String requiredUnlockId;
  final int maxLevel;
  final int costLife;
  final int costHistory;
  final int costInorganic;
  final int costCurrency;
  final double costWillpower;
  final String effectDescription;

  const AutomationUpgradeSpec({
    required this.id,
    required this.title,
    required this.kind,
    required this.requiredUnlockId,
    this.maxLevel = kAutomationUpgradeAbsoluteMaxLevel,
    this.costLife = 0,
    this.costHistory = 0,
    this.costInorganic = 0,
    this.costCurrency = 0,
    this.costWillpower = 0,
    required this.effectDescription,
  });
}

const List<AutomationUpgradeSpec> kAutomationUpgradeSpecs = [
  AutomationUpgradeSpec(
    id: AutomationUpgradeIds.harvestRange,
    title: '吸引半径',
    kind: AutomationToolKind.harvest,
    requiredUnlockId: AutomationUnlockIds.harvestVacuum,
    costLife: 8,
    effectDescription: '吸引範囲 +28px / Lv',
  ),
  AutomationUpgradeSpec(
    id: AutomationUpgradeIds.harvestCapacity,
    title: 'ストレージ容量',
    kind: AutomationToolKind.harvest,
    requiredUnlockId: AutomationUnlockIds.harvestStorage,
    costInorganic: 6,
    effectDescription: '残滓スロット +30 / Lv',
  ),
  AutomationUpgradeSpec(
    id: AutomationUpgradeIds.harvestPullSpeed,
    title: '吸引速度',
    kind: AutomationToolKind.harvest,
    requiredUnlockId: AutomationUnlockIds.harvestVacuum,
    costLife: 5,
    costHistory: 3,
    effectDescription: '吸引速度 +22% / Lv',
  ),
  AutomationUpgradeSpec(
    id: AutomationUpgradeIds.upkeepFuelTank,
    title: '燃料タンク',
    kind: AutomationToolKind.upkeep,
    requiredUnlockId: AutomationUnlockIds.upkeepRepair,
    costWillpower: 1.5,
    effectDescription: '最大燃料 +20 / Lv',
  ),
  AutomationUpgradeSpec(
    id: AutomationUpgradeIds.upkeepRelayRadius,
    title: '補給半径',
    kind: AutomationToolKind.upkeep,
    requiredUnlockId: AutomationUnlockIds.upkeepFuelRelay,
    costCurrency: 15,
    effectDescription: '他装置への補給半径 +25px / Lv',
  ),
  AutomationUpgradeSpec(
    id: AutomationUpgradeIds.upkeepRepairAmount,
    title: '回復量',
    kind: AutomationToolKind.upkeep,
    requiredUnlockId: AutomationUnlockIds.upkeepRepair,
    costLife: 6,
    effectDescription: 'Integrity 回復 +1 / Lv',
  ),
  AutomationUpgradeSpec(
    id: AutomationUpgradeIds.wardDamage,
    title: '攻撃力',
    kind: AutomationToolKind.ward,
    requiredUnlockId: AutomationUnlockIds.wardMelee,
    costInorganic: 8,
    effectDescription: 'ダメージ +4 / Lv',
  ),
  AutomationUpgradeSpec(
    id: AutomationUpgradeIds.wardRange,
    title: '射程',
    kind: AutomationToolKind.ward,
    requiredUnlockId: AutomationUnlockIds.wardMelee,
    costHistory: 5,
    effectDescription: '射程 +20px / Lv',
  ),
  AutomationUpgradeSpec(
    id: AutomationUpgradeIds.wardCooldown,
    title: '攻撃間隔',
    kind: AutomationToolKind.ward,
    requiredUnlockId: AutomationUnlockIds.wardMelee,
    costCurrency: 20,
    effectDescription: 'クールダウン -8% / Lv',
  ),
];

/// 1調査ステージ（outdoor_1=1 … outdoor_4=4, philosophy=5）あたりの強化上限増分。
const int kAutomationUpgradeLevelsPerStage = 4;

/// 強化の絶対最大 Lv（全ステージ到達後もここまで）。
const int kAutomationUpgradeAbsoluteMaxLevel = 24;

extension AutomationAbilityCatalog on GameRuntimeState {
  static const int maxPlacementsPerKind = 1;

  /// 屋外シーン ID から調査ステージ tier を求める。
  static int investigationStageTierForScene(String? sceneId) {
    if (sceneId == null) return 1;
    if (sceneId == 'outdoor_philosophy') return 5;
    if (!GameRuntimeState.isTargetStarOutdoorId(sceneId)) return 0;
    return int.tryParse(sceneId.split('_').last) ?? 1;
  }

  /// セーブ読込・ステージ入場時に tier を更新。
  void noteAutomationUpgradeStageTier(String? sceneId) {
    final tier = investigationStageTierForScene(sceneId);
    if (tier <= 0) return;
    if (tier > automationUpgradeStageTier) {
      automationUpgradeStageTier = tier;
      notifyRuntimeChanged();
    }
  }

  int automationUpgradeLevelCapForStageTier(int tier) {
    if (tier <= 0) return kAutomationUpgradeLevelsPerStage;
    final cap = tier * kAutomationUpgradeLevelsPerStage;
    return cap.clamp(
      kAutomationUpgradeLevelsPerStage,
      kAutomationUpgradeAbsoluteMaxLevel,
    );
  }

  /// 現在の進行で到達できる強化上限 Lv。
  int automationUpgradeLevelCap() =>
      automationUpgradeLevelCapForStageTier(automationUpgradeStageTier);

  int automationUpgradeEffectiveMaxLevel(AutomationUpgradeSpec spec) {
    final cap = automationUpgradeLevelCap();
    return cap < spec.maxLevel ? cap : spec.maxLevel;
  }

  bool isAutomationUnlocked(String unlockId) =>
      automationUnlocks[unlockId] == true;

  void unlockAutomation(String unlockId) {
    automationUnlocks[unlockId] = true;
  }

  int automationUpgradeLevel(String upgradeId) =>
      automationUpgradeLevels[upgradeId] ?? 0;

  void setAutomationUpgradeLevel(String upgradeId, int level) {
    final spec = kAutomationUpgradeSpecs
        .cast<AutomationUpgradeSpec?>()
        .firstWhere((s) => s!.id == upgradeId, orElse: () => null);
    final max = spec == null
        ? kAutomationUpgradeAbsoluteMaxLevel
        : automationUpgradeEffectiveMaxLevel(spec);
    automationUpgradeLevels[upgradeId] = level.clamp(0, max);
  }

  /// 収穫: 吸引半径（px）。旧 A-1 自動回収（100〜140）程度を基準。
  double harvestVacuumRange() {
    if (!isAutomationUnlocked(AutomationUnlockIds.harvestVacuum)) return 0;
    final lv = automationUpgradeLevel(AutomationUpgradeIds.harvestRange);
    return 128.0 + lv * 28.0 + farmAutoPickupRangeBonus;
  }

  /// 収穫: ストレージ容量（残滓ユニット換算）
  int harvestStorageCapacity() {
    if (!isAutomationUnlocked(AutomationUnlockIds.harvestStorage)) return 0;
    final lv = automationUpgradeLevel(AutomationUpgradeIds.harvestCapacity);
    return 80 + lv * 30;
  }

  double harvestPullSpeedMultiplier() {
    final lv = automationUpgradeLevel(AutomationUpgradeIds.harvestPullSpeed);
    return 1.35 + lv * 0.22;
  }

  /// 整備: 最大燃料
  double upkeepMaxFuel() {
    final lv = automationUpgradeLevel(AutomationUpgradeIds.upkeepFuelTank);
    return 40.0 + lv * 20.0;
  }

  double upkeepRelayRadius() {
    if (!isAutomationUnlocked(AutomationUnlockIds.upkeepFuelRelay)) return 0;
    final lv = automationUpgradeLevel(AutomationUpgradeIds.upkeepRelayRadius);
    return 80.0 + lv * 25.0;
  }

  double upkeepRepairPerTick() {
    if (!isAutomationUnlocked(AutomationUnlockIds.upkeepRepair)) return 0;
    final lv = automationUpgradeLevel(AutomationUpgradeIds.upkeepRepairAmount);
    return 1.5 + lv * 1.0;
  }

  /// 防衛
  double wardMeleeDamage() {
    if (!isAutomationUnlocked(AutomationUnlockIds.wardMelee)) return 0;
    final lv = automationUpgradeLevel(AutomationUpgradeIds.wardDamage);
    return 8.0 + lv * 4.0;
  }

  double wardMeleeRange() {
    if (!isAutomationUnlocked(AutomationUnlockIds.wardMelee)) return 0;
    final lv = automationUpgradeLevel(AutomationUpgradeIds.wardRange);
    return 60.0 + lv * 20.0;
  }

  double wardAttackInterval() {
    var base = 1.2;
    if (isAutomationUnlocked(AutomationUnlockIds.wardRanged)) base *= 0.85;
    final lv = automationUpgradeLevel(AutomationUpgradeIds.wardCooldown);
    return (base * (1.0 - lv * 0.08)).clamp(0.35, 2.0);
  }

  AutomationShopTab shopTabForToolKind(AutomationToolKind kind) => switch (kind) {
        AutomationToolKind.harvest => AutomationShopTab.harvest,
        AutomationToolKind.upkeep => AutomationShopTab.upkeep,
        AutomationToolKind.ward => AutomationShopTab.ward,
      };

  List<AutomationUpgradeSpec> upgradeSpecsForKind(AutomationToolKind kind) =>
      kAutomationUpgradeSpecs.where((s) => s.kind == kind).toList();

  String? tryUpgradeAutomation(String upgradeId) {
    final spec = kAutomationUpgradeSpecs
        .cast<AutomationUpgradeSpec?>()
        .firstWhere((s) => s!.id == upgradeId, orElse: () => null);
    if (spec == null) return '不明な強化です';
    if (!isAutomationUnlocked(spec.requiredUnlockId)) {
      return 'ショップで先に開放してください';
    }
    final cur = automationUpgradeLevel(upgradeId);
    final cap = automationUpgradeEffectiveMaxLevel(spec);
    if (cur >= spec.maxLevel) return '最大レベルです';
    if (cur >= cap) {
      return '調査ステージ${automationUpgradeStageTier}では Lv$cap まで。'
          '次のステージへ進むと上限が上がる。';
    }

    final tab = shopTabForToolKind(spec.kind);
    final lifeCost = farmDiscountedCostForTab(spec.costLife, tab);
    final histCost = farmDiscountedCostForTab(spec.costHistory, tab);
    final inoCost = farmDiscountedCostForTab(spec.costInorganic, tab);
    final curCost = farmDiscountedCostForTab(spec.costCurrency, tab);
    final willCost = spec.costWillpower > 0
        ? spec.costWillpower / shopTabMultiplierFor(tab)
        : 0.0;

    if (cargoLifeCount < lifeCost ||
        cargoHistoryCount < histCost ||
        cargoInorganicCount < inoCost ||
        currency < curCost ||
        currentWillpower < willCost) {
      return 'コストが不足しています';
    }

    cargoLifeCount =
        GameRuntimeState.clampResidueCount(cargoLifeCount - lifeCost);
    cargoHistoryCount =
        GameRuntimeState.clampResidueCount(cargoHistoryCount - histCost);
    cargoInorganicCount =
        GameRuntimeState.clampResidueCount(cargoInorganicCount - inoCost);
    currency -= curCost;
    if (willCost > 0) {
      currentWillpower -= willCost;
      clampCurrentWillpowerToCapacity();
    }
    recordFarmCost(
      life: lifeCost,
      history: histCost,
      inorganic: inoCost,
      currency: curCost,
      willpower: willCost,
    );
    setAutomationUpgradeLevel(upgradeId, cur + 1);
    saveGame();
    notifyRuntimeChanged();
    return null;
  }

  /// ストレージからプレイヤーカーゴへ搬出。
  /// [onCurrencyGain] / [onMiningGain] で Player の notifier 経由に同期する。
  void transferHarvestStorageToCargo({
    void Function(int amount)? onCurrencyGain,
    void Function(int amount)? onMiningGain,
  }) {
    cargoLifeCount = GameRuntimeState.clampResidueCount(
      cargoLifeCount + harvestStorage.life,
    );
    cargoHistoryCount = GameRuntimeState.clampResidueCount(
      cargoHistoryCount + harvestStorage.history,
    );
    cargoInorganicCount = GameRuntimeState.clampResidueCount(
      cargoInorganicCount + harvestStorage.inorganic,
    );
    final cur = harvestStorage.currency;
    if (cur > 0) {
      if (onCurrencyGain != null) {
        onCurrencyGain(cur);
      } else {
        currency += cur;
      }
    }
    final mining = harvestStorage.miningPoints;
    if (mining > 0) {
      if (onMiningGain != null) {
        onMiningGain(mining);
      } else {
        miningPoints += mining;
      }
    }
    harvestStorage.clear();
    notifyRuntimeChanged();
    saveGame();
  }
}
