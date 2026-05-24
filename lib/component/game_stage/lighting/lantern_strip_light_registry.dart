import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../scene/abstract_outdoor_scene.dart';
import '../../item/lantern_item.dart';
import 'light_receiver_renderer.dart';
import 'light_source_entry.dart';
import 'lighting_mask_catalog.dart';
import 'lighting_participant.dart';
import 'lighting_world.dart';

/// 設置ランタンの punch をベイクし、参加者ローカル暗幕ベールに dstOut 合成する。
final class LanternStripLightRegistry {
  LanternStripLightRegistry._();

  static final LanternStripLightRegistry instance = LanternStripLightRegistry._();

  static const double _movementRebakeThreshold = 2.0;
  static const int _maintenanceRebakeIntervalFrames = 12;

  final List<_LanternEntry> _entries = [];
  final Map<_LanternEntry, Future<void>> _entryBakeChains = {};
  int _roundRobinIndex = -1;
  int _nextPlacementIndex = 0;
  int _framesUntilMaintenanceRebake = 0;

  /// 設置直後に punch ベイクを完了するまで待つ。
  Future<void> register(LanternItem lantern, MyGame game) async {
    if (_entries.any((e) => e.lantern == lantern)) {
      return;
    }
    final entry = _LanternEntry(
      lantern: lantern,
      placementIndex: _nextPlacementIndex++,
    );
    _entries.add(entry);
    await _scheduleEntryBake(game, entry, toPending: false);
  }

  void unregister(LanternItem lantern) {
    final index = _entries.indexWhere((e) => e.lantern == lantern);
    if (index < 0) {
      return;
    }
    final entry = _entries[index];
    entry.invalidate();
    entry.dispose();
    _entryBakeChains.remove(entry);
    _entries.removeAt(index);
    if (_entries.isEmpty) {
      _roundRobinIndex = -1;
    } else {
      _roundRobinIndex = _roundRobinIndex.clamp(0, _entries.length - 1);
    }
  }

  /// Ambient punch 用: 登録済み設置ランタンを全件 [LightSourceEntry] 化する。
  List<LightSourceEntry> registeredStripLightEntries({
    required MyGame game,
    required double lanternRadiusScale,
  }) {
    final entries = <LightSourceEntry>[];
    for (final entry in _entries) {
      if (!entry.isAlive) {
        continue;
      }
      final lantern = entry.lantern;
      if (!lantern.isMounted || !lantern.isActive) {
        continue;
      }
      final scale = lantern.usesGlobalRadiusPulse
          ? lanternRadiusScale
          : lantern.radiusScale;
      entries.add(
        LightSourceEntry(
          worldCenter: lantern.worldCenter,
          profile: lantern.profile,
          color: lantern.color,
          radiusScale: scale,
          warmTintStrength: lantern.warmTintStrength,
        ),
      );
    }
    return entries;
  }

  /// [LightingBakeCoordinator] から毎フレーム: 移動検知 + 低頻度メンテナンス再ベイク。
  void tickFrameBakes(MyGame game) {
    tickMovementRebakes(game);
    tickRoundRobinBake(game);
  }

  void tickMovementRebakes(MyGame game) {
    if (_entries.isEmpty) {
      return;
    }
    final scene = game.sceneManager.currentScene;
    if (scene is! AbstractOutdoorScene) {
      return;
    }

    for (final entry in _entries) {
      if (!entry.isAlive || !entry.lantern.isMounted) {
        continue;
      }
      final center = entry.lantern.worldCenter;
      final last = entry.lastBakedWorldCenter;
      if (last == null) {
        continue;
      }
      if (center.distanceTo(last) <= _movementRebakeThreshold) {
        continue;
      }
      entry.clearPending();
      _scheduleEntryBake(
        game,
        entry,
        toPending: entry.cachesByReceiver.isNotEmpty,
      );
    }
  }

  /// 1 フレームに最大 1 灯: 未ベイク灯の追い込み、または既存灯の pending 更新。
  void tickRoundRobinBake(MyGame game) {
    if (_entries.isEmpty) {
      return;
    }
    final scene = game.sceneManager.currentScene;
    if (scene is! AbstractOutdoorScene) {
      return;
    }

    _roundRobinIndex = (_roundRobinIndex + 1) % _entries.length;
    final entry = _entries[_roundRobinIndex];
    if (!entry.isAlive || !entry.lantern.isMounted) {
      return;
    }

    if (entry.cachesByReceiver.isEmpty) {
      _scheduleEntryBake(game, entry, toPending: false);
      return;
    }

    if (_framesUntilMaintenanceRebake > 0) {
      _framesUntilMaintenanceRebake--;
      return;
    }
    _framesUntilMaintenanceRebake = _maintenanceRebakeIntervalFrames;

    entry.clearPending();
    _scheduleEntryBake(game, entry, toPending: true);
  }

  /// 設置済みランタン全件のベイク punch を描画。
  void drawBakedPunches({
    required Canvas canvas,
    required PositionComponent receiver,
    required Rect boundsRect,
  }) {
    final receiverId = identityHashCode(receiver);
    for (final entry in _entries) {
      if (!entry.isAlive) {
        continue;
      }
      final bake = entry.cachesByReceiver[receiverId];
      if (bake == null || bake.poolRect.isEmpty) {
        continue;
      }
      if (!boundsRect.overlaps(bake.poolRect)) {
        continue;
      }
      LightReceiverRenderer.drawBakedPunchMask(
        canvas: canvas,
        poolRect: bake.poolRect,
        punchMask: bake.punchMask,
      );
    }
  }

