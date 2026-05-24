import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' show lerpDouble;
import '../main.dart';
import '../UI/game_ui.dart';
import 'game_stage/building/station.dart';
import 'common/physics/kinematic_movement.dart';
import 'common/physics/knockback_config.dart';
import 'common/physics/entity_physics_mixin.dart';
import 'common/physics/physics_body_queries.dart';
import 'common/physics/physics_step_obstacle.dart';
import 'common/physics/small_step_traversal.dart';
import 'common/collision/collision_family.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'game_stage/building/destructible_object.dart';
import 'game_stage/building/hideable_object.dart';
import 'effect/hiding_vignette.dart';
import 'item/item_bag.dart';
import 'item/item.dart';
import '../scene/abstract_outdoor_scene.dart'; // AbstractOutdoorSceneをインポート
import 'enemy/enemy_base.dart';
import 'common/terrain/terrain_field.dart';
import '../game_manager/audio_manager.dart'; // Add this line
import '../system/storage/game_runtime_state.dart'; // GameRuntimeStateをインポート
import 'npc/npc.dart';
import '../component/effect/hp_low_effect.dart';
import '../component/effect/drowsiness_effect.dart';
import 'game_stage/lighting/light_receiver.dart';
import 'game_stage/lighting/lighting_participation.dart';
import 'game_stage/lighting/lighting_participant.dart';
import '../component/effect/residue_effect.dart'; // Add this line
import 'effect/residue_pickup.dart';
import 'player_cargo_terminal.dart';

enum PlayerState { idle, walking, jumping, digging, falling }

class CurrencyNotifier extends ChangeNotifier {
  int _value;
  int get value => _value;

  CurrencyNotifier(this._value);

  void update(int income) {
    _value += income;
    if (_value < 0) {
      _value = 0;
    }
    notifyListeners();
  }
}

class MiningPointsNotifier extends ChangeNotifier {
  int _value;
  int get value => _value;

  MiningPointsNotifier(this._value);

  void update(int income) {
    _value += income;
    if (_value < 0) {
      _value = 0;
    }
    notifyListeners();
  }
}

