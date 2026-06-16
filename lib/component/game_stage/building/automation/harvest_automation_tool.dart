import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../system/automation_ability_catalog.dart';
import '../../../../system/automation_tool_kind.dart';
import '../../../effect/residue_effect.dart';
import '../../../effect/residue_pickup.dart';
import '../../../item/item.dart';
import 'automation_tool_base.dart';

/// 自動収穫（nozzle）— 吸引＋内蔵ストレージ（A-2以降）。
class HarvestAutomationTool extends AutomationToolBase {
  double _vacuumTick = 0;

  HarvestAutomationTool({
    required super.instanceId,
    required super.position,
  }) : super(kind: AutomationToolKind.harvest);

  @override
  Color pulseColor() => const Color(0xFF00DC78);

  bool get _hasStorageModule =>
      state.isAutomationUnlocked(AutomationUnlockIds.harvestStorage);

  int get _storageCap => state.harvestStorageCapacity();

  bool get _storageFull =>
      _hasStorageModule &&
      _storageCap > 0 &&
      state.harvestStorage.totalSlots >= _storageCap;

  @override
  void tickTool(double dt) {
    final range = state.harvestVacuumRange();
    if (range <= 0) {
      setDisplayLabel(kind.displayLabel);
      return;
    }

    if (_storageFull) {
      setDisplayLabel('${kind.displayLabel}（ストレージ満杯）');
      return;
    }

    setDisplayLabel(kind.displayLabel);

    _vacuumTick += dt;
    if (_vacuumTick < 0.05) return;
    _vacuumTick = 0;

    final origin = absoluteCenter;
    final speedMul = state.harvestPullSpeedMultiplier();
    final pull = 320.0 * speedMul;
    final absorbDist = (range * 0.14).clamp(24.0, 48.0);

    for (final item in game.world.children.whereType<Item>()) {
      if (item.isCollected) continue;
      final dist = (origin - item.absoluteCenter).length;
      if (dist > range) continue;
      if (dist < absorbDist) {
        if (_tryAbsorbItem(item)) {
          item.removeFromParent();
        }
        continue;
      }
      final dir = (origin - item.absoluteCenter).normalized();
      item.position += dir * pull * 0.05;
    }

    if (state.isAutomationUnlocked(AutomationUnlockIds.harvestFilterResidue) ||
        state.isAutomationUnlocked(AutomationUnlockIds.harvestVacuum)) {
      for (final r in game.world.children.whereType<ResiduePickup>()) {
        if (!r.collectibleByPlayer) continue;
        final dist = (origin - r.absolutePosition).length;
        if (dist > range) continue;
        if (dist < absorbDist) {
          if (_tryAbsorbResidue(r)) {
            r.removeFromParent();
          }
          continue;
        }
        final dir = (origin - r.absolutePosition).normalized();
        r.position += dir * pull * 0.05;
      }
    }
  }

  /// ストレージ未開放時は吸引のみ（格納しない）。満杯時は false。
  bool _tryAbsorbItem(Item item) {
    if (!_hasStorageModule) return false;
    if (_storageFull) return false;
    if (!_stashItemValue(item)) return false;
    return true;
  }

  bool _tryAbsorbResidue(ResiduePickup r) {
    if (!_hasStorageModule) return false;
    if (_storageFull) return false;
    _stashResidue(r);
    return true;
  }

  bool _stashItemValue(Item item) {
    final storage = state.harvestStorage;
    if (storage.totalSlots >= _storageCap) return false;
    if (!_applyItemToStorage(item)) return false;
    state.notifyRuntimeChanged();
    return true;
  }

  bool _applyItemToStorage(Item item) {
    final storage = state.harvestStorage;
    switch (item.resourceType) {
      case ResourceType.life:
        storage.life += item.value.clamp(1, 99);
        return true;
      case ResourceType.history:
        storage.history += item.value.clamp(1, 99);
        return true;
      case ResourceType.inorganic:
        storage.inorganic += item.value.clamp(1, 99);
        return true;
      case ResourceType.none:
        final name = item.name;
        if (name == '通貨') {
          storage.currency += item.value.clamp(1, 99);
          return true;
        }
        if (name.contains('採掘') || name == 'クオーツ') {
          storage.miningPoints += 1;
          return true;
        }
        return false;
    }
  }

  void _stashResidue(ResiduePickup r) {
    final storage = state.harvestStorage;
    if (storage.totalSlots >= _storageCap) return;
    switch (r.type) {
      case ResidueType.life:
        storage.life += r.cargoValue;
      case ResidueType.history:
        storage.history += r.cargoValue;
      case ResidueType.inorganic:
        storage.inorganic += r.cargoValue;
    }
    state.notifyRuntimeChanged();
  }
}
