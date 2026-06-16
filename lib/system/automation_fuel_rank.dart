import 'package:flutter/material.dart';

import 'automation_shop_grade.dart';
import 'automation_tool_kind.dart';
import 'storage/game_runtime_state.dart';

/// 装置タンクに入る燃料のランク（プレイ上は缶／凝固ブロック比喩）。
enum AutomationFuelRank {
  r0Crude,
  r1Life,
  r2History,
  r3Inorganic,
  s1Solid;

  static AutomationFuelRank? fromJson(String? s) {
    if (s == null || s.isEmpty) return null;
    return switch (s) {
      'r0Crude' => AutomationFuelRank.r0Crude,
      'r1Life' => AutomationFuelRank.r1Life,
      'r2History' => AutomationFuelRank.r2History,
      'r3Inorganic' => AutomationFuelRank.r3Inorganic,
      's1Solid' => AutomationFuelRank.s1Solid,
      _ => null,
    };
  }

  String toJson() => name;
}

extension AutomationFuelRankX on AutomationFuelRank {
  String get itemName => switch (this) {
        AutomationFuelRank.r0Crude => '粗製燃料',
        AutomationFuelRank.r1Life => '生命馏分',
        AutomationFuelRank.r2History => '歴史胶质',
        AutomationFuelRank.r3Inorganic => '無機基油',
        AutomationFuelRank.s1Solid => '意志凝固',
      };

  String get shortLabel => switch (this) {
        AutomationFuelRank.r0Crude => '粗製',
        AutomationFuelRank.r1Life => '生命馏',
        AutomationFuelRank.r2History => '歴史胶',
        AutomationFuelRank.r3Inorganic => '無機基油',
        AutomationFuelRank.s1Solid => '意志凝固',
      };

  Color get accentColor => switch (this) {
        AutomationFuelRank.r0Crude => Colors.grey.shade400,
        AutomationFuelRank.r1Life => Colors.redAccent,
        AutomationFuelRank.r2History => Colors.lightBlueAccent,
        AutomationFuelRank.r3Inorganic => Colors.blueGrey,
        AutomationFuelRank.s1Solid => Colors.cyanAccent,
      };

  /// 1 個あたりタンクへ入る燃料量。
  double get fuelUnitsPerItem => switch (this) {
        AutomationFuelRank.r0Crude => 8,
        AutomationFuelRank.r1Life => 12,
        AutomationFuelRank.r2History => 12,
        AutomationFuelRank.r3Inorganic => 12,
        AutomationFuelRank.s1Solid => 20,
      };

  /// 相性一致時の燃費倍率（小さいほど長持ち）。
  double get burnCostMultiplier => switch (this) {
        AutomationFuelRank.r0Crude => 1.0,
        AutomationFuelRank.r1Life => 0.92,
        AutomationFuelRank.r2History => 0.92,
        AutomationFuelRank.r3Inorganic => 0.92,
        AutomationFuelRank.s1Solid => 0.80,
      };

  AutomationToolKind? get preferredTool => switch (this) {
        AutomationFuelRank.r1Life => AutomationToolKind.ward,
        AutomationFuelRank.r2History => AutomationToolKind.harvest,
        AutomationFuelRank.r3Inorganic => AutomationToolKind.upkeep,
        _ => null,
      };

  static AutomationFuelRank? fromItemName(String? name) {
    if (name == null) return null;
    for (final r in AutomationFuelRank.values) {
      if (r.itemName == name) return r;
    }
    return null;
  }
}

extension AutomationFuelRankUnlock on GameRuntimeState {
  bool isFuelRankUnlocked(AutomationFuelRank rank) {
    return switch (rank) {
      AutomationFuelRank.r0Crude => true,
      AutomationFuelRank.r1Life => automationShopGradeCommon >= 1,
      AutomationFuelRank.r2History => automationShopGradeCommon >= 2,
      AutomationFuelRank.r3Inorganic => automationShopGradeCommon >= 3,
      AutomationFuelRank.s1Solid => automationShopGradeUpkeep >= 1,
    };
  }
}
