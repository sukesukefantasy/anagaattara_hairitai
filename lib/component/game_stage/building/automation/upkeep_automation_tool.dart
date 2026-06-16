import 'package:flutter/material.dart';
import '../../../../system/automation_ability_catalog.dart';
import '../../../../system/automation_fuel.dart';
import '../../../../system/automation_tool_kind.dart';
import '../../../../system/farm_role_profile.dart';
import '../../../../system/storage/game_runtime_state.dart';
import '../../../effect/residue_pickup.dart';
import 'automation_tool_base.dart';
import 'harvest_automation_tool.dart';
import 'ward_automation_tool.dart';

/// 自動整備（valve）— 燃料・手動サイクル・他装置補給・C-2。
class UpkeepAutomationTool extends AutomationToolBase {
  static const double _stage2Interval = 60.0;
  static const double _stage3Interval = 30.0;
  static const double _stage4Interval = 15.0;

  double _cycleTimer = 0;

  UpkeepAutomationTool({
    required super.instanceId,
    required super.position,
  }) : super(kind: AutomationToolKind.upkeep);

  @override
  Color pulseColor() => const Color(0xFF78A0FF);

  int get _stage => state.automationKitStage;

  @override
  void tickTool(double dt) {
    _relayFuelToNearby(dt);

    final stage = _stage;
    if (stage < 2) return;
    if (!state.isAutomationUnlocked(AutomationUnlockIds.upkeepManualCycle)) {
      return;
    }

    final interval = stage == 4
        ? _stage4Interval
        : (stage == 3 ? _stage3Interval : _stage2Interval);
    _cycleTimer += dt;
    if (_cycleTimer >= interval) {
      _cycleTimer = 0;
      _runAutoCycle(stage);
    }

    if (stage == 4) {
      state.automationKitTotalRuntime += dt;
    }

    if (state.isAutomationUnlocked(AutomationUnlockIds.upkeepRepair)) {
      final repair = state.upkeepRepairPerTick() * dt;
      state.currentIntegrity = GameRuntimeState.quantizeIntegrityHalf(
        (state.currentIntegrity + repair).clamp(0.0, state.maxIntegrity),
      );
    }
  }

  void _relayFuelToNearby(double dt) {
    final radius = state.upkeepRelayRadius();
    if (radius <= 0) return;
    final parentComp = parent;
    if (parentComp == null) return;
    for (final child in parentComp.children) {
      if (child == this) continue;
      if (child is! AutomationToolBase) continue;
      final dist = (absoluteCenter - child.absoluteCenter).length;
      if (dist > radius) continue;
      if (state.upkeepToolFuel < 2) break;
      final relay = (dt * 3.0).clamp(0.5, 2.0);
      if (child is HarvestAutomationTool) {
        state.relayFuelToTool(AutomationToolKind.harvest, relay);
      } else if (child is WardAutomationTool) {
        state.relayFuelToTool(AutomationToolKind.ward, relay);
      }
    }
  }

  void _runAutoCycle(int stage) {
    int baseCurrency;
    int baseMining;
    switch (stage) {
      case 4:
        baseCurrency = 20;
        baseMining = 5;
        break;
      case 3:
        baseCurrency = 15;
        baseMining = 3;
        break;
      default:
        baseCurrency = 10;
        baseMining = 2;
    }
    final mult = state.farmCycleOutputMultiplier;
    final currencyGain = state.scaledFarmInt(baseCurrency, mult);
    final miningGain = state.scaledFarmInt(baseMining, mult);
    final cargoLife =
        state.farmSubModule == FarmSubModule.harvestRefine ? 2 : 1;

    game.player.updateMoneyPoints(currencyGain);
    game.player.updateMiningPoints(miningGain);
    ResiduePickup.emitCargo(
      game,
      ResiduePickup.worldEmitOrigin(this),
      life: cargoLife,
    );
    state.recordFarmOutput(
      currency: currencyGain,
      mining: miningGain,
      cargoLife: cargoLife,
    );
    state.noteMicroCategoryFarm(1);
    state.tryBoostAutomationAutoPickupFromAutoCycle();
    state.applyFarmCycleSideEffects();
    state.notifyRuntimeChanged();
  }

  /// 手動サイクル（インタラクト UI から呼ぶ）。
  void runManualCycle() {
    final mult = state.farmCycleOutputMultiplier;
    game.player.updateMoneyPoints(state.scaledFarmInt(10, mult));
    game.player.updateMiningPoints(state.scaledFarmInt(2, mult));
    ResiduePickup.emitCargo(
      game,
      ResiduePickup.worldEmitOrigin(this),
      life: 1,
    );
    state.tryStartAutomationAutoPickupWindow();
    state.openFarmInterventionWindow();
    state.codexIncrementAutomationOps();
    state.grantManualCycleFuel(game.player.itemBag);
    state.notifyRuntimeChanged();
  }

  void refuelFromWillpower() {
    state.produceSolidFuelFromWillpower(game.player.itemBag);
  }
}

