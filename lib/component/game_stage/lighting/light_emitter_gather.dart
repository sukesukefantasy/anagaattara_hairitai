import 'package:flame/components.dart';

import '../../../main.dart';
import '../../item/item.dart';
import 'light_emitter.dart';
import 'lighting_quality.dart';
import 'light_source_entry.dart';

/// シーン／ワールドから [LightEmitter] を収集して [LightSourceEntry] 化する。
abstract final class LightEmitterGather {
  LightEmitterGather._();

  static List<LightSourceEntry> gatherActiveLights(
    MyGame game, {
    double globalRadiusPulseScale = 1.0,
  }) {
    if (game.sceneManager.currentScene == null) {
      return const [];
    }

    final entries = <LightSourceEntry>[];
    final seen = <int>{};
    final carried = game.player.carriedItem;

    void addEmitter(LightEmitter emitter, {bool toFront = false}) {
      if (!emitter.isActive) {
        return;
      }
      final id = identityHashCode(emitter);
      if (seen.contains(id)) {
        return;
      }
      seen.add(id);

      final scale = emitter.usesGlobalRadiusPulse
          ? globalRadiusPulseScale
          : emitter.radiusScale;

      final entry = LightSourceEntry(
        worldCenter: emitter.worldCenter,
        profile: emitter.profile,
        color: emitter.color,
        radiusScale: scale,
        warmTintStrength: emitter.warmTintStrength,
      );
      if (toFront) {
        entries.insert(0, entry);
      } else {
        entries.add(entry);
      }
    }

    void walk(Component root) {
      if (root is LightEmitter) {
        final emitter = root as LightEmitter;
        if (identical(emitter, carried)) {
          return;
        }
        if (root is Item && !root.isCollected) {
          return;
        }
        addEmitter(emitter);
      }
      for (final child in root.children) {
        walk(child);
      }
    }

    walk(game.sceneManager.currentScene!);
    walk(game.world);

    if (carried is LightEmitter) {
      final emitter = carried as LightEmitter;
      if (emitter.isActive) {
        addEmitter(emitter, toFront: true);
      }
    }

    final sortOrigin = game.player.absoluteCenter;
    entries.sort((a, b) {
      final distA = a.worldCenter.distanceTo(sortOrigin);
      final distB = b.worldCenter.distanceTo(sortOrigin);
      return distA.compareTo(distB);
    });

    final maxLights = LightingConfig.maxActiveLights;
    if (entries.length > maxLights) {
      entries.removeRange(maxLights, entries.length);
    }

    return entries;
  }
}
