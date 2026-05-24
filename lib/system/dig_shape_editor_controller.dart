import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../component/common/terrain/dig_shape_template.dart';
import '../main.dart';

/// 掘削断面エディタの状態。
class DigShapeEditorController {
  final ValueNotifier<bool> isActive = ValueNotifier(false);
  final ValueNotifier<int> previewTick = ValueNotifier(0);

  final List<Vector2> _drawPointsNormalized = [];
  DigShapeTemplate? _presetTemplate;
  int? _selectedPresetIndex;

  List<Vector2> get drawPointsNormalized =>
      List<Vector2>.unmodifiable(_drawPointsNormalized);

  int? get selectedPresetIndex => _selectedPresetIndex;
  bool get isFreehandMode => _selectedPresetIndex == null;

  /// キャンバス上のプレビュー用（手書き > 選択プリセット）。
  DigShapeTemplate? get previewTemplate {
    final drawn = DigShapeTemplate.fromNormalizedDrawPoints(
      _drawPointsNormalized,
    );
    if (drawn != null) return drawn;
    return _presetTemplate;
  }

  late MyGame _game;

  void bind(MyGame game) => _game = game;

  bool start(MyGame game) {
    bind(game);
    if (!game.player.inUnderGround) return false;
    _drawPointsNormalized.clear();
    _presetTemplate = null;
    _selectedPresetIndex = null;
    isActive.value = true;
    previewTick.value++;
    return true;
  }

  void addDrawPointNormalized(Vector2 point) {
    if (_drawPointsNormalized.isNotEmpty) {
      final last = _drawPointsNormalized.last;
      final dx = point.x - last.x;
      final dy = point.y - last.y;
      if (dx * dx + dy * dy < 0.0004) return;
    }
    _selectedPresetIndex = null;
    _presetTemplate = null;
    _drawPointsNormalized.add(point);
    previewTick.value++;
  }

  void selectPreset(int index) {
    final presets = DigShapeTemplate.builtInPresets;
    if (index < 0 || index >= presets.length) return;
    _selectedPresetIndex = index;
    _presetTemplate = presets[index].build();
    _drawPointsNormalized.clear();
    previewTick.value++;
  }

  void useFreehand() {
    _selectedPresetIndex = null;
    _presetTemplate = null;
    previewTick.value++;
  }

  void clearDraw() {
    _drawPointsNormalized.clear();
    _presetTemplate = null;
    _selectedPresetIndex = null;
    previewTick.value++;
  }

  void cancel() {
    _drawPointsNormalized.clear();
    _presetTemplate = null;
    _selectedPresetIndex = null;
    isActive.value = false;
    previewTick.value++;
  }

  /// カスタム型を確定して保存。
  bool confirm() {
    final template = previewTemplate;
    if (template == null) {
      _game.windowManager.showDialog([
        '形を選ぶか、ドラッグで描いてください。',
      ]);
      return false;
    }
    final err = template.validate();
    if (err != null) {
      _game.windowManager.showDialog([err]);
      return false;
    }
    _game.gameRuntimeState.digShapeTemplate = template;
    _game.gameRuntimeState.saveGame();
    cancel();
    _game.windowManager.showDialog(['掘削の型を保存しました。']);
    return true;
  }

  /// 既定の円形掘削に戻す（カスタム型を解除）。
  bool restoreDefaultShape() {
    _game.gameRuntimeState.digShapeTemplate = null;
    _game.gameRuntimeState.saveGame();
    cancel();
    _game.windowManager.showDialog(['元の円形掘削に戻しました。']);
    return true;
  }
}
