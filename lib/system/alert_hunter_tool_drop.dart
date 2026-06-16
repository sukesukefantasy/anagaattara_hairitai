import 'package:flame/components.dart';

import '../component/item/item.dart';
import '../../system/automation_tool_kind.dart';
import '../../system/automation_tool_state.dart';
import '../../system/storage/game_runtime_state.dart';

/// 警戒狩人撃破時の装置付与。
extension AlertHunterToolDrop on GameRuntimeState {
  static const _dropOrder = [
    AutomationToolKind.harvest,
    AutomationToolKind.upkeep,
    AutomationToolKind.ward,
  ];

  AutomationToolKind? nextHunterToolToGrant() {
    for (final k in _dropOrder) {
      if (!hunterToolsGranted.contains(k.toJson())) return k;
    }
    return null;
  }

  void grantToolFromHunter(AutomationToolKind kind) {
    grantHunterTool(kind);
    hasReceivedAutomationKitFromHunter = hunterToolsGranted.isNotEmpty;
    saveGame();
    notifyRuntimeChanged();
  }
}

Item? createAutomationToolItem(AutomationToolKind kind, Vector2 position) {
  return ItemFactory.createItemByName(kind.itemName, position);
}
