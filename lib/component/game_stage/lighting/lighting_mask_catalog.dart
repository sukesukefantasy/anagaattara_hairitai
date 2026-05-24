import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import '../../../main.dart';
import '../../../scene/abstract_outdoor_scene.dart';
import '../../common/ground/ground.dart';
import '../../common/underground/underground.dart';
import '../gamestage_component.dart';
import 'light_receiver.dart';
import 'lighting_mask_builder.dart';
import 'lighting_mask_handle.dart';
import 'lighting_participant.dart';
import 'sky_component.dart';

/// [bakeScene] の結果（必須マスク検証含む）。
final class LightingMaskBakeResult {
  const LightingMaskBakeResult({
    required this.success,
    this.missingLabels = const [],
  });

  final bool success;
  final List<String> missingLabels;
}

/// ロード時にベイクしたマスクのカタログ。
abstract final class LightingMaskCatalog {
  LightingMaskCatalog._();

  static final Map<int, LightingMaskAtlas> _atlasesById = {};
  static final Map<int, WeakReference<PositionComponent>> _owners = {};
  static bool _sceneBakeComplete = false;

  /// ロード時一括ベイク完了後は、動的スポーンは onMount で個別ベイクする。
  static bool get sceneBakeComplete => _sceneBakeComplete;

  static LightingMaskAtlas? atlasFor(PositionComponent component) {
    return _atlasesById[identityHashCode(component)];
  }

  static void registerOwner(PositionComponent component, LightingMaskAtlas atlas) {
    final id = identityHashCode(component);
    _atlasesById[id]?.dispose();
    _atlasesById[id] = atlas;
    _owners[id] = WeakReference(component);
    if (component is LightReceiver) {
      component.attachedLightingMaskAtlas = atlas;
    }
  }

  /// [bakeScene] でまとめてベイクする静的 Receiver は onMount 個別ベイクを抑止。
  static bool deferMountBakeFor(PositionComponent component) {
    return !_sceneBakeComplete && component is LightReceiver;
  }

  static void unregister(PositionComponent component) {
    final id = identityHashCode(component);
    _atlasesById.remove(id)?.dispose();
    _owners.remove(id);
    if (component is LightReceiver) {
      component.attachedLightingMaskAtlas = null;
    }
  }

  static Future<LightingMaskBakeResult> bakeScene(
    MyGame game, {
    void Function(double progress, String message)? onProgress,
  }) async {
    clearAll();
    _sceneBakeComplete = false;
    onProgress?.call(0, 'マスク生成を準備中…');

    final receivers = <PositionComponent>[];
    void walk(Component node) {
      if (node is PositionComponent && node.isMounted) {
        if (node is SkyComponent || _shouldBake(node)) {
          receivers.add(node);
        }
      }
      for (final child in node.children) {
        walk(child);
      }
    }

    final scene = game.sceneManager.currentScene;
    if (scene != null) {
      walk(scene);
    }
    walk(game.world);

    final total = receivers.length;
    if (total == 0) {
      onProgress?.call(1, 'マスク生成完了');
      _sceneBakeComplete = true;
      return const LightingMaskBakeResult(success: true);
    }

    for (var i = 0; i < total; i++) {
      final component = receivers[i];
      onProgress?.call(
        (i + 1) / total,
        'マスク生成中 (${i + 1}/$total)',
      );

      try {
        await _generateReceiverMask(component, game);
      } catch (e, st) {
        debugPrint(
          'LightingMaskCatalog: mask generate failed for ${component.runtimeType}: $e\n$st',
        );
      }
    }

    onProgress?.call(0.95, 'マスクを検証中…');
    var missing = _missingRequiredSilhouetteLabels(game);
    if (missing.isNotEmpty) {
      onProgress?.call(0.96, 'マスク再生成中…');
      for (final label in List<String>.from(missing)) {
        final component = _requiredComponentForLabel(game, label);
        if (component == null) {
          continue;
        }
        try {
          unregister(component);
          await _generateReceiverMask(component, game);
        } catch (e, st) {
          debugPrint(
            'LightingMaskCatalog: retry failed for $label: $e\n$st',
          );
        }
      }
      missing = _missingRequiredSilhouetteLabels(game);
    }

    final loopStage = _firstLoopGameStage(game);
    if (loopStage != null && !_hasSilhouetteMaskReady(loopStage)) {
      missing = [...missing, 'LoopGameStage'];
    }

    _sceneBakeComplete = true;
    if (missing.isEmpty) {
      onProgress?.call(1, 'マスク生成完了');
      return const LightingMaskBakeResult(success: true);
    }

    final message = 'マスク未完了: ${missing.join(', ')}';
    onProgress?.call(1, message);
    debugPrint('LightingMaskCatalog: $message');
    return LightingMaskBakeResult(success: false, missingLabels: missing);
  }