  /// 灯ごとに直列・灯同士は並行。register はこの Future の完了を await する。
  Future<void> _scheduleEntryBake(
    MyGame game,
    _LanternEntry entry, {
    required bool toPending,
  }) {
    if (!entry.isAlive) {
      return Future.value();
    }
    final scene = game.sceneManager.currentScene;
    if (scene is! AbstractOutdoorScene) {
      return Future.value();
    }

    final bakeGeneration = entry.generation;
    final scheduled = (_entryBakeChains[entry] ?? Future.value()).then((_) async {
      if (!entry.isAlive || entry.generation != bakeGeneration) {
        return;
      }
      await _bakeEntry(
        game,
        scene,
        entry,
        toPending: toPending,
        bakeGeneration: bakeGeneration,
      );
      if (toPending &&
          entry.isAlive &&
          entry.generation == bakeGeneration) {
        entry.commitPending();
      }
    });
    _entryBakeChains[entry] = scheduled;
    return scheduled;
  }

  Future<void> _bakeEntry(
    MyGame game,
    AbstractOutdoorScene scene,
    _LanternEntry entry, {
    required bool toPending,
    required int bakeGeneration,
  }) async {
    if (!entry.isAlive || entry.generation != bakeGeneration) {
      return;
    }

    final lantern = entry.lantern;
    if (!lantern.isMounted) {
      return;
    }

    try {
      await lantern.loaded;
    } catch (_) {
      return;
    }
    if (!entry.isAlive || entry.generation != bakeGeneration) {
      return;
    }
    if (!lantern.isMounted) {
      return;
    }

    if (lantern.lightingMaskAtlas == null ||
        !lantern.lightingMaskAtlas!.isReady) {
      await LightingMaskCatalog.bakeAndRegister(lantern);
    }

    final lightingWorld = scene.lightingWorld;
    final ambientBase = lightingWorld.sunState.ambientBrightness;
    if (ambientBase <= 0.001) {
      return;
    }

    final receivers = LightingParticipantBounds.collectFullParticipants(game);
    if (receivers.isEmpty) {
      return;
    }

    var wroteAnyCache = false;
    for (final receiver in receivers) {
      if (!entry.isAlive || entry.generation != bakeGeneration) {
        return;
      }

      final depthFactor = receiver is LightingParticipant
          ? lightingReceiverDepthFactor(
              participant: receiver,
              component: receiver,
              emitters: [lantern],
            )
          : 1.0;
      if (depthFactor <= 0.01) {
        continue;
      }

      final boundsRect = Rect.fromLTWH(0, 0, receiver.size.x, receiver.size.y);
      final poolRect = LightReceiverRenderer.stripLanternPoolRect(
        receiver: receiver,
        boundsRect: boundsRect,
        emitter: lantern,
      );
      if (poolRect.isEmpty) {
        continue;
      }

      final masks = await LightReceiverRenderer.bakeStripLanternPunchMask(
        receiver: receiver,
        poolRect: poolRect,
        emitter: lantern,
        ambientBase: ambientBase,
        depthFactor: depthFactor,
      );
      if (!entry.isAlive || entry.generation != bakeGeneration) {
        masks?.dispose();
        return;
      }
      if (masks == null) {
        continue;
      }

      final receiverId = identityHashCode(receiver);
      final target = toPending
          ? entry.pendingCachesByReceiver
          : entry.cachesByReceiver;
      target[receiverId]?.dispose();
      target[receiverId] = _ReceiverBake(
        poolRect: poolRect,
        punchMask: masks.punchMask,
      );
      wroteAnyCache = true;
    }

    if (wroteAnyCache) {
      entry.lastBakedWorldCenter = lantern.worldCenter.clone();
    }
  }
}

final class _LanternEntry {
  _LanternEntry({
    required this.lantern,
    required this.placementIndex,
  });

  final LanternItem lantern;
  final int placementIndex;
  int generation = 0;
  bool _disposed = false;

  final Map<int, _ReceiverBake> cachesByReceiver = {};
  final Map<int, _ReceiverBake> pendingCachesByReceiver = {};
  Vector2? lastBakedWorldCenter;

  bool get isAlive => !_disposed;

  void invalidate() {
    generation++;
  }

  void clearPending() {
    for (final cache in pendingCachesByReceiver.values) {
      cache.dispose();
    }
    pendingCachesByReceiver.clear();
  }

  void commitPending() {
    for (final entry in pendingCachesByReceiver.entries) {
      cachesByReceiver[entry.key]?.dispose();
      cachesByReceiver[entry.key] = entry.value;
    }
    pendingCachesByReceiver.clear();
  }

  void dispose() {
    _disposed = true;
    invalidate();
    for (final cache in cachesByReceiver.values) {
      cache.dispose();
    }
    cachesByReceiver.clear();
    clearPending();
  }
}

final class _ReceiverBake {
  _ReceiverBake({
    required this.poolRect,
    this.punchMask,
  });

  final Rect poolRect;
  final ui.Image? punchMask;

  void dispose() {
    punchMask?.dispose();
  }
}
