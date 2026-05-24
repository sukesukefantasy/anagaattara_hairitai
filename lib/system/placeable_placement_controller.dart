import 'dart:ui' show Rect;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../main.dart';
import 'placeable_placement_spec.dart';

/// バッグから開始する placeable 配置モードの状態。
class PlaceablePlacementController {
  final ValueNotifier<bool> isActive = ValueNotifier(false);
  final ValueNotifier<int> previewTick = ValueNotifier(0);

  PlaceablePlacementSpec? _spec;
  Vector2 _previewWorldCenter = Vector2.zero();

  PlaceablePlacementSpec? get spec => _spec;
  Vector2 get previewWorldCenter => _previewWorldCenter;

  Rect previewWorldRect(PlaceablePlacementSpec activeSpec) {
    final halfW = activeSpec.previewWorldSize.width / 2;
    final halfH = activeSpec.previewWorldSize.height / 2;
    return Rect.fromLTRB(
      _previewWorldCenter.x - halfW,
      _previewWorldCenter.y - halfH,
      _previewWorldCenter.x + halfW,
      _previewWorldCenter.y + halfH,
    );
  }

  bool get canConfirm {
    final active = _spec;
    if (active == null) return false;
    return active.validate(_game, previewWorldRect(active));
  }

  late MyGame _game;

  void bind(MyGame game) => _game = game;

  bool start(MyGame game, PlaceablePlacementSpec newSpec) {
    bind(game);
    if (!newSpec.canStart(game)) {
      return false;
    }
    _spec = newSpec;
    _previewWorldCenter = newSpec.snapPreviewCenter(
      game,
      game.player.absoluteCenter.clone(),
    );
    isActive.value = true;
    previewTick.value++;
    return true;
  }

  void updatePreviewWorldCenter(Vector2 worldCenter) {
    final active = _spec;
    _previewWorldCenter = active != null
        ? active.snapPreviewCenter(_game, worldCenter)
        : worldCenter;
    previewTick.value++;
  }

  void cancel() {
    _spec = null;
    isActive.value = false;
    previewTick.value++;
  }

  bool confirm() {
    final active = _spec;
    if (active == null) return false;
    final rect = previewWorldRect(active);
    if (!active.validate(_game, rect)) {
      _game.windowManager.showDialog(['ここには置けません。']);
      return false;
    }
    if (!active.onConfirm(_game, rect)) {
      _game.windowManager.showDialog(['ここには置けません。']);
      return false;
    }

    _game.itemBag.removeItem(active.itemName, count: 1);
    _game.gameRuntimeState.codexIncrementItemUsed(active.itemName);
    cancel();
    return true;
  }
}
