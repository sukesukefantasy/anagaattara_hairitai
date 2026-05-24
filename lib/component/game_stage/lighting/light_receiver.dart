import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'lighting_mask_catalog.dart';
import 'lighting_mask_handle.dart';
import 'lighting_participant.dart';
import 'light_receiver_renderer.dart';

/// 光を受けるコンポーネント（マスク + コンポーネント単位 render）。
mixin LightReceiver on PositionComponent, LightingParticipant {
  /// ベイク時に [LightingMaskCatalog] が直接付与（identityHash より確実）。
  LightingMaskAtlas? attachedLightingMaskAtlas;

  LightingMaskAtlas? get lightingMaskAtlas =>
      attachedLightingMaskAtlas ?? LightingMaskCatalog.atlasFor(this);

  /// ロード時ベイク対象の全 [SpriteAnimation]（Player 等）。未指定時は現在のアニメのみ。
  List<SpriteAnimation>? get lightingMaskAnimations => null;

  /// 現在のアニメコマ index（ルート SAC または子 SAC）。
  int get lightingMaskFrameIndex {
    if (this is SpriteAnimationComponent) {
      final sac = this as SpriteAnimationComponent;
      final local = sac.animationTicker?.currentIndex ?? 0;
      final atlas = lightingMaskAtlas;
      if (atlas != null) {
        return atlas.resolveFrameIndex(sac.animation, local);
      }
      return local;
    }
    return _animationFrameIndexInChildren(this) ?? 0;
  }

  static int? _animationFrameIndexInChildren(Component root) {
    int? found;
    void walk(Component node) {
      if (found != null) {
        return;
      }
      if (node is SpriteAnimationComponent) {
        found = node.animationTicker?.currentIndex;
        return;
      }
      for (final child in node.children) {
        walk(child);
      }
    }

    walk(root);
    return found;
  }

  @override
  void onMount() {
    super.onMount();
    if (lightingMaskAtlas != null) {
      return;
    }
    if (LightingMaskCatalog.deferMountBakeFor(this)) {
      return;
    }
    LightingMaskCatalog.bakeAndRegister(this);
  }

  /// [render] 内で `drawContent` の前後に照明を合成する。
  void renderWithComponentLighting(
    Canvas canvas,
    void Function(Canvas canvas) drawContent,
  ) {
    LightReceiverRenderer.renderReceiver(
      canvas: canvas,
      receiver: this,
      participant: this,
      drawContent: drawContent,
      maskFrameIndex: lightingMaskFrameIndex,
    );
  }
}