class Player extends SpriteAnimationComponent
    with
        CollisionCallbacks,
        HasGameReference<MyGame>,
        HasCollisionFamily,
        LightingParticipant,
        LightReceiver {
  @override
  CollisionFamily get collisionFamily => CollisionFamily.player;

  @override
  LightingParticipation get lightingParticipation =>
      LightingParticipation.full;

  @override
  List<SpriteAnimation> get lightingMaskAnimations => [
    idleFrontAnimation,
    idleLeftAnimation,
    idleRightAnimation,
    movingLeftAnimation,
    movingRightAnimation,
    jumpingAnimation,
    jumpingLeftAnimation,
    jumpingRightAnimation,
    fallingAnimation,
    crouchingAnimation,
    diggingAnimation,
  ];

  static const double speed = 180.0;
  /// プレイヤーの質量（ノックバック等の物理計算に使用）。
  static const double mass = KnockbackConfig.playerMass;
  static const double powerOfPlayer = 1.25;
  static const double gravity = 700.0;
  static const double maxFallSpeed = 1400.0;
  static const double jumpForce = -250.0; // 少し弱める
  static const double maxJumpTime = 0.25; // ジャンプ持続時間の最大値

  // 属性による能力強化の計算
  double get effectiveSpeed {
    final state = game.gameRuntimeState;

    double base = speed;

    // 周回ボーナス（キャリブレーション適用）
    base *= (1.0 + (state.movementSpeedBonus - 1.0) * state.speedCalibrationScale);

    // 警戒度による「引力体感」への影響：移動速度上昇（1.0 につきおよそ 10%）
    base *= (1.0 + (state.starAlertLevel * 0.1));

    return base;
  }

  double get effectiveGravity {
    final state = game.gameRuntimeState;

    double base = gravity;

    // 投擲強化ボーナスを重力軽減に転用（キャリブレーション適用）
    double philosophyEffect = (state.throwPowerBonus - 1.0) * state.powerCalibrationScale;
    base *= (1.0 - (philosophyEffect * 0.5));

    // 警戒度による「引力体感」への影響：重力軽減（1.0 につきおよそ 15%）
    base *= (1.0 - (state.starAlertLevel * 0.15)).clamp(0.1, 1.0);

    // シーンによる重力倍率の適用
    final currentScene = game.sceneManager.currentScene;
    if (currentScene is AbstractOutdoorScene) {
      base *= currentScene.gravityMultiplier;
    }

    return base;
  }

  double get effectiveMeleeSizeScale {
    final state = game.gameRuntimeState;

    double bonusScale = 1.0;
    // HPボーナスの一部を体格（攻撃範囲）に反映
    bonusScale += (state.hpBonus / 1000.0) * state.hpCalibrationScale;

    return bonusScale;
  }

  double get vacuumRange {
    final state = game.gameRuntimeState;

    double range = 0.0;

    // キャリブレーションによる調整（移動ボーナスが溜まっている場合）
    range += (state.movementSpeedBonus - 1.0) * 200 * state.speedCalibrationScale;

    return range;
  }

  bool isJumpButtonPressed = false;
  double _jumpTime = 0.0;
  bool _isJumping = false;

  bool isHiding = false;
  HideableObject? hidingSpot;
  HidingVignette? _hidingVignette;

  bool unbeatable = false;

  DrowsinessEffect? _drowsinessEffect;

  // 耐久力（Integrity）の変更を通知するためのValueNotifier
  final ValueNotifier<double> integrityNotifier = ValueNotifier<double>(1000.0);
  double get maxIntegrity => gameRuntimeState.maxIntegrity;
  double get currentIntegrity => integrityNotifier.value;

  // 外的刺激（Stress）の変更を通知するためのValueNotifier
  final ValueNotifier<double> stressNotifier = ValueNotifier<double>(0.0);
  double get maxStress => gameRuntimeState.maxStress;
  double get currentStress => stressNotifier.value;

  /// [updateStress] の上限および 80% 判定と同一。
  double get effectiveMaxStress =>
      maxStress +
      (gameRuntimeState.stressBonus *
          gameRuntimeState.stressCalibrationScale);

  // お金ポイント
  final CurrencyNotifier currencyNotifier;
  int get moneyPoints => currencyNotifier.value;

  // 採掘ポイント
  final MiningPointsNotifier miningPointsNotifier;
  int get currentMiningPoints => miningPointsNotifier.value;

  Vector2 get facingDirection {
    if (isMovingUp) return Vector2(0, -1);
    if (isMovingDown) return Vector2(0, 1);
    if (isMovingLeft) return Vector2(-1, 0);
    if (isMovingRight) return Vector2(1, 0);
    if (_lastMoveDirection.y != 0) {
      return Vector2(0, _lastMoveDirection.y.sign);
    }
    if (_lastMoveDirection.x != 0) {
      return Vector2(_lastMoveDirection.x.sign, 0);
    }
    return Vector2(_lastMoveDirection.x.sign, 0);
  }

  /// D-pad 入力から最後の向きを更新（地下・空中・採掘中を含む）。
  void _syncLastMoveDirectionFromInput() {
    if (isDigging) {
      final digDir = _digDirectionVector();
      if (digDir != null) {
        _lastMoveDirection.setFrom(digDir);
        return;
      }
    }
    if (isMovingUp) {
      _lastMoveDirection.setValues(0, -1);
    } else if (isMovingDown) {
      _lastMoveDirection.setValues(0, 1);
    } else if (isMovingLeft) {
      _lastMoveDirection.setValues(-1, 0);
    } else if (isMovingRight) {
      _lastMoveDirection.setValues(1, 0);
    }
  }

  Vector2 velocity = Vector2.zero();
  Vector2 get currentSpeed => velocity;
  bool isMovingRight = false;
  bool isMovingLeft = false;
  bool isMovingDown = false;
  bool isMovingUp = false;
  bool isOnGround = false;
  bool isDigging = false;
  bool iscrouching = false;
  bool isTouchingEnemy = false;
  bool inUnderGround = false;
  final ValueNotifier<bool> inUnderGroundNotifier = ValueNotifier<bool>(false);
  bool inUnderGroundFlag = false;
  
  // ダッシュ（Run）関連
  bool _isRunning = false;
  double _lastTapTime = 0.0;
  int _lastTapDirection = 0; // 1: Right, -1: Left
  static const double _doubleTapThreshold = 0.3; // 0.3秒以内の再入力でダッシュ
  
  Vector2 _lastMoveDirection = Vector2(-1.0, 0.0); // 最後に移動した方向(初期値は左)
  bool canDig = false; // 採掘可能かどうかを示すプロパティを追加

  /// 方向入力しながら採掘するとき、何フレームに1回スタンプを刻むか
  static const int digCarveIntervalFrames = 6;
  int _digCarveFrameCounter = 0;

  double _idleTimer = 0.0; // アイドル状態の時間を計測するタイマー
  static const double _idleThreshold = 3.0; // 4秒

  // New flags to control physics behavior based on scene
  bool _applyGravity = true;
  bool _enableHorizontalPhysics = true;
  bool _enableVerticalMovement = true;

  final Set<PositionComponent> _solidCollisions = {};
  final Set<PositionComponent> _ignoredHorizontalSolidRoots = {};
  final SmallStepState _smallStepState = SmallStepState();

  bool get isSmallStepActive => _smallStepState.lastLiftApplied > 0;
  final Set<EnemyBase> _collidingEnemies = {};
  final Set<Item> _activeLadders = {}; // 接触中のはしごを保持

  /// 外部ノックバック中は [update] が velocity.x を入力で上書きしない。
  double _knockbackTimer = 0.0;

  /// 同一相手からの接触ノックバッククールダウン（秒）。
  final Map<int, double> _contactKnockbackCooldownBySource = {};

  /// 敵接触時の残滓バーストクールダウン（秒）。
  double _contactResidueBurstCooldown = 0.0;

  bool get isUnderKnockback => _knockbackTimer > 0;

  // インタラクション関連のプロパティを追加
  bool canInteract = false;

  bool get isOnLadder => _activeLadders.isNotEmpty; // はしごに登っているかどうか

  // 運搬中の配置可能アイテム
  Item? carriedItem;
  final ValueNotifier<bool> isCarryingItemNotifier = ValueNotifier<bool>(false);

  // アニメーション用の変数
  late SpriteAnimation idleFrontAnimation; // 正面向き静止 (フレーム1-2)
  late SpriteAnimation idleLeftAnimation; // 左向き静止 (フレーム3)
  late SpriteAnimation idleRightAnimation; // 右向き静止 (フレーム6)
  late SpriteAnimation movingLeftAnimation; // 左向き歩行 (フレーム4-5)
  late SpriteAnimation movingRightAnimation; // 右向き歩行 (フレーム7-8)
  late SpriteAnimation jumpingAnimation; // ジャンプ (フレーム9)
  late SpriteAnimation jumpingRightAnimation; // 右向きジャンプ (フレーム10)
  late SpriteAnimation jumpingLeftAnimation; // 左向きジャンプ (フレーム11)
  late SpriteAnimation fallingAnimation; // 落下 (フレーム12)
  late SpriteAnimation crouchingAnimation; // クローching (フレーム13)
  late SpriteAnimation diggingAnimation;

  // オーディオ用の変数
  final Map<String, List<AudioSource>> _playerSounds = {};
  
  final Map<String, List<String>> _playerSoundFiles = {
    'footsteps': [
      'assets/audio/footsteps/step_lth1.mp3',
      'assets/audio/footsteps/step_lth2.mp3',
      'assets/audio/footsteps/step_lth3.mp3',
      'assets/audio/footsteps/step_lth4.mp3',
    ],
    'hits': [
      'assets/audio/hits/Hit1.wav',
      'assets/audio/hits/Hit2.wav',
      'assets/audio/hits/Hit3.wav',
    ],
    'swing': [
      'assets/audio/actions/swish-7.wav',
      'assets/audio/actions/swish-8.wav',
      'assets/audio/actions/swish-9.wav',
    ],
  };

  // ダメージ表現用のフラグとタイマー
  bool _isTintedRed = false;
  double _tintTimer = 0.0;
  ColorFilter? _ambientColorFilter;

  // movingAnimationの最終フレームインデックスを追跡
  int _lastMovingAnimationFrameIndex = -1;

  final GameRuntimeState gameRuntimeState; // GameRuntimeStateを追加
  final ItemBag itemBag;
  final AudioManager audioManager; // Add this line

  /// カーゴ端末への参照（UIボタンから呼び出す）
  PlayerCargoTerminal? cargoTerminal;

  double _lastPlayerX = 0.0; // プレイヤーの前のX座標を追跡

  Player({
    super.position,
    required this.itemBag,
    required this.gameRuntimeState,
    required this.audioManager,
  }) : currencyNotifier = CurrencyNotifier(gameRuntimeState.currency),
       miningPointsNotifier = MiningPointsNotifier(
         gameRuntimeState.miningPoints,
       ),
       super(size: Vector2.all(50), anchor: Anchor.center) {
    // 初期値をGameRuntimeStateから取得
    integrityNotifier.value =
        GameRuntimeState.quantizeIntegrityHalf(gameRuntimeState.currentIntegrity);
    stressNotifier.value = gameRuntimeState.currentStress;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // ヒットボックスの追加（1つに統合）
    add(
      RectangleHitbox(
        size: Vector2(20, 50),
        position: Vector2(15, 0),
        collisionType: CollisionType.active,
        isSolid: true,
      ),
    );

    // カーゴ端末をプレイヤーに追従させる
    cargoTerminal = PlayerCargoTerminal();
    add(cargoTerminal!);

    // 画像の読み込み
    final spriteSheet01 = await game.images.load('player01_anim.png');
    final spriteSheet02 = await game.images.load('player02_anim.png');

    // 静止状態のアニメーション（1-2フレーム） -> idleFrontAnimation
    idleFrontAnimation = SpriteAnimation.fromFrameData(
      spriteSheet01,
      SpriteAnimationData([
        SpriteAnimationFrameData(
          srcPosition: Vector2.zero(),
          srcSize: Vector2.all(50),
          stepTime: 2,
        ),
        SpriteAnimationFrameData(
          srcPosition: Vector2(50, 0),
          srcSize: Vector2(49, 50),
          stepTime: 0.4,
        ),
      ], loop: true),
    );

    // 左向き静止アニメーション（3フレーム）
    idleLeftAnimation = SpriteAnimation.spriteList(
      [
        Sprite(
          spriteSheet01,
          srcPosition: Vector2(50 * 2, 0), // 3番目のフレーム (インデックスは2)
          srcSize: Vector2.all(50),
        ),
      ],
      stepTime: 0.2,
      loop: true,
    );

    // 左向き歩行アニメーション（4-5フレーム）。5列目は隣フレーム bleed 回避で 49px。
    movingLeftAnimation = SpriteAnimation.fromFrameData(
      spriteSheet01,
      SpriteAnimationData([
        SpriteAnimationFrameData(
          srcPosition: Vector2(50 * 3, 0),
          srcSize: Vector2.all(50),
          stepTime: 0.2,
        ),
        SpriteAnimationFrameData(
          srcPosition: Vector2(50 * 4, 0),
          srcSize: Vector2(49, 50),
          stepTime: 0.2,
        ),
      ], loop: true),
    );

    // 右向き静止アニメーション（6フレーム）
    idleRightAnimation = SpriteAnimation.spriteList(
      [
        Sprite(
          spriteSheet01,
          srcPosition: Vector2(50 * 5, 0), // 6番目のフレーム (インデックスは5)
          srcSize: Vector2.all(50),
        ),
      ],
      stepTime: 0.2,
      loop: true,
    );

    // 右向き歩行アニメーション（7-8フレーム）
    final movingRightSprites = [
      Sprite(
        spriteSheet01,
        srcPosition: Vector2(50 * 6, 0), // 7番目のフレーム (インデックスは6)
        srcSize: Vector2.all(50),
      ),
      Sprite(
        spriteSheet01,
        srcPosition: Vector2(50 * 7, 0), // 8番目のフレーム (インデックスは7)
        srcSize: Vector2.all(50),
      ),
    ];
    movingRightAnimation = SpriteAnimation.spriteList(
      movingRightSprites,
      stepTime: 0.2,
      loop: true,
    );

    // ジャンプアニメーション (9フレーム目)
    jumpingAnimation = SpriteAnimation.spriteList(
      [
        Sprite(
          spriteSheet01,
          srcPosition: Vector2(50 * 8, 0), // 9番目のフレーム (インデックスは8)
          srcSize: Vector2.all(50),
        ),
      ],
      stepTime: 0.2,
      loop: false, // ジャンプはループしない
    );

    // 右向きジャンプアニメーション (10フレーム目)
    jumpingLeftAnimation = SpriteAnimation.spriteList(
      [
        Sprite(
          spriteSheet01,
          srcPosition: Vector2(50 * 9, 0), // 10番目のフレーム (インデックスは9)
          srcSize: Vector2.all(50),
        ),
      ],
      stepTime: 0.2,
      loop: false, // ジャンプはループしない
    );

    // 左向きジャンプアニメーション (11フレーム目)
    jumpingRightAnimation = SpriteAnimation.spriteList(
      [
        Sprite(
          spriteSheet01,
          srcPosition: Vector2(50 * 10, 0), // 11番目のフレーム (インデックスは10)
          srcSize: Vector2.all(50),
        ),
      ],
      stepTime: 0.2,
      loop: false, // ジャンプはループしない
    );

    // 落下アニメーション (12フレーム目)
    fallingAnimation = SpriteAnimation.spriteList(
      [
        Sprite(
          spriteSheet01,
          srcPosition: Vector2(50 * 11, 0), // 12番目のフレーム (インデックスは11)
          srcSize: Vector2.all(50),
        ),
      ],
      stepTime: 0.2,
      loop: false,
    );

    // しゃがみアニメーション (13フレーム目)
    crouchingAnimation = SpriteAnimation.spriteList(
      [
        Sprite(
          spriteSheet01,
          srcPosition: Vector2(50 * 12, 0), // 13番目のフレーム (インデックスは12)
          srcSize: Vector2.all(50),
        ),
      ],
      stepTime: 0.2,
      loop: false,
    );

    // 掘るアニメーション
    diggingAnimation = SpriteAnimation.fromFrameData(
      spriteSheet02,
      SpriteAnimationData.sequenced(
        amount: 2,
        stepTime: 0.3,
        textureSize: Vector2(50, 50),
        amountPerRow: 2,
        loop: true,
      ),
    );

    // 初期アニメーション
    animation = idleFrontAnimation;

    _lastPlayerX = position.x; // 初期位置を設定

    _drowsinessEffect = DrowsinessEffect();
    game.camera.viewport.add(_drowsinessEffect!);

    // オーディオの読み込み
    for (final type in _playerSoundFiles.keys) {
      _playerSounds[type] = await Future.wait(
        _playerSoundFiles[type]!
            .map((file) => audioManager.loadAndCacheSound(file))
            .toList(),
      );
    }
  }

  @override
  void onMount() {
    super.onMount();
    // GameUIの方向ボタン押下状態Notifierを購読
    GameUI.upButtonPressedNotifier.addListener(_updateIsMovingUp);
    GameUI.downButtonPressedNotifier.addListener(_updateIsMovingDown);
    GameUI.leftButtonPressedNotifier.addListener(_updateIsMovingLeft);
    GameUI.rightButtonPressedNotifier.addListener(_updateIsMovingRight);
    GameUI.downButtonPressedNotifier.addListener(_updateIscrouching);
  }

  @override
  void onRemove() {
    GameUI.upButtonPressedNotifier.removeListener(_updateIsMovingUp);
    GameUI.downButtonPressedNotifier.removeListener(_updateIsMovingDown);
    GameUI.leftButtonPressedNotifier.removeListener(_updateIsMovingLeft);
    GameUI.rightButtonPressedNotifier.removeListener(_updateIsMovingRight);
    GameUI.downButtonPressedNotifier.removeListener(_updateIscrouching);
    super.onRemove();
  }

  // プレイヤーの足元のY座標を計算するgetter
  double get playerFootPositionY => absolutePosition.y + (size.y / 2);

  /// プレイヤーをテレポートさせ、背景パララックスをリセットする
  void teleportTo(Vector2 newPosition) {
    position = newPosition;
    _lastPlayerX = newPosition.x;
    game.cameraController.resetManualPan();
    game.cameraController.syncVerticalFocusFromPlayer();
    game.cameraController.resetBackgroundParallax();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_knockbackTimer > 0) {
      _knockbackTimer -= dt;
    }
    if (_contactResidueBurstCooldown > 0) {
      _contactResidueBurstCooldown -= dt;
    }
    _tickContactKnockbackCooldowns(dt);

    SmallStepTraversal.endFrame(
      _smallStepState,
      _ignoredHorizontalSolidRoots,
    );

    if (!game.gameRuntimeState.isAutoPlay) {
      game.gameRuntimeState.tickAutomationAutoPickup(dt);
    }

    if (gameRuntimeState.isAutoPlay) {
      _performAutoPlay(dt);
      _applyKinematicMovement(dt);
      _handleUnderGroundPostMove(dt);
      _lastPlayerX = position.x;
      return;
    }

    _lastPlayerX = position.x;

    // 外的刺激（ストレス）値の自動回復
    updateStress(currentStress - 5 * dt);

    // 地下でのベース処理
    if (inUnderGround) {
      // 地下深部での眠気演出
      final currentScene = game.sceneManager.currentScene;
      if (currentScene is AbstractOutdoorScene) {
        final double depth = position.y - currentScene.underGround.position.y;
        if (depth > 300) {
          // 深度300を超えると眠気が発生
          final double intensity = ((depth - 300) / 500).clamp(0.0, 1.0);
          _drowsinessEffect?.intensity = intensity;
          
          // 耐久力を継続的に減少
          decreaseIntegrity(10 * intensity * dt);
          
          if (intensity > 0.8) {
             // 非常に深い場所ではさらにストレスも増加
             updateStress(currentStress + 5 * dt);
          }
        } else {
          _drowsinessEffect?.intensity = 0.0;
        }
      }

      // 地下での自動耐久力回復
      if (currentIntegrity < (maxIntegrity / 2) && currentStress < 25) {
        recoveryIntegrity(15 * dt);
      }

      if (inUnderGroundFlag == false) {
        unbeatable = true;
        game.cameraController.adjustCameraForDigging();
        _updateUpButtonState();
      }
      // エコーフィルターのアクティブ化/非アクティブ化
      if (audioManager.soloud.isInitialized &&
          !audioManager.soloud.filters.echoFilter.isActive) {
        audioManager.soloud.filters.echoFilter.activate();
        audioManager.soloud.filters.echoFilter
          ..wet.value = 0.6
          ..delay.value = 0.1
          ..decay.value = 0.6;
      }
      inUnderGroundFlag = true;
    } else {
      if (inUnderGroundFlag == true) {
        toggleDigging(false);
        unbeatable = false;
        game.cameraController.setOutdoorSceneCamera();
        _updateUpButtonState();
      }
      // エコーフィルターのアクティブ化/非アクティブ化
      if (audioManager.soloud.isInitialized &&
          audioManager.soloud.filters.echoFilter.isActive) {
        audioManager.soloud.filters.echoFilter.deactivate();
      }
      inUnderGroundFlag = false;
    }

    // ゲームオーバー（意志力が尽きた場合）
    // max が 0 のときは gameOver 後も current が補充できず連続発火するためトリガーしない
    if (gameRuntimeState.currentWillpower <= 0 &&
        !game.isGameOver &&
        gameRuntimeState.maxWillCoreValue > 1e-9) {
      Future.microtask(() => game.gameOver());
    }

    // inUnderGround の状態を更新
    // 現在のシーンがUnderGroundプロパティを持つGameSceneのサブクラスであるかを確認
    if (game.sceneManager.currentScene is AbstractOutdoorScene) {
      final currentScene =
          game.sceneManager.currentScene as AbstractOutdoorScene; // 明示的にキャスト
      // 足元が少しでも地下に入ったら inUnderGround とする
      inUnderGround = (position.y + 20) >= currentScene.underGround.position.y;
    } else {
      inUnderGround = false; // 屋外シーン以外では地下にいない
    }
    if (inUnderGroundNotifier.value != inUnderGround) {
      inUnderGroundNotifier.value = inUnderGround;
    }

    // エフェクトの更新
    updateEffect();

    // ダメージエフェクトのタイマー更新
    if (_isTintedRed) {
      _tintTimer -= dt;
      if (_tintTimer <= 0) {
        _isTintedRed = false;
        _applyActiveColorFilter();
      }
    }

    // movingAnimationのフレーム変更時に足音を再生
    if ((animation == movingRightAnimation ||
            animation == movingLeftAnimation) &&
        isOnGround) {
      if (animationTicker!.currentIndex != _lastMovingAnimationFrameIndex) {
        // 歩く音を再生
        final double playbackRate = 0.9 + Random().nextDouble() * 0.2;
        requestPlayPlayerSound('footsteps', volume: 0.8, playbackRate: playbackRate);
        _lastMovingAnimationFrameIndex = animationTicker!.currentIndex;

        // ダッシュ中は生命資源の残滓（赤粒子）を漏出させる
        if (isRunning) {
          ResidueEffect.spawnLife(game, absolutePosition.clone(), count: 3);
        }
      }
    } else {
      // 他のアニメーションに変わったらリセット
      _lastMovingAnimationFrameIndex = -1;
    }

    // アイドルタイマーの更新と正面向きアニメーションへの移行
    if (!isMovingRight &&
        !isMovingLeft &&
        !isMovingUp &&
        !isMovingDown &&
        !isDigging &&
        !iscrouching) {
      _idleTimer += dt;
      if (_idleTimer >= _idleThreshold) {
        animation = idleFrontAnimation; // 正面向き静止アニメーションに設定
      } else {
        // 4秒未満のアイドル時は最後に移動した方向のアニメーション
        if (_lastMoveDirection.y < 0 || _lastMoveDirection.y > 0) {
          animation = idleFrontAnimation; // 上下向き後のアイドル
        } else if (_lastMoveDirection.x > 0) {
          animation = idleRightAnimation; // 右向き静止
        } else if (_lastMoveDirection.x < 0) {
          animation = idleLeftAnimation; // 左向き静止
        } else {
          animation = idleFrontAnimation; // 正面向き静止
        }
      }
    } else {
      _idleTimer = 0.0; // 移動または掘削中はタイマーをリセット
    }

    final outdoorScene =
        game.sceneManager.currentScene is AbstractOutdoorScene;

    // 水平方向の移動
    if (_enableHorizontalPhysics) {
      if (isDigging) {
        // 掘削中は押している方向にのみ移動（横掘り・縦掘り）
        final digSpeed = effectiveSpeed * 0.35;
        if (!isUnderKnockback) {
          if (isMovingRight) {
            velocity.x = digSpeed;
          } else if (isMovingLeft) {
            velocity.x = -digSpeed;
          } else {
            velocity.x = 0;
          }
        }
        animation = diggingAnimation;
      } else if (iscrouching) {
        // しゃがみ状態の水平移動速度
        if (!isUnderKnockback) {
          if (velocity.x.abs() > 0.1) {
            // 完全に停止するまでのしきい値
            velocity.x *= 0.9;
          } else {
            velocity.x = 0;
          }
        }
        animation = crouchingAnimation;
      } else {
        // 通常の水平移動速度
        double currentBaseSpeed = effectiveSpeed;
        if (isRunning) {
          currentBaseSpeed *= 1.5; // ダッシュ時は1.5倍
        }
        if (!isUnderKnockback) {
          velocity.x = (isMovingRight ? currentBaseSpeed : (isMovingLeft ? -currentBaseSpeed : 0));
        }

        if (isMovingRight) {
          animation = movingRightAnimation;
        } else if (isMovingLeft) {
          animation = movingLeftAnimation;
        }
      }
    } else {
      if (!isUnderKnockback) {
        velocity.x = 0;
      }
      if (isDigging) {
        animation = diggingAnimation;
      } else {
        // 水平移動が無効な場合でも、アイドルタイマーによってアニメーションが決定される
        // ここでは何もしない
      }
    }

    if (outdoorScene &&
        !isDigging &&
        !iscrouching &&
        !isOnLadder &&
        _enableHorizontalPhysics &&
        _enableVerticalMovement &&
        (isOnGround || inUnderGround)) {
      final intent = velocity.x.sign.toInt();
      if (intent != 0 && velocity.x.abs() > 1.0) {
        final horizontalDx = velocity.x * dt;
        var stepBase = effectiveSpeed;
        if (isRunning) {
          stepBase *= 1.5;
        }
        final outdoor =
            game.sceneManager.currentScene is AbstractOutdoorScene
                ? game.sceneManager.currentScene! as AbstractOutdoorScene
                : null;
        SmallStepTraversal.tryBegin(
          state: _smallStepState,
          body: this,
          intent: intent,
          solidCandidates: _solidCollisions,
          ignoredHorizontalRoots: _ignoredHorizontalSolidRoots,
          velocity: velocity,
          basisSpeed: stepBase,
          terrain: outdoor?.underGround.terrainField,
          horizontalDxAttempt: horizontalDx,
        );
      }
    }

    // 垂直方向の移動 (重力、ジャンプ、および掘削)
    if (_enableVerticalMovement) {
      if (isDigging) {
        // 掘削中は重力は通常無視され、垂直速度は直接制御される
        if (isMovingDown) {
          velocity.y = effectiveSpeed * 0.25; // 下に掘る
        } else if (isMovingUp) {
          if (position.y >
              game.initialGameCanvasSize.y +
                  game
                      .sceneManager
                      .currentScene!
                      .groundComponent!
                      .groundHeight) {
            // 地面より上に掘りすぎないようにする
            velocity.y = -effectiveSpeed * 0.25; // 上に掘る
          }
        } else {
          velocity.y = 0; // 掘削中に上下に移動していない場合、垂直速度はゼロ
        }
        isOnGround = false; // 積極的に掘削中は、通常の物理的な「地面にいる」状態ではない
      } else if (isOnLadder) {
        // はしご移動
        if (_isJumping) {
          if (isJumpButtonPressed && _jumpTime < maxJumpTime) {
            _jumpTime += dt;
            velocity.y = jumpForce;
          } else {
            _isJumping = false;
          }
        } else if (isMovingUp) {
          velocity.y = -effectiveSpeed;
        } else if (isMovingDown) {
          velocity.y = effectiveSpeed;
        } else {
          velocity.y = 0;
        }

        // はしご中でも足元に固形物（地面など）があれば停止する
        if (velocity.y >= 0) {
          final Rect playerFootRect = Rect.fromLTWH(
            absolutePosition.x - size.x * 0.05,
            absolutePosition.y + size.y / 2,
            size.x * 0.1,
            2,
          );

          for (final collision in _solidCollisions) {
            if (collision.toRect().overlaps(playerFootRect)) {
              if (velocity.y > 0) velocity.y = 0;
              isOnGround = true;
              break;
            }
          }
        }

        if (velocity.y < 0) {
          isOnGround = false;
        }
      } else {
        // 掘削中でない場合、通常の物理を適用
        
        // 可変ジャンプの実装
        if (_isJumping) {
          if (isJumpButtonPressed && _jumpTime < maxJumpTime) {
            _jumpTime += dt;
            velocity.y = jumpForce; // 上向きの力を維持
          } else {
            _isJumping = false;
          }
        }

        // isOnGroundの判定は、_solidCollisionsと現在の垂直速度に基づく
        bool newIsOnGround = false;

        final Rect playerFootRect = Rect.fromLTWH(
          absolutePosition.x - size.x * 0.05,
          absolutePosition.y + size.y / 2,
          size.x * 0.1,
          2,
        );

        for (final collision in _solidCollisions) {
          if (collision.toRect().overlaps(playerFootRect)) {
            newIsOnGround = true;
            break;
          }
        }

        if (newIsOnGround && velocity.y >= 0) {
          velocity.y = 0;
          _isJumping = false;
        }

        isOnGround = newIsOnGround;

        // アニメーションの切り替え: ジャンプ、落下、静止、移動
        if (!isOnGround) {
          if (velocity.y < 0) {
            // ジャンプ中
            if (_lastMoveDirection.x > 0 || isMovingRight) {
              animation = jumpingRightAnimation;
            } else if (_lastMoveDirection.x < 0 || isMovingLeft) {
              animation = jumpingLeftAnimation;
            } else {
              animation = jumpingAnimation;
            }
          } else if (velocity.y > 150) {
            // 落下中
            animation = fallingAnimation;
          }
        } else if (!isDigging && !iscrouching) {
          if (isMovingRight) {
            animation = movingRightAnimation;
          } else if (isMovingLeft) {
            animation = movingLeftAnimation;
          }
        }
      }

      if (!isOnLadder &&
          _enableHorizontalPhysics &&
          _enableVerticalMovement) {
        _applyKinematicMovement(dt);
      } else if (isOnLadder) {
        _applyLadderKinematicMovement(dt);
      } else {
        position.y += velocity.y * KinematicMovement.clampPhysicsDt(dt);
      }

      // 運搬中のアイテムをプレイヤー頭上に固定（ワールド座標）
      if (carriedItem != null) {
        _syncCarriedItemWorldPosition();
      }
    }

    // 画面の端でプレイヤーを停止させる
    if (game.sceneManager.currentScene != null &&
        game.sceneManager.currentScene!.groundComponent != null) {
      final ground = game.sceneManager.currentScene!.groundComponent!;
      double clampLeft = game.sceneManager.currentScene is AbstractOutdoorScene ? -MyGame.worldWidth + 10 : ground.position.x + 10;
      double clampRight = game.sceneManager.currentScene is AbstractOutdoorScene ? -10 : ground.groundWidth - 10;
      position.x = position.x.clamp(
        clampLeft,
        clampRight,
      );

      // 落下限界点の定義
      if (!inUnderGround &&
          velocity.y >= 0 &&
          position.y > ground.position.y + 300) {
        position.y = ground.position.y + ground.groundHeight;
      }
    }

    // 向き保存は _syncLastMoveDirectionFromInput のみが担当（速度で上書きしない）
    _syncLastMoveDirectionFromInput();

    // プレイヤーの向きに応じてリスナーの 'at' ベクトルを設定
    final Vector2 listenerAt;
    if (velocity.x != 0) {
      listenerAt = Vector2(velocity.x.sign, 0.0);
    } else if (velocity.y != 0) {
      listenerAt = Vector2(0.0, velocity.y.sign);
    } else {
      listenerAt = facingDirection;
    }

    game.audioManager.updateListener(
      position, // プレイヤーの現在の位置
      listenerAt, // プレイヤーが向いている方向
      Vector2(0.0, 1.0), // 2Dゲームにおける上方向
    );

    _handleUnderGroundPostMove(dt);
  }

  Vector2 _feetWorldPosition() =>
      Vector2(absoluteCenter.x, absoluteCenter.y + size.y / 2);

  /// 採掘スタンプの基準（足元より [size.y / 2] 上）。
  Vector2 _digCarveOriginWorldPosition() =>
      Vector2(absoluteCenter.x, absoluteCenter.y);

  ({
    List<Rect> slabs,
    List<Rect> floorSlabList,
    TerrainField? terrain,
  }) _collectKinematicCollisionContext() {
    final currentScene = game.sceneManager.currentScene;
    final outdoor =
        currentScene is AbstractOutdoorScene ? currentScene : null;

    Rect? groundSlabRect;
    if (outdoor?.ground != null) {
      groundSlabRect = PhysicsStepQueries.absoluteAabb(outdoor!.ground!);
    }

    final slabs = <Rect>[];
    final floorSlabList = <Rect>[];
    final ug = outdoor?.underGround;
    if (ug != null) {
      _solidCollisions.remove(ug);
    }
    for (final raw in _solidCollisions) {
      if (!raw.isMounted) continue;
      final root = PhysicsStepQueries.solidRoot(raw);
      if (_ignoredHorizontalSolidRoots.contains(root)) continue;
      if (ug != null && identical(root, ug)) continue;
      for (final slab in KinematicMovement.collectTerrainSlabs([raw])) {
        if (isDigging &&
            groundSlabRect != null &&
            _rectsNearlyEqual(slab, groundSlabRect)) {
          continue;
        }
        slabs.add(slab);
      }
    }

    final TerrainField? terrain =
        outdoor != null && !isDigging ? outdoor.underGround.terrainField : null;

    if (outdoor != null && groundSlabRect != null && !isDigging) {
      slabs.add(groundSlabRect);
    }

    if (ug != null && inUnderGround && !isDigging) {
      floorSlabList.addAll(ug.floorSlabs());
      slabs.addAll(floorSlabList);
    }

    return (slabs: slabs, floorSlabList: floorSlabList, terrain: terrain);
  }

  void _applyKinematicMovement(double dt) {
    final collision = _collectKinematicCollisionContext();

    final result = KinematicMovement.integrate(
      body: this,
      velocity: velocity,
      dt: dt,
      config: KinematicConfig(
        gravity: effectiveGravity,
        maxFallSpeed: maxFallSpeed,
        maxHorizontalSpeed: effectiveSpeed * 2.5,
        applyGravity: _applyGravity && !_isJumping && !isDigging,
        enableHorizontal: _enableHorizontalPhysics && !iscrouching,
        enableVertical: true,
        startOnGround: isDigging ? false : isOnGround,
        enableFootSnap: !isDigging,
      ),
      terrain: collision.terrain,
      staticSlabs: collision.slabs,
      preferredFootSlabs: collision.floorSlabList,
      oneWaySlabs: collision.floorSlabList,
      dropThroughOneWaySlabs: iscrouching && inUnderGround,
    );

    if (isDigging) {
      isOnGround = false;
      final outdoor = game.sceneManager.currentScene;
      if (outdoor is AbstractOutdoorScene) {
        _tickDigCarve(outdoor);
      }
    } else {
      _digCarveFrameCounter = 0;
      isOnGround = result.isOnGround;
      if (isOnGround && velocity.y > 0) {
        velocity.y = 0;
        _isJumping = false;
      }
    }
  }

  /// はしご上の移動（地形・slab 衝突あり、重力なし）。
  void _applyLadderKinematicMovement(double dt) {
    final collision = _collectKinematicCollisionContext();

    final result = KinematicMovement.integrate(
      body: this,
      velocity: velocity,
      dt: dt,
      config: KinematicConfig(
        gravity: effectiveGravity,
        maxFallSpeed: maxFallSpeed,
        maxHorizontalSpeed: effectiveSpeed * 2.5,
        applyGravity: false,
        enableHorizontal: _enableHorizontalPhysics && !iscrouching,
        enableVertical: true,
        startOnGround: isOnGround,
        enableFootSnap: true,
      ),
      terrain: collision.terrain,
      staticSlabs: collision.slabs,
      preferredFootSlabs: collision.floorSlabList,
      oneWaySlabs: collision.floorSlabList,
      dropThroughOneWaySlabs: false,
    );

    isOnGround = result.isOnGround;
    if (result.hitCeiling && velocity.y < 0) {
      velocity.y = 0;
      _isJumping = false;
    }
    if (isOnGround && velocity.y > 0) {
      velocity.y = 0;
    }
  }

  /// 6フレームに1回、足元と掘削速度に応じた前方へスタンプを刻む。
  void _tickDigCarve(AbstractOutdoorScene outdoor) {
    final dir = _digDirectionVector();
    if (dir == null) {
      _digCarveFrameCounter = 0;
      return;
    }

    _digCarveFrameCounter++;
    if (_digCarveFrameCounter < digCarveIntervalFrames) {
      return;
    }
    _digCarveFrameCounter = 0;

    final ug = outdoor.underGround;
    final origin = _digCarveOriginWorldPosition();

    final digSpeed = effectiveSpeed * 0.35;
    final lookAhead = max(
      20.0,
      digSpeed * digCarveIntervalFrames / 60.0,
    );
    final ahead = origin + dir * lookAhead;
    ug.carveCapsule(origin, ahead, ug.passageRadiusForPlayer());
  }

  Vector2? _digDirectionVector() {
    if (isMovingDown) return Vector2(0, 1);
    if (isMovingUp) return Vector2(0, -1);
    if (isMovingRight) return Vector2(1, 0);
    if (isMovingLeft) return Vector2(-1, 0);
    return null;
  }

  static bool _rectsNearlyEqual(Rect a, Rect b) =>
      (a.left - b.left).abs() < 2 &&
      (a.top - b.top).abs() < 2 &&
      (a.width - b.width).abs() < 2 &&
      (a.height - b.height).abs() < 2;

  Vector2 _feetFromCenter(Vector2 center) =>
      Vector2(center.x, center.y + size.y / 2);

  // オートプレイ用のロジック
  void _performAutoPlay(double dt) {
    // Stage 6 (Despair) で右に向かって自動で歩き続ける
    isMovingRight = true;
    isMovingLeft = false;
    isMovingUp = false;
    isMovingDown = false;

    // 通常の移動処理
    velocity.x = effectiveSpeed * 0.7;
    animation = movingRightAnimation;

    // 崖（世界の右端）に到達したらリセット（飛び降り または 帰還）
    if (position.x > 1000) { 
      debugPrint('AutoPlay: Reached the edge. Returning to Stage 1...');
      game.stageClear(); // 周回クリア処理
    }
  }

  void jump() {
    if (isOnGround || isOnLadder) {
      isOnGround = false;
      _isJumping = true;
      _jumpTime = 0.0;
      velocity.y = jumpForce;
      isJumpButtonPressed = true;
      
      // ジャンプ音
      requestPlayPlayerSound('swing', volume: 0.5, playbackRate: 1.5);
    }
  }

  void stopJump() {
    isJumpButtonPressed = false;
    // _isJumping は update 内で _jumpTime >= maxJumpTime になったら false になるが、
    // ボタンを離した瞬間に上昇を止める（または弱める）ことでキレのある操作感にする
    if (velocity.y < 0) {
      velocity.y *= 0.5;
    }
    _isJumping = false;
  }

  void enterHide(HideableObject spot) {
    if (isHiding) return;
    isHiding = true;
    hidingSpot = spot;
    
    // プレイヤーを非表示にする（または半透明にする）
    opacity = 0.0;
    velocity = Vector2.zero();
    
    // ビネットエフェクトを追加
    _hidingVignette = HidingVignette();
    game.camera.viewport.add(_hidingVignette!);
    
    // 操作不能にする（updateで制御）
    unbeatable = true;
    setPhysicsBehavior(
      applyGravity: false,
      enableHorizontalPhysics: false,
      enableVerticalMovement: false,
    );
    
    // UIの更新（隠れるボタンを「出る」アイコンに変える）
    GameUI.setInteractButtonIcon(Icons.exit_to_app);
  }

  void exitHide() {
    if (!isHiding) return;
    isHiding = false;
    hidingSpot = null;
    
    // プレイヤーを表示に戻す
    opacity = 1.0;
    
    // ビネットエフェクトを削除
    _hidingVignette?.removeFromParent();
    _hidingVignette = null;
    
    // 物理挙動を元に戻す
    unbeatable = false;
    setPhysicsBehavior(
      applyGravity: true,
      enableHorizontalPhysics: true,
      enableVerticalMovement: true,
    );
    
    // UIの更新
    GameUI.setInteractButtonIcon(Icons.meeting_room);
  }
  void performMeleeAttack() {
    // 1. 攻撃範囲の計算（ワールド座標系）
    final playerCenter = absolutePosition;
    final scale = effectiveMeleeSizeScale;
    final meleeSize = Vector2(60 * scale, 60 * scale); 

    // 攻撃音
    double playbackRate = 1.1;
    double volume = 1.0;

    // ご要望のオフセット調整 (+25)
    // 向きに応じてXの位置を決定し、さらに+25
    final double meleeX = facingDirection.x > 0 
        ? playerCenter.x + 10 + 25
        : playerCenter.x - (meleeSize.x + 10) + 25; 
    
    // Y軸も+25
    final double meleeY = playerCenter.y - (meleeSize.y / 2) + 25;
    
    final attackRect = Rect.fromLTWH(meleeX, meleeY, meleeSize.x, meleeSize.y);

    // 2. 攻撃エフェクトの表示（視覚的な確認用）
    final effectX = facingDirection.x > 0 ? 35.0 : -45.0 - (meleeSize.x - 60); 
    final attackEffect = RectangleComponent(
      position: Vector2(effectX, -(meleeSize.y / 2) + 25),
      size: meleeSize,
      paint: Paint()..color = Colors.white.withOpacity(0.4),
    );
    add(attackEffect);
    
    // FlameのTimerComponentを使用して確実に削除
    add(TimerComponent(
      period: 0.1,
      removeOnFinish: true,
      onTick: () {
        if (attackEffect.isMounted) attackEffect.removeFromParent();
      },
    ));

    // 攻撃音
    requestPlayPlayerSound('swing', volume: volume, playbackRate: playbackRate);

    // 3. ヒット判定（現在のシーンの子コンポーネントを検索）
    final currentScene = game.sceneManager.currentScene;
    if (currentScene == null) return;

    // 破壊可能オブジェクト
    final destructibles = currentScene.children.whereType<DestructibleObject>();
    for (final obj in destructibles) {
      if (obj.toAbsoluteRect().overlaps(attackRect)) {
        debugPrint('Melee Hit: DestructibleObject at ${obj.position}');
        obj.onHit();
      }
    }

    // 敵
    final enemies = currentScene.children.whereType<EnemyBase>();
    
    // 依存ルートの補正：自動エイム（近くの敵に吸い寄せられる）
    if (gameRuntimeState.isDependencyOverloadForUi) {
      EnemyBase? nearestEnemy;
      double minDistance = 100.0;
      for (final enemy in enemies) {
        final distance = (absolutePosition - enemy.absolutePosition).length;
        if (distance < minDistance) {
          minDistance = distance;
          nearestEnemy = enemy;
        }
      }
      if (nearestEnemy != null) {
        // 敵の方向にわずかに移動（吸い付き）
        position.x = lerpDouble(position.x, nearestEnemy.position.x - (facingDirection.x * 20), 0.3)!;
      }
    }

    for (final enemy in enemies) {
      if (PhysicsBodyQueries.physicsAabb(enemy).overlaps(attackRect)) {
        debugPrint('Melee Hit: Enemy at ${enemy.position}');

        final equippedItemName = itemBag.equippedItemName;
        double itemAttackPower = 0.0;
        double itemMass = KnockbackConfig.meleeBareHandMass;

        if (equippedItemName != null) {
          final tempItem = ItemFactory.createItemByName(equippedItemName, Vector2.zero());
          if (tempItem != null) {
            itemAttackPower = tempItem.attackPower;
            itemMass = tempItem.mass;
          }
        }

        final damage = powerOfPlayer * (itemAttackPower + itemMass * 2.0);
        final impulse = KnockbackConfig.meleeImpulse(
          itemMass: itemMass,
          enemyMass: enemy.mass,
          facingX: facingDirection.x,
          scale: scale,
        );

        enemy.hitByMelee(damage, impulse);
      }
    }

    // NPC
    final npcs = currentScene.children.whereType<Npc>();
    for (final npc in npcs) {
      if (npc.toAbsoluteRect().overlaps(attackRect)) {
        debugPrint('Melee Hit: NPC at ${npc.position}');
      }
    }
  }

  // 状態管理メソッド ==============================================================================
  void _updateUpButtonState() {
    final state =
        (inUnderGround || isOnLadder)
            ? DirectionButtonState.normal
            : DirectionButtonState.disabled;
    GameUI.setUpButtonState(state);
  }

  void toggleDigging([bool? diggingState]) {
    isDigging = diggingState ?? !isDigging;
    if (!isDigging) {
      _digCarveFrameCounter = 0;
    }
    final bool isDiggingOnGround = diggingState != null && diggingState;

    // 依存ルートの演出：採掘モーションの高速化
    if (gameRuntimeState.isDependencyOverloadForUi && isDigging) {
      diggingAnimation.stepTime = 0.05; // 超高速
    } else {
      diggingAnimation.stepTime = 0.3; // 通常
    }

    // UI更新を非同期にスケジュール
    Future.microtask(() {
      if (!inUnderGround) {
        // プレイヤーが地上にいる場合
        GameUI.setDownButtonState(
          isDiggingOnGround
              ? DirectionButtonState.notice
              : DirectionButtonState.normal,
        );
        GameUI.setLeftButtonState(
          isDiggingOnGround || iscrouching
              ? DirectionButtonState.disabled
              : DirectionButtonState.normal,
        );
        GameUI.setRightButtonState(
          isDiggingOnGround || iscrouching
              ? DirectionButtonState.disabled
              : DirectionButtonState.normal,
        );
      } else {
        // プレイヤーが地下にいる場合
        GameUI.setDownButtonState(DirectionButtonState.normal);
        GameUI.setLeftButtonState(DirectionButtonState.normal);
        GameUI.setRightButtonState(DirectionButtonState.normal);
      }
    });
    _updateIscrouching(); // isDiggingの状態変更後にもiscrouchingを更新
  }

  void _updateIsMovingUp() {
    isMovingUp = GameUI.upButtonPressedNotifier.value;
  }

  void _updateIsMovingDown() {
    isMovingDown = GameUI.downButtonPressedNotifier.value;
  }

  bool get isRunning => _isRunning;

  void _updateIsMovingLeft() {
    final bool newValue = GameUI.leftButtonPressedNotifier.value;
    if (newValue && !isMovingLeft) {
      _handleMoveInputStart(-1);
    }
    isMovingLeft = newValue;
    _checkRunStop();
  }

  void _updateIsMovingRight() {
    final bool newValue = GameUI.rightButtonPressedNotifier.value;
    if (newValue && !isMovingRight) {
      _handleMoveInputStart(1);
    }
    isMovingRight = newValue;
    _checkRunStop();
  }

  void _handleMoveInputStart(int direction) {
    if (!gameRuntimeState.canRun) return;
    
    final currentTime = game.timeService.totalPlayTime;
    if (direction == _lastTapDirection && (currentTime - _lastTapTime) < _doubleTapThreshold) {
      _isRunning = true;
      debugPrint('Dash Started: Direction $direction');
    }
    
    _lastTapTime = currentTime;
    _lastTapDirection = direction;
  }

  void _checkRunStop() {
    if (!isMovingLeft && !isMovingRight) {
      if (_isRunning) {
        debugPrint('Dash Stopped');
      }
      _isRunning = false;
    }
  }

  void _updateIscrouching() {
    iscrouching =
        GameUI.downButtonPressedNotifier.value && !isDigging && !isOnLadder;
  }

  // ステータス管理メソッド ==============================================================================

  // 耐久力を更新するメソッド（小数は .0 / .5 のみ）
  void updateIntegrity(double newIntegrity) {
    final state = game.gameRuntimeState;
    double effectiveMaxIntegrity =
        maxIntegrity + (state.hpBonus * state.hpCalibrationScale);
    final q = GameRuntimeState.quantizeIntegrityHalf(
      newIntegrity.clamp(0.0, effectiveMaxIntegrity),
    );
    integrityNotifier.value = q;
    state.currentIntegrity = q;
  }

  // 自然回復
  void recoveryIntegrity(double recoveryAmount) {
    updateIntegrity(integrityNotifier.value + recoveryAmount);
  }

  // 外的刺激（ストレス）値を更新するメソッド
  void updateStress(double newStress) {
    final state = game.gameRuntimeState;
    final cap = effectiveMaxStress;
    stressNotifier.value = newStress.clamp(0.0, cap);
    state.currentStress = stressNotifier.value; // GameRuntimeStateを同期

    // ストレスが閾値（80%）を超えた場合の耐久力減少ロジック
    if (stressNotifier.value >= cap * 0.8 && !unbeatable) {
      // ストレス1につき耐久力1.0減少（以前の2倍）
      decreaseIntegrity(1.0); 
    }
  }

  // 耐久力を減少させるメソッド
  void decreaseIntegrity(double amount) {
    if (unbeatable) return;
    updateIntegrity(currentIntegrity - amount);

    if (currentIntegrity <= 0 &&
        !game.isGameOver &&
        gameRuntimeState.maxWillCoreValue > 1e-9) {
      final state = gameRuntimeState;
      final unit = GameRuntimeState.willCoreUnit;
      // currentWillpower > willCoreUnit のときだけコストを支払い復帰（上限核は削らない）。
      // <= willCoreUnit は活力枯渇として GO。
      if (state.currentWillpower > unit) {
        state.payWillCoreUnitAfterIntegrityKnockdown();
        final effectiveMax =
            maxIntegrity + (state.hpBonus * state.hpCalibrationScale);
        updateIntegrity(effectiveMax);
      } else {
        Future.microtask(() => game.gameOver());
      }
    }
  }

  // 最大ストレス値を増やすメソッド
  void addMaxStress(double addAmount) {
    gameRuntimeState.maxStress = (gameRuntimeState.maxStress + addAmount).clamp(50.0, 300.0);
  }

  // お金を増減させるメソッド
  void updateMoneyPoints(int income) {
    currencyNotifier.update(income);
    gameRuntimeState.currency = moneyPoints; // GameRuntimeStateを更新
  }

  // 採掘ポイントを増減させるメソッド
  void updateMiningPoints(int income) {
    miningPointsNotifier.update(income);
    gameRuntimeState.miningPoints = currentMiningPoints; // GameRuntimeStateを更新
  }

  // アイテム管理メソッド ==============================================================================

  // アイテムを収集するメソッド (Itemクラスから呼び出される)
  void collectItem(Item item) {
    itemBag.addItem(item);
  }

  // アイテム運搬メソッド --------------------------------------------------------------------------------
  void _syncCarriedItemWorldPosition() {
    if (carriedItem == null) return;
    carriedItem!.syncDisplayAnchor();
    // Item は Anchor.center — position はスプライト中心のワールド座標
    carriedItem!.position = Vector2(
      absoluteCenter.x,
      absoluteCenter.y - size.y / 2,
    );
  }

  // アイテム運搬を開始するメソッド
  Future<void> startCarrying(Item item) async {
    debugPrint('Player: startCarrying called for ${item.name}');

    var carryItem = item;
    if (ItemFactory.isLanternLightItem(item)) {
      if (item.isMounted) {
        item.removeFromParent();
      }
      final lantern = ItemFactory.createPlacedWorldItemByName(
        item.name,
        Vector2.zero(),
      );
      if (lantern != null) {
        lantern.syncDisplayAnchor();
        carryItem = lantern;
      }
    }

    // 運搬アイテムの重複チェック
    if (carriedItem != null) {
      if (carriedItem!.name == item.name) {
        // 同じアイテムをすでに持っている場合は、位置だけ再設定して早期リターン
        _syncCarriedItemWorldPosition();
        isCarryingItemNotifier.value = true;
        debugPrint('Player: Already carrying ${item.name}, updated position.');
        return;
      }
      debugPrint('すでに別のアイテムを運搬中です: ${carriedItem!.name}');
      return;
    }

    // 物理挙動を無効にする
    carryItem.physicsBehavior.setEnabled(false);
    carryItem.physicsBehavior.velocity = Vector2.zero();

    // インベントリからアイテムを消費（初期化時のロード時は、すでにバッグにないはず）
    if (itemBag.getItemCount(carryItem.name) > 0) {
      itemBag.removeItem(carryItem.name);
    }

    // ワールドに追加（置く/投げと同じ absoluteCenter 基準で追従）
    if (carryItem.isMounted) {
      debugPrint(
        'Player: Item ${carryItem.name} was already mounted, removing from parent.',
      );
      carryItem.removeFromParent();
    }

    debugPrint('Player: Adding item ${carryItem.name} to world.');
    await game.world.add(carryItem);
    carriedItem = carryItem;
    _syncCarriedItemWorldPosition();

    // 運搬中はアイテムの衝突判定を無効にする
    debugPrint('Player: Waiting for item ${carryItem.name} to load...');
    await carryItem.loaded;
    final hitboxes = carryItem.children.whereType<ShapeHitbox>();
    if (hitboxes.isNotEmpty) {
      hitboxes.first.collisionType = CollisionType.inactive;
      debugPrint('Player: Item hitbox set to inactive.');
    }

    // スプライトを再ロードして表示を確実にする
    if (carryItem.spritePath.isNotEmpty) {
      debugPrint(
        'Player: Reloading sprite for ${carryItem.name}: ${carryItem.spritePath}',
      );
      carryItem.sprite = await ItemFactory.loadDisplaySprite(
        game,
        carryItem.name,
        carryItem.spritePath,
      );
      await carryItem.attachWorldAnimationIfNeeded();
      carryItem.syncDisplayAnchor();
    }

    _syncCarriedItemWorldPosition();

    // UIを確実に更新するために、一度falseにしてからtrueにする（再起動時のロード対策）
    isCarryingItemNotifier.value = false;
    isCarryingItemNotifier.value = true;
    debugPrint('Player: isCarryingItemNotifier set to true.');

    GameUI.setPlaceButtonState(ActionButtonState.normal);
    GameUI.setStoreButtonState(ActionButtonState.normal);

    gameRuntimeState.carriedItemName = carryItem.name;
    debugPrint(
      'Player: startCarrying finished for ${carryItem.name}. Position: ${carryItem.position}',
    );
  }

  // アイテム運搬を終了するメソッド
  void stopCarrying() {
    if (carriedItem != null) {
      // ワールドから削除する
      carriedItem!.removeFromParent();
      carriedItem = null; // 荷下ろしなのでnullにする
      isCarryingItemNotifier.value = false; // 運搬モード終了
      GameUI.resetCarryingModeButtons(); // 運搬モードボタンをリセット

      // GameRuntimeStateの運搬アイテム情報をリセット
      gameRuntimeState.carriedItemName = null;
    }
  }

  /// 運搬アイテムを置く／投げるときのワールド座標（anchor=center）。
  Vector2 _carriedItemPlaceCenter(Item object) {
    final facing = facingDirection;
    if (facing.y < 0) {
      return absoluteCenter + Vector2(0, -size.y / 2);
    }
    if (facing.y > 0) {
      return absoluteCenter.clone();
    }
    return absoluteCenter + Vector2(facing.x * 25, 0);
  }

  // ワールドにアイテムオブジェクトを配置するメソッド
  Future<void> placeWorldObject(Item object) async {
    final newPosition = _carriedItemPlaceCenter(object);

    // 運搬を終了
    stopCarrying();

    final item = ItemFactory.createPlacedWorldItemByName(object.name, newPosition);
    if (item != null) {
      item.isCollected = true;
      game.world.add(item);
      await ItemFactory.applyPlacedWorldItemWorldDisplay(item);
      item.physicsBehavior.setEnabled(true);
      await ItemFactory.registerPlacedLanternIfNeeded(item, game);
    }

    // GameRuntimeStateの運搬アイテム情報をリセット
    gameRuntimeState.carriedItemName = null;
  }

  Future<void> throwWorldObject(Item object) async {
    final newPosition = _carriedItemPlaceCenter(object);

    // Stage 2 の追尾ギミック：近くの敵に吸い付く
    Vector2 finalPosition = newPosition;
    if (gameRuntimeState.currentOutdoorSceneId == 'outdoor_2') {
      final enemies = game.world.children.whereType<EnemyBase>();
      EnemyBase? nearestEnemy;
      double minDistance = 150.0;

      for (final enemy in enemies) {
        final distance = (absolutePosition - enemy.absolutePosition).length;
        if (distance < minDistance) {
          minDistance = distance;
          nearestEnemy = enemy;
        }
      }

      if (nearestEnemy != null) {
        // 最適な攻撃位置（敵の少し横）にニュルっと移動
        final targetX = nearestEnemy.position.x - (facingDirection.x * 40);
        position.x = lerpDouble(position.x, targetX, 0.5)!;
      }
    }

    // await item.loaded の間に複数フレームが進み velocity が 0 に戻るため、
    // 投げ操作時点の水平速度・向きを先に確定させる。
    final double snapshotSpeedX = velocity.x;
    final double snapshotFacingX = facingDirection.x;

    // 運搬を終了
    stopCarrying();

    final item = ItemFactory.createPlacedWorldItemByName(object.name, finalPosition);
    if (item != null) {
      item.isCollected = true;
      game.world.add(item);
      await ItemFactory.applyPlacedWorldItemWorldDisplay(item);

      // プレイヤーの向きに応じて水平方向の力を設定
      final horizontalThrowForce =
          snapshotSpeedX.abs() * powerOfPlayer * snapshotFacingX;
      item.physicsBehavior.setVelocity(Vector2(horizontalThrowForce, -30));
      item.physicsBehavior.setEnabled(true);
      await ItemFactory.registerPlacedLanternIfNeeded(item, game);
    }

    // GameRuntimeStateの運搬アイテム情報をリセット
    gameRuntimeState.carriedItemName = null;
  }

  /// 装備中ツールを投げ、バッグから 1 つ消費する（UI / ToolEffectResolver 用）。
  Future<void> throwEquippedToolItem() async {
    final itemName = itemBag.equippedItemName;
    if (itemName == null) return;
    final template = ItemFactory.createItemByName(itemName, Vector2.zero());
    if (template == null) return;
    await throwWorldObject(template);
    itemBag.removeItem(itemName, count: 1);
  }

  // アイテムウィンドウ用メソッド --------------------------------------------------------------------------------
  // ToolItemを装備するメソッド (後で実装)
  void equipItem(String itemName) {
    debugPrint('ツール $itemName を装備しました。');
    game.windowManager.showDialog(
      ['$itemName を装備しました。'],
    );
    itemBag.equipItem(itemName);
  }

  // ToolItemを解除するメソッド (後で実装)
  void unequipItem(String itemName) {
    debugPrint('ツール $itemName を解除しました。');
    game.windowManager.showDialog(
      ['$itemName を解除しました。'],
    );
    itemBag.unequipItem();
  }

  // 配置可能アイテムを全て廃棄するメソッド (個数を指定して捨てるという需要がなさそうなので全て捨てる)
  void disposePlaceableItem(Item item) {
    debugPrint('配置可能アイテム ${item.name} を廃棄しました。');
    game.windowManager.showDialog(
      ['${item.name} を廃棄しました。'],
    );
    itemBag.removeItem(item.name, count: 0);
  }

  // 宝石を眺めるメソッド (後で実装)
  void viewGem(Item gem) {
    debugPrint('宝石 ${gem.name} を眺めました。');
    game.windowManager.showDialog(
      ['${gem.name} を眺められる機能って必要？俺はいらないと思う。', 'あってもいいけど。'],
    );
  }

  // プレイヤー音源 メソッド ==============================================================================

  Future<void> requestPlayPlayerSound(
    String type, {
    double volume = 1.0,
    double playbackRate = 1.0,
  }) async {
    if (!audioManager.soloud.isInitialized) return;
    final sources = _playerSounds[type];
    if (sources == null || sources.isEmpty) return;

    try {
      final soundToPlay = sources[Random().nextInt(sources.length)];
      final SoundHandle handle = await audioManager.soloud.play(
        soundToPlay,
        volume: volume,
      );
      audioManager.soloud.setRelativePlaySpeed(handle, playbackRate);
    } catch (e) {
      // エラーログ
    }
  }

  // 衝突ロジック メソッド ==============================================================================

  void _handleUnderGroundPostMove(double dt) {
    final currentScene = game.sceneManager.currentScene;
    if (currentScene is! AbstractOutdoorScene) {
      return;
    }
    final ground = currentScene.groundComponent;
    if (ground == null) return;

    if (inUnderGround && isDigging && velocity.y < 0) {
      final groundBottomY = ground.position.y + ground.groundHeight;
      if (position.y < groundBottomY) {
        position.y = groundBottomY;
        velocity.y = 0;
      }
    }

    // アイテム吸引 (Efficiency能力)
    final double autoPickupRange = gameRuntimeState.automationAutoPickupVacuumRange;
    final double pullRange =
        vacuumRange > autoPickupRange ? vacuumRange : autoPickupRange;
    if (pullRange > 0) {
      final items = game.world.children.whereType<Item>().where((i) => !i.isCollected);
      for (final item in items) {
        final dist = (absoluteCenter - item.absolutePosition).length;
        if (dist < pullRange) {
          // プレイヤーの方へ引き寄せる
          final dir = (absoluteCenter - item.absolutePosition).normalized();
          item.position += dir * 200 * dt;
          if (dist < 20) {
            collectItem(item);
          }
        }
      }
    }
  }

  // エフェクト管理 メソッド ==============================================================================

  void setAmbientColorFilter(ColorFilter? filter) {
    _ambientColorFilter = filter;
    if (!_isTintedRed) {
      _applyActiveColorFilter();
    }
  }

  void _applyActiveColorFilter() {
    if (_isTintedRed) {
      paint.colorFilter = ColorFilter.mode(
        const Color.fromARGB(200, 255, 0, 0),
        BlendMode.srcATop,
      );
      return;
    }
    paint.colorFilter = _ambientColorFilter;
  }

  void updateEffect() {
    // 耐久力が350以下の場合の画面全体のエフェクト管理
    if (currentIntegrity <= 350) {
      if (game.camera.viewport.children.whereType<HpLowEffect>().isEmpty) {
        game.camera.viewport.add(HpLowEffect()); 
      }
    } else {
      // 耐久力が350より大きい場合、既存のHpLowEffectがあれば削除
      game.camera.viewport.children.whereType<HpLowEffect>().forEach((e) {
        e.removeFromParent();
      });
    }
  }

  // 物理挙動管理 メソッド ==============================================================================

  void _tickContactKnockbackCooldowns(double dt) {
    if (_contactKnockbackCooldownBySource.isEmpty) return;
    for (final key in _contactKnockbackCooldownBySource.keys.toList()) {
      _contactKnockbackCooldownBySource[key] =
          _contactKnockbackCooldownBySource[key]! - dt;
    }
    _contactKnockbackCooldownBySource.removeWhere((_, t) => t <= 0);
  }

  /// 接触時のノックバック（力積 p = mass × velocity、Δv = p × scale / プレイヤー質量）。
  void applyKnockbackFromContact(ContactKnockbackSource other) {
    if (unbeatable) return;

    final sourceKey = identityHashCode(other);
    if ((_contactKnockbackCooldownBySource[sourceKey] ?? 0) > 0) return;

    var contactVelocity = other.contactVelocity.clone();

    // 静止に近い接触: 分離方向へ最低速度を与える
    if (contactVelocity.length2 < 25) {
      var away = absoluteCenter - other.absoluteCenter;
      if (away.length2 < 1.0) {
        contactVelocity = Vector2(
          other.contactFallbackDirectionX * KnockbackConfig.minContactSpeed,
          0,
        );
      } else {
        away.normalize();
        contactVelocity = away * KnockbackConfig.minContactSpeed;
      }
    }

    // p = m * v → Δv = p * scale / m_player
    // 車 (mass≈100) を基準に、それより軽い歩行者は質量比で飛び量を抑える
    final impulse = contactVelocity * other.contactMass;
    final massWeight = (other.contactMass / KnockbackConfig.contactReferenceMass)
        .clamp(0.2, 3.0);
    var deltaV =
        impulse * (KnockbackConfig.contactImpulseScale / mass) * massWeight;

    // 極端な速度は物理サブステップ増加の原因になるため上限を設ける
    if (deltaV.x.abs() > KnockbackConfig.maxContactDeltaVX) {
      deltaV.x = KnockbackConfig.maxContactDeltaVX * deltaV.x.sign;
    }

    velocity.x += deltaV.x;
    if (isOnGround) {
      if (deltaV.y < 0) {
        velocity.y = min(velocity.y, deltaV.y);
      } else {
        velocity.y = min(
          velocity.y,
          -deltaV.x.abs() * KnockbackConfig.contactGroundBounceFromHorizontal,
        );
      }
    } else {
      velocity.y += deltaV.y;
    }

    _knockbackTimer = KnockbackConfig.playerKnockbackDuration;
    _contactKnockbackCooldownBySource[sourceKey] =
        KnockbackConfig.contactKnockbackCooldown;
  }

  void setPhysicsBehavior({
    required bool applyGravity,
    required bool enableHorizontalPhysics,
    required bool enableVerticalMovement,
  }) {
    _applyGravity = applyGravity;
    _enableHorizontalPhysics = enableHorizontalPhysics;
    _enableVerticalMovement = enableVerticalMovement;
  }

  // override メソッド ==============================================================================

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is EnemyBase) {
      final isNewContact = !_collidingEnemies.contains(other);
      _collidingEnemies.add(other);
      isTouchingEnemy = true;

      applyKnockbackFromContact(other);

      requestPlayPlayerSound('hits', volume: 0.8, playbackRate: 1.0);

      if (!unbeatable && isNewContact) {
        double totalAttackStress = 0.0;
        for (final enemy in _collidingEnemies) {
          totalAttackStress += enemy.attackStress;
        }
        updateStress(currentStress + totalAttackStress);
        if (totalAttackStress > 1e-6 && _contactResidueBurstCooldown <= 0) {
          ResiduePickup.spawnCaptureResistantBurst(
            game,
            ResiduePickup.worldEmitOrigin(this),
            intensity: (totalAttackStress / 25).clamp(0.35, 2.5),
          );
          _contactResidueBurstCooldown =
              KnockbackConfig.contactResidueBurstCooldown;
        }
      }

      // ダメージエフェクトの適用 (プレイヤー自身に - ColorFilterを使用)
      if (!_isTintedRed) {
        _isTintedRed = true;
        _tintTimer = 0.2; // 0.2秒間赤くする
        _applyActiveColorFilter();
      }
    }

    if (other is Npc) {
      applyKnockbackFromContact(other);
    }

    if (other is Item && other.name == 'はしご') {
      _activeLadders.add(other);
      _updateUpButtonState();
    }

    // 衝突相手がソリッドなコンポーネントであれば_solidCollisionsに追加
    bool isOtherSolid = other.children.whereType<ShapeHitbox>().any(
      (h) => h.isSolid,
    );

    if (isOtherSolid) {
      _solidCollisions.add(other);
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is EnemyBase) {
      _collidingEnemies.add(other);
      isTouchingEnemy = true;
    }

    // 現在のシーンが屋外シーンであることを確認
    final currentScene = game.sceneManager.currentScene;
    if (currentScene is AbstractOutdoorScene) {
      // UnderGroundとの衝突処理（掘削は _tickDigCarve が担当）
      if (other == currentScene.underGround) {
        if (isDigging) {
          return;
        }
        // 岩盤の当たりは terrainField が担当（巨大スラブで吸着しない）
      }
      // Groundとの衝突処理
      else if (other == currentScene.ground) {
        // Groundは常にソリッドとして扱うので、_solidCollisionsに追加
        _solidCollisions.add(other);
      }
      // Stationとの衝突処理
      else if (other is Station) {
        if (other.platformHitbox.isSolid) {
          _solidCollisions.add(other);

          // 衝突点の中で最も高いY座標を見つける (プレイヤーが乗り上げる面の上端)
          final highestIntersectionY =
              intersectionPoints.fold<double>(
                double.infinity,
                (prev, current) => current.y < prev ? current.y : prev,
              ) -
              (size.y / 2);

          // プレイヤーが落下中または静止中で、かつプラットフォームを貫通している場合
          if (velocity.y >= 0 && position.y > highestIntersectionY) {
            position.y = highestIntersectionY;
            velocity.y = 0;
          }
        }
      }
      // その他のソリッドなコンポーネント
      else {
        bool isOtherSolid = other.children.whereType<ShapeHitbox>().any(
          (h) => h.isSolid,
        );
        if (isOtherSolid) {
          _solidCollisions.add(other);
        }
      }
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);

    if (other is EnemyBase) {
      _collidingEnemies.remove(other);
      if (_collidingEnemies.isEmpty) {
        isTouchingEnemy = false;
      }
    }

    if (other is Item && other.name == 'はしご') {
      _activeLadders.remove(other);
      _updateUpButtonState();
    }

    _solidCollisions.remove(other);
    //debugPrint('Removed ${other.runtimeType} from _solidCollisions. Current solids: ${_solidCollisions.map((c) => c.runtimeType).join(', ')}');
  }

  @override
  void render(Canvas canvas) {
    renderWithComponentLighting(canvas, super.render);
  }
}

