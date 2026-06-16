import 'dart:async';
import 'dart:ui' show Rect, Size;

import 'package:flame/components.dart';

import '../component/common/physics/physics_body_queries.dart';
import '../component/common/underground/underground.dart';
import '../component/item/item.dart';
import '../component/game_stage/building/automation/automation_tool_factory.dart';
import '../system/automation_tool_kind.dart';
import '../system/automation_tool_state.dart';
import '../main.dart';
import '../scene/abstract_outdoor_scene.dart';

/// placeable 配置モードの効果定義（家具・地形埋めなど共通）。
abstract class PlaceablePlacementSpec {
  String get itemName;
  String get spritePath;
  Size get previewWorldSize;

  bool canStart(MyGame game);
  bool validate(MyGame game, Rect worldRect);
  bool onConfirm(MyGame game, Rect worldRect);

  /// プレビュー中心のスナップ（地形充填はグリッド揃え）。
  Vector2 snapPreviewCenter(MyGame game, Vector2 raw) => raw;
}

/// 地下の掘削トンネルを岩盤で埋め戻す。
class TerrainFillPlacementSpec extends PlaceablePlacementSpec {
  @override
  final String itemName;

  @override
  final String spritePath;

  @override
  Size get previewWorldSize =>
      const Size(UnderGround.digAreaSize, UnderGround.digAreaSize);

  TerrainFillPlacementSpec({
    required this.itemName,
    required this.spritePath,
  });

  UnderGround? _underGround(MyGame game) {
    final scene = game.sceneManager.currentScene;
    if (scene is! AbstractOutdoorScene) return null;
    return scene.underGround;
  }

  @override
  bool canStart(MyGame game) => game.player.inUnderGround;

  @override
  bool validate(MyGame game, Rect worldRect) {
    final ug = _underGround(game);
    if (ug == null) return false;
    if (!worldRect.overlaps(ug.undergroundBounds)) return false;

    final playerAabb = PhysicsBodyQueries.physicsAabb(game.player);
    if (playerAabb.overlaps(worldRect)) return false;

    return ug.canFillAt(worldRect);
  }

  @override
  Vector2 snapPreviewCenter(MyGame game, Vector2 raw) {
    final ug = _underGround(game);
    if (ug == null) return raw;
    return ug.snapPlacementCenterToGrid(raw);
  }

  @override
  bool onConfirm(MyGame game, Rect worldRect) {
    final ug = _underGround(game);
    if (ug == null) return false;
    return ug.fillSolidRect(worldRect);
  }
}

/// 地下トンネル内に水平床板を設置する。
class FloorPlacementSpec extends PlaceablePlacementSpec {
  @override
  final String itemName;

  @override
  final String spritePath;

  @override
  Size get previewWorldSize => const Size(
        UnderGround.floorSlabWidth,
        UnderGround.floorSlabHeight,
      );

  FloorPlacementSpec({
    required this.itemName,
    required this.spritePath,
  });

  UnderGround? _underGround(MyGame game) {
    final scene = game.sceneManager.currentScene;
    if (scene is! AbstractOutdoorScene) return null;
    return scene.underGround;
  }

  @override
  bool canStart(MyGame game) => game.player.inUnderGround;

  @override
  bool validate(MyGame game, Rect worldRect) {
    final ug = _underGround(game);
    if (ug == null) return false;
    return ug.canPlaceFloorForPlayer(worldRect, game.player);
  }

  @override
  Vector2 snapPreviewCenter(MyGame game, Vector2 raw) {
    final ug = _underGround(game);
    if (ug == null) return raw;
    return ug.snapFloorPreviewCenter(
      raw,
      previewWorldSize.width / 2,
      previewWorldSize.height / 2,
    );
  }

  @override
  bool onConfirm(MyGame game, Rect worldRect) {
    final ug = _underGround(game);
    if (ug == null) return false;
    return ug.addFloor(worldRect);
  }
}

/// グリッドに縛られない家具・ランタン等の自由配置。
/// 確定時にワールドへ実体を出し、重力は無効のまま固定する。
class FurniturePlacementSpec extends PlaceablePlacementSpec {
  @override
  final String itemName;

  @override
  final String spritePath;

  FurniturePlacementSpec({
    required this.itemName,
    required this.spritePath,
  });

  @override
  Size get previewWorldSize {
    final size = ItemFactory.previewSizeForName(itemName);
    if (size == null) return const Size(25, 25);
    return Size(size.x, size.y);
  }

  @override
  bool canStart(MyGame game) => game.player.inUnderGround;

  @override
  bool validate(MyGame game, Rect worldRect) {
    if (game.sceneManager.currentScene == null) return false;
    final playerAabb = PhysicsBodyQueries.physicsAabb(game.player);
    if (playerAabb.overlaps(worldRect)) return false;
    return true;
  }

  @override
  bool onConfirm(MyGame game, Rect worldRect) {
    final pos = Item.positionForWorldRect(worldRect);
    final item = ItemFactory.createPlacedWorldItemByName(itemName, pos);
    if (item == null) return false;

    item.isCollected = true;
    item.physicsBehavior.setEnabled(false);
    game.world.add(item);
    unawaited(_finishFurniturePlacement(game, item));
    return true;
  }

  static Future<void> _finishFurniturePlacement(MyGame game, Item item) async {
    await ItemFactory.applyPlacedWorldItemWorldDisplay(item);
    await ItemFactory.registerPlacedLanternIfNeeded(item, game);
  }
}

/// 対象星の地上に設置する自動化装置（種別ごと max 1）。
class AutomationToolPlacementSpec extends PlaceablePlacementSpec {
  static const Size _toolWorldSize = Size(40, 40);

  final AutomationToolKind toolKind;

  @override
  final String itemName;

  @override
  final String spritePath;

  AutomationToolPlacementSpec({
    required this.toolKind,
    required this.itemName,
    required this.spritePath,
  });

  @override
  Size get previewWorldSize => _toolWorldSize;

  @override
  bool canStart(MyGame game) {
    final state = game.gameRuntimeState;
    if (!state.isOnTargetStarOutdoor) return false;
    if (game.player.inUnderGround) return false;
    if (!state.canPlaceTool(toolKind)) return false;
    return true;
  }

  @override
  bool validate(MyGame game, Rect worldRect) {
    if (game.sceneManager.currentScene is! AbstractOutdoorScene) return false;
    final playerAabb = PhysicsBodyQueries.physicsAabb(game.player);
    if (playerAabb.overlaps(worldRect)) return false;
    return true;
  }

  double? _groundFeetY(MyGame game) {
    final scene = game.sceneManager.currentScene;
    if (scene is! AbstractOutdoorScene) return null;
    final ground = scene.groundComponent;
    if (ground == null) return null;
    return ground.position.y + 2;
  }

  @override
  Vector2 snapPreviewCenter(MyGame game, Vector2 raw) {
    final feetY = _groundFeetY(game);
    if (feetY == null) return raw;
    return Vector2(raw.x, feetY - _toolWorldSize.height / 2);
  }

  @override
  bool onConfirm(MyGame game, Rect worldRect) {
    final scene = game.sceneManager.currentScene;
    if (scene is! AbstractOutdoorScene) return false;

    final feetY = _groundFeetY(game) ?? worldRect.bottom;
    final pos = Vector2(worldRect.center.dx, feetY);
    final id = game.gameRuntimeState.recordAutomationToolPlacement(
      toolKind,
      scene.sceneId,
      pos.x,
      pos.y,
    );
    final tool = createAutomationTool(
      kind: toolKind,
      instanceId: id,
      position: pos,
    );
    scene.add(tool);
    return true;
  }
}
