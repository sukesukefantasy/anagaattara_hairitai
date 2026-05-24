import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 事前ベイクしたカバレッジマスク（白 RGB + スプライト α。暗さは含まない）。
final class LightingMaskFrame {
  LightingMaskFrame({
    required this.image,
    required this.localBounds,
    this.ownsImage = true,
  });

  final ui.Image image;
  final Rect localBounds;

  /// false のとき共有 1x1 白（全面マスク用）。
  final bool ownsImage;

  void dispose() {
    if (ownsImage) {
      image.dispose();
    }
  }
}

/// 1 Receiver 分のマスク（静止画 or アニメ各コマ）。
final class LightingMaskAtlas {
  LightingMaskAtlas({
    required this.frames,
    this.isFullRect = false,
    Map<SpriteAnimation, int>? frameBaseByAnimation,
  }) : _frameBaseByAnimation = frameBaseByAnimation;

  final List<LightingMaskFrame> frames;
  final bool isFullRect;
  final Map<SpriteAnimation, int>? _frameBaseByAnimation;

  bool get isReady => frames.isNotEmpty;

  /// 再生中アニメのローカルコマ index をフラット atlas index に変換する。
  int resolveFrameIndex(SpriteAnimation? animation, int localFrameIndex) {
    if (frames.isEmpty) {
      return 0;
    }
    final maxIndex = frames.length - 1;
    if (_frameBaseByAnimation == null || animation == null) {
      return localFrameIndex.clamp(0, maxIndex);
    }
    final base = _frameBaseByAnimation[animation];
    if (base == null) {
      return localFrameIndex.clamp(0, maxIndex);
    }
    return (base + localFrameIndex).clamp(0, maxIndex);
  }

  LightingMaskFrame? frameAt(int index) {
    if (frames.isEmpty) {
      return null;
    }
    if (index < 0 || index >= frames.length) {
      return frames.first;
    }
    return frames[index];
  }

  void dispose() {
    for (final f in frames) {
      f.dispose();
    }
    frames.clear();
  }
}
