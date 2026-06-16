import 'automation_ability_catalog.dart';
import 'automation_fuel.dart';
import 'automation_tool_kind.dart';
import 'automation_tool_placement.dart';
import 'automation_shop_grade.dart';
import 'storage/game_runtime_state.dart';

/// 3種装置の設置・所持・レガシー移行。
extension AutomationToolState on GameRuntimeState {
  static int _placementIdSeq = 0;

  int countPlacements(AutomationToolKind kind, {String? sceneId}) {
    return automationToolPlacements.where((p) {
      if (p.kind != kind) return false;
      if (sceneId != null && p.sceneId != sceneId) return false;
      return true;
    }).length;
  }

  bool canPlaceTool(AutomationToolKind kind) =>
      countPlacements(kind) < AutomationAbilityCatalog.maxPlacementsPerKind;

  bool hasToolPlaced(AutomationToolKind kind) => countPlacements(kind) > 0;

  bool get hasAnyAutomationToolPlaced => automationToolPlacements.isNotEmpty;

  /// レガシー互換
  bool get hasAutomationKitPlaced => hasToolPlaced(AutomationToolKind.upkeep);

  bool ownsPlaceableToolItem(AutomationToolKind kind) {
    if (hunterToolsGranted.contains(kind.toJson())) return true;
    // バッグはランタイムで ItemBag を見る — 呼び出し側で bag を渡す版も用意
    return false;
  }

  bool ownsPlaceableToolItemInBag(String itemName, int count) =>
      count > 0; // プレイヤー側で getItemCount する

  AutomationToolKind? nextHunterToolGrant() {
    for (final k in AutomationToolKind.values) {
      if (!hunterToolsGranted.contains(k.toJson())) return k;
    }
    return null;
  }

  void grantHunterTool(AutomationToolKind kind) {
    if (!hunterToolsGranted.contains(kind.toJson())) {
      hunterToolsGranted.add(kind.toJson());
    }
  }

  String recordAutomationToolPlacement(
    AutomationToolKind kind,
    String sceneId,
    double x,
    double y,
  ) {
    final id = 'tool_${kind.toJson()}_${++_placementIdSeq}_${DateTime.now().millisecondsSinceEpoch}';
    automationToolPlacements.add(
      AutomationToolPlacement(
        instanceId: id,
        kind: kind,
        sceneId: sceneId,
        x: x,
        y: y,
      ),
    );
  if (kind == AutomationToolKind.upkeep && automationKitStage < 1) {
      automationKitStage = 1;
    }
    if (fuelForKind(kind) <= 0) {
      setFuelForKind(kind, AutomationFuel.defaultFuelPerKind);
    }
    saveGame();
    notifyRuntimeChanged();
    return id;
  }

  void removeAutomationToolPlacement(String instanceId) {
    automationToolPlacements.removeWhere((p) => p.instanceId == instanceId);
    saveGame();
    notifyRuntimeChanged();
  }

  List<AutomationToolPlacement> placementsInScene(String sceneId) =>
      automationToolPlacements.where((p) => p.sceneId == sceneId).toList();

  /// 対象星（outdoor_1〜4）間の移動時、設置済み装置を現ステージへ引き継ぐ。
  void syncAutomationToolsToOutdoorScene(String sceneId, double groundFeetY) {
    if (!GameRuntimeState.isTargetStarOutdoorId(sceneId)) return;

    var changed = false;
    automationToolPlacements = automationToolPlacements.map((p) {
      if (!GameRuntimeState.isTargetStarOutdoorId(p.sceneId)) return p;
      if (p.sceneId == sceneId && (p.y - groundFeetY).abs() < 0.5) return p;
      changed = true;
      return AutomationToolPlacement(
        instanceId: p.instanceId,
        kind: p.kind,
        sceneId: sceneId,
        x: p.x,
        y: groundFeetY,
      );
    }).toList();

    if (changed) {
      saveGame();
      notifyRuntimeChanged();
    }
  }

  /// 旧セーブ（単一キット座標）→ 整備ツール1台。
  void migrateLegacyAutomationKitIfNeeded() {
    if (automationToolPlacements.isNotEmpty) return;
    if (automationKitSceneId == null ||
        automationKitPositionX == null ||
        automationKitPositionY == null) {
      return;
    }
    automationToolPlacements.add(
      AutomationToolPlacement(
        instanceId: 'legacy_upkeep',
        kind: AutomationToolKind.upkeep,
        sceneId: automationKitSceneId!,
        x: automationKitPositionX!,
        y: automationKitPositionY!,
      ),
    );
    if (hasReceivedAutomationKitFromHunter) {
      grantHunterTool(AutomationToolKind.upkeep);
    }
    notifyRuntimeChanged();
  }

  /// 旧フラグ → 狩人付与リスト
  void migrateHunterGrantsFromLegacy() {
    if (hasReceivedAutomationKitFromHunter &&
        hunterToolsGranted.isEmpty) {
      grantHunterTool(AutomationToolKind.upkeep);
    }
  }

  /// 既存セーブ互換 — grade ベースの unlock 同期へ委譲。
  void syncUnlocksFromLegacyShopTiers() {
    syncUnlocksFromShopGrades();
  }
}