  static Future<void> _generateReceiverMask(
    PositionComponent component,
    MyGame game,
  ) async {
    if (component is SkyComponent) {
      final atlas = await LightingMaskBuilder.buildFullRectMask(
        component.size,
      );
      registerOwner(component, atlas);
      return;
    }

    if (component is GameStageComponent) {
      final atlas = component.loop
          ? await LightingMaskBuilder.generateLoopGameStageMask(
              component,
              game,
            )
          : await LightingMaskBuilder.buildGameStageMask(component);
      if (atlas != null) {
        registerOwner(component, atlas);
      }
      return;
    }

    if (component is Ground) {
      final atlas = await LightingMaskBuilder.generateGroundMask(
        component,
        game,
      );
      if (atlas != null) {
        registerOwner(component, atlas);
      }
      return;
    }

    if (component is UnderGround) {
      final atlas = await LightingMaskBuilder.generateUnderGroundMask(component);
      if (atlas != null) {
        registerOwner(component, atlas);
      }
      return;
    }

    final animations = component is LightReceiver
        ? component.lightingMaskAnimations
        : null;
    final atlas = await LightingMaskBuilder.buildAtlas(
      component,
      animations: animations,
    );
    if (atlas != null) {
      registerOwner(component, atlas);
    }
  }

  static GameStageComponent? _firstLoopGameStage(MyGame game) {
    final scene = game.sceneManager.currentScene;
    if (scene == null) {
      return null;
    }
    for (final child in scene.children) {
      if (child is GameStageComponent && child.loop) {
        return child;
      }
    }
    return null;
  }

  static List<({PositionComponent component, String label})>
      _requiredSilhouetteMasks(MyGame game) {
    final required = <({PositionComponent component, String label})>[
      (component: game.player, label: 'Player'),
    ];
    final scene = game.sceneManager.currentScene;
    if (scene is AbstractOutdoorScene) {
      final ground = scene.ground;
      if (ground != null && ground.isMounted) {
        required.add((component: ground, label: 'Ground'));
      }
      final under = scene.underGround;
      if (under.isMounted) {
        required.add((component: under, label: 'UnderGround'));
      }
    }
    return required;
  }

  static PositionComponent? _requiredComponentForLabel(
    MyGame game,
    String label,
  ) {
    for (final entry in _requiredSilhouetteMasks(game)) {
      if (entry.label == label) {
        return entry.component;
      }
    }
    return null;
  }

  static List<String> _missingRequiredSilhouetteLabels(MyGame game) {
    final missing = <String>[];
    for (final entry in _requiredSilhouetteMasks(game)) {
      if (!_hasSilhouetteMaskReady(entry.component)) {
        missing.add(entry.label);
      }
    }
    return missing;
  }

  static bool _hasSilhouetteMaskReady(PositionComponent component) {
    final atlas = component is LightReceiver
        ? (component.lightingMaskAtlas ?? atlasFor(component))
        : atlasFor(component);
    return atlas != null && atlas.isReady && !atlas.isFullRect;
  }

  static bool _shouldBake(PositionComponent component) {
    if (component is SpriteComponent ||
        component is SpriteAnimationComponent) {
      return true;
    }
    if (component is LightingParticipant) {
      return true;
    }
    return _containsSprite(component);
  }

  static bool _containsSprite(Component root) {
    if (root is SpriteComponent || root is SpriteAnimationComponent) {
      return true;
    }
    for (final child in root.children) {
      if (_containsSprite(child)) {
        return true;
      }
    }
    return false;
  }

  static void clearAll() {
    _sceneBakeComplete = false;
    LightingMaskBuilder.disposeSharedResources();
    for (final ref in _owners.values) {
      final owner = ref.target;
      if (owner is LightReceiver) {
        owner.attachedLightingMaskAtlas = null;
      }
    }
    for (final atlas in _atlasesById.values) {
      atlas.dispose();
    }
    _atlasesById.clear();
    _owners.clear();
  }

  /// 動的スポーン用: 1 コンポーネントだけマスク生成して登録。
  static Future<void> bakeAndRegister(PositionComponent component) async {
    if (component case final HasGameReference<MyGame> ref) {
      await _generateReceiverMask(component, ref.game);
      return;
    }
    if (component is SkyComponent) {
      registerOwner(
        component,
        await LightingMaskBuilder.buildFullRectMask(component.size),
      );
    }
  }
}
