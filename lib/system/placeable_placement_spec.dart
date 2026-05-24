import 'dart:async';
import 'dart:ui' show Rect, Size;

import 'package:flame/components.dart';

import '../component/common/physics/physics_body_queries.dart';
import '../component/common/underground/underground.dart';
import '../component/item/item.dart';
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
