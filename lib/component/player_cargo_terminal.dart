import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../scene/abstract_outdoor_scene.dart';
import 'effect/residue_effect.dart';
import 'common/hitboxes/interact_hitbox.dart';
import 'game_stage/lighting/lighting_participant.dart';
import 'game_stage/lighting/lighting_participation.dart';

/// ステージに固定配置されるカーゴ端末。
/// プレイヤーが接近してインタラクトすることで資源蓄積UIを開く。
class PlayerCargoTerminal extends PositionComponent
    with HasGameReference<MyGame>, LightingParticipant {
  @override
  LightingParticipation get lightingParticipation => LightingParticipation.full;

  late SpriteSheet spriteSheet;
  
  /// 各レイヤーのコンポーネント
  late SpriteComponent _coreBase;
  late SpriteComponent _coreOverlay;
  late SpriteComponent _exterior;
  late SpriteAnimationComponent _propulsion;

  /// 推進アニメーション（待機用・低速）
  late SpriteAnimation _idlePropulsion;
  /// 推進アニメーション（射出用・高速）
  late SpriteAnimation _launchPropulsion;

  bool _isLaunching = false;
  double _velocity = 0.0;
  final double _acceleration = 800.0; // 射出時の加速度 (px/s^2)
  double _launchTimer = 0.0;

  PlayerCargoTerminal()
      : super(
          size: Vector2.zero(),
          priority: 51,
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final cargoImage = await game.images.load('cargo.png');
    // 230x45, 5フレーム => 1フレーム 46x45
    spriteSheet = SpriteSheet.fromColumnsAndRows(
      image: cargoImage,
      columns: 5,
      rows: 1,
    );
    final frameSize = Vector2(46, 45);
    size.setFrom(frameSize);

    // 1. コア基部 (Frame 0)
    _coreBase = SpriteComponent(
      sprite: spriteSheet.getSprite(0, 0),
      size: frameSize,
    );
    add(_coreBase);

    // 2. コア上層 (Frame 1)
    _coreOverlay = SpriteComponent(
      sprite: spriteSheet.getSprite(0, 1),
      size: frameSize,
    );
    add(_coreOverlay);

    // 3. 外装 (Frame 2)
    _exterior = SpriteComponent(
      sprite: spriteSheet.getSprite(0, 2),
      size: frameSize,
    );
    _exterior.opacity = 0.0;
    add(_exterior);

    // 4. 推進アニメーション (Frame 3-4)
    _idlePropulsion = SpriteAnimation.fromFrameData(
      cargoImage,
      SpriteAnimationData.sequenced(
        amount: 2,
        stepTime: 0.2,
        textureSize: frameSize,
        texturePosition: Vector2(3 * frameSize.x, 0),
        loop: true,
      ),
    );

    _launchPropulsion = SpriteAnimation.fromFrameData(
      cargoImage,
      SpriteAnimationData.sequenced(
        amount: 2,
        stepTime: 0.05,
        textureSize: frameSize,
        texturePosition: Vector2(3 * frameSize.x, 0),
        loop: true,
      ),
    );

    _propulsion = SpriteAnimationComponent(
      animation: _idlePropulsion,
      size: frameSize,
    );
    add(_propulsion);

    // インタラクト判定を追加
    add(
      InteractHitbox(
        onInteract: () => showCargoDialog(),
        size: frameSize + Vector2(20, 20),
        position: Vector2.zero(),
        anchor: Anchor.center,
        icon: Icons.hub_outlined,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_isLaunching) {
      // 加速しながら上昇
      _velocity += _acceleration * dt;
      position.y -= _velocity * dt;
      _launchTimer += dt;

      // 5秒経過、または画面外（上方向）に十分出たらリセット
      if (_launchTimer > 5.0 || position.y < -1000) {
        _isLaunching = false;
        _propulsion.animation = _idlePropulsion;
        _exterior.opacity = 0.0;
        // 固定配置なので位置は戻さない（またはリセットが必要ならここで）
      }
      return;
    }
  }

  /// UIボタンから呼び出す公開メソッド
  void showCargoDialog() {
    game.windowManager.showCargoTransfer(game, this);
  }

  /// UIから射出を実行する
  void invokeLaunchFromUI() {
    _launchCargo();
  }

  void _launchCargo() {
    final state = game.gameRuntimeState;
    final batchLife = state.cargoLifeCount;
    final batchHist = state.cargoHistoryCount;
    final batchIno = state.cargoInorganicCount;
    final batchTotal = state.totalCargoResidueCount;
    final batchPctLife = batchTotal > 0 ? (batchLife / batchTotal * 100).round() : 0;
    final batchPctHist = batchTotal > 0 ? (batchHist / batchTotal * 100).round() : 0;
    final batchPctIno = batchTotal > 0 ? (batchIno / batchTotal * 100).round() : 0;

    state.launchCargo(); // isCargoLaunched = true もここで設定される

    // 射出演出開始
    _isLaunching = true;
    _velocity = 0.0;
    _launchTimer = 0.0;
    _propulsion.animation = _launchPropulsion;
    _exterior.opacity = 1.0;

    // 残滓エフェクト（全種類を爆発的に漏出させる）
    ResidueEffect.spawnLife(game, game.player.absolutePosition.clone(), count: 12);
    ResidueEffect.spawnHistory(game, game.player.absolutePosition.clone(), count: 6);
    ResidueEffect.spawnInorganic(game, game.player.absolutePosition.clone(), count: 12);

    // 射出後に電車を呼ぶ
    final scene = game.sceneManager.currentScene;
    if (scene is AbstractOutdoorScene) {
      scene.spawnTrain();
    }

    // フィードバックダイアログ（資源傾向によって変化）
    final sentLife = state.sentLifeResourceCount;
    final sentHistory = state.sentHistoryResourceCount;
    final sentInorganic = state.sentInorganicResourceCount;

    List<String> messages;
    if (sentLife > sentHistory && sentLife > sentInorganic) {
      messages = [
        '残滓は母星へ向かった。',
      ];
    } else if (sentHistory > sentLife && sentHistory > sentInorganic) {
      messages = [
        '残滓は母星へ向かった。',
      ];
    } else {
      messages = [
        '残滓は母星へ向かった。',
      ];
    }

    if (state.disclosureTier >= 1) {
      messages.add(
        '〔開示：${state.disclosureTier >= 2 ? "終盤" : "中途"}〕通信にノイズが混じり始めた。',
      );
    }

    messages.add(
      '母星人間性: ${state.homePlanetHumanity.toStringAsFixed(0)} / 100（射出後）',
    );

    game.windowManager.showDialog(messages);
  }
}
