import 'package:flame/components.dart';

import '../../../game_manager/time_service.dart';
import '../../../main.dart';
import '../../../scene/abstract_outdoor_scene.dart';
import 'lantern_strip_light_registry.dart';
import 'sun_modulate_mask.dart';

/// ロード後のランタン再ベイク・照明フレーム更新（画面全体暗幕は持たない）。
class LightingBakeCoordinator extends Component with HasGameReference<MyGame> {
  LightingBakeCoordinator({required this.timeService});

  final TimeService timeService;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await SunModulateMask.warmUp();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final scene = game.sceneManager.currentScene;
    if (scene is! AbstractOutdoorScene) {
      return;
    }

    final world = scene.lightingWorld;
    world.beginFrame();
    world.updateFromGame(game);

    LanternStripLightRegistry.instance.tickFrameBakes(game);
  }
}