// デバッグ描画用のコンポーネント
class DebugRenderer extends PositionComponent {
  Vector2? collisionPoint;
  Vector2? playerCenter;
  static const double pointSize = 5.0;

  // Paintオブジェクトをフィールドとして定義
  final centerPaint =
      Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;

  final collisionPaint =
      Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;

  final linePaint =
      Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

  DebugRenderer() : super(priority: 1000);

  @override
  void render(Canvas canvas) {
    if (collisionPoint != null && playerCenter != null) {
      // プレイヤーの中心を描画（青色）
      canvas.drawCircle(
        Offset(playerCenter!.x, playerCenter!.y),
        pointSize,
        centerPaint,
      );

      // 衝突点を描画（赤色）
      canvas.drawCircle(
        Offset(collisionPoint!.x, collisionPoint!.y),
        pointSize,
        collisionPaint,
      );

      // 中心から衝突点までの線を描画（黄色）
      canvas.drawLine(
        Offset(playerCenter!.x, playerCenter!.y),
        Offset(collisionPoint!.x, collisionPoint!.y),
        linePaint,
      );
    }
  }
}

class PositionSnapshot {
  final double x;
  final double y;
  final int frame;

  PositionSnapshot(this.x, this.y, this.frame);

  double distanceTo(PositionSnapshot other) {
    return sqrt(pow(x - other.x, 2) + pow(y - other.y, 2));
  }
}
