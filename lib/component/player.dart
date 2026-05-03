import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' show lerpDouble;
import '../main.dart';
import '../UI/game_ui.dart';
import 'game_stage/building/station.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'game_stage/building/destructible_object.dart';
import 'game_stage/building/hideable_object.dart';
import 'effect/hiding_vignette.dart';
import 'item/item_bag.dart';
import 'item/item.dart';
import '../scene/abstract_outdoor_scene.dart'; // AbstractOutdoorSceneをインポート
import 'enemy/enemy_base.dart';
import 'common/underground/underground.dart';
import '../scene/game_scene.dart'; // GameSceneをインポート
import '../game_manager/audio_manager.dart'; // Add this line
import '../system/storage/game_runtime_state.dart'; // GameRuntimeStateをインポート
import 'npc/npc.dart';
import '../component/effect/hp_low_effect.dart';

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
    with CollisionCallbacks, HasGameReference<MyGame> {
  static const double speed = 180.0;
  static const double powerOfPlayer = 1.25;
  static const double gravity = 700.0;
  static const double jumpForce = -250.0; // 少し弱める
  static const double maxJumpTime = 0.25; // ジャンプ持続時間の最大値

  // 属性による能力強化の計算
  double get effectiveSpeed {
    final state = game.gameRuntimeState;
    final attr = game.missionManager.getCurrentAttribute();
    final level = game.missionManager.getAttributeLevel();
    
    double base = speed;
    
    // 周回ボーナス（キャリブレーション適用）
    base *= (1.0 + (state.movementSpeedBonus - 1.0) * state.speedCalibrationScale);

    // 属性レベルボーナス（リアルタイム）
    if (attr == GameRuntimeState.routeEfficiency) {
      base *= (1.0 + (level * 0.2)); // Level 3 で 1.6倍
    }
    return base;
  }

  double get effectiveGravity {
    final state = game.gameRuntimeState;
    final attr = game.missionManager.getCurrentAttribute();
    final level = game.missionManager.getAttributeLevel();
    
    double base = gravity;
    
    // 哲学ボーナス（キャリブレーション適用：投擲力の一部を重力軽減に転用するイメージ）
    double philosophyEffect = (state.throwPowerBonus - 1.0) * state.powerCalibrationScale;
    base *= (1.0 - (philosophyEffect * 0.5));

    // 属性レベルボーナス（リアルタイム）
    if (attr == GameRuntimeState.routePhilosophy) {
      base *= (1.0 - (level * 0.2)); // Level 3 で 0.4倍
    }
    return base;
  }

  double get effectiveMeleeSizeScale {
    final state = game.gameRuntimeState;
    final attr = game.missionManager.getCurrentAttribute();
    final level = game.missionManager.getAttributeLevel();
    
    double bonusScale = 1.0;
    // HPボーナスの一部を体格（攻撃範囲）に反映
    bonusScale += (state.hpBonus / 1000.0) * state.hpCalibrationScale;

    if (attr == GameRuntimeState.routeViolence) {
      bonusScale += (level * 0.5); // Level 3 で +1.5
    }
    return bonusScale;
  }

  double get vacuumRange {
    final state = game.gameRuntimeState;
    final attr = game.missionManager.getCurrentAttribute();
    final level = game.missionManager.getAttributeLevel();
    
    double range = 0.0;
    if (attr == GameRuntimeState.routeEfficiency && level >= 1) {
      range = 50.0 + (level * 50.0); // Level 3 で 200px
    }
    
    // キャリブレーションによる調整（効率ボーナスが溜まっている場合）
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

  // HPの変更を通知するためのValueNotifier
  final ValueNotifier<double> hpNotifier = ValueNotifier<double>(1000.0);
  double maxHp = 1000.0;
  double get currentHp => hpNotifier.value;

  // ストレスの変更を通知するためのValueNotifier
  final ValueNotifier<double> stressNotifier = ValueNotifier<double>(0.0);
  double maxStress;
  double get currentStress => stressNotifier.value;

  // お金ポイント
  final CurrencyNotifier currencyNotifier;
  int get moneyPoints => currencyNotifier.value;

  // 採掘ポイント
  final MiningPointsNotifier miningPointsNotifier;
  int get currentMiningPoints => miningPointsNotifier.value;

  Vector2 get facingDirection {
    if (isMovingLeft) {
      _lastMoveDirection.x = -1;
      return Vector2(-1, 0);
    } else if (isMovingRight) {
      _lastMoveDirection.x = 1;
      return Vector2(1, 0);
    } else if (_lastMoveDirection.x != 0) {
      return Vector2(_lastMoveDirection.x.sign, 0);
    } else {
      // アイドル状態の場合、_lastMoveDirection.xを水平方向として返す
      return Vector2(_lastMoveDirection.x.sign, 0);
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

  double _idleTimer = 0.0; // アイドル状態の時間を計測するタイマー
  static const double _idleThreshold = 3.0; // 4秒

  // New flags to control physics behavior based on scene
  bool _applyGravity = true;
  bool _enableHorizontalPhysics = true;
  bool _enableVerticalMovement = true;

  final Set<PositionComponent> _solidCollisions = {};
  final Set<EnemyBase> _collidingEnemies = {};
  final Set<Item> _activeLadders = {}; // 接触中のはしごを保持

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

  // movingAnimationの最終フレームインデックスを追跡
  int _lastMovingAnimationFrameIndex = -1;

  final GameRuntimeState gameRuntimeState; // GameRuntimeStateを追加
  final ItemBag itemBag;
  final AudioManager audioManager; // Add this line

  double _lastPlayerX = 0.0; // プレイヤーの前のX座標を追跡

  Player({
    super.position,
    required this.itemBag,
    required this.gameRuntimeState,
    required this.audioManager,
  }) : maxStress = gameRuntimeState.maxStress, // 初期値をGameRuntimeStateから取得
       currencyNotifier = CurrencyNotifier(gameRuntimeState.currency),
       miningPointsNotifier = MiningPointsNotifier(
         gameRuntimeState.miningPoints,
       ),
       super(size: Vector2.all(50), anchor: Anchor.center);

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

    // 画像の読み込み
    final spriteSheet01 = await game.images.load('player01_anim.png');
    final spriteSheet02 = await game.images.load('player02_anim.png');

    // 静止状態のアニメーション（1-2フレーム） -> idleFrontAnimation
    idleFrontAnimation = SpriteAnimation.fromFrameData(
      spriteSheet01,
      SpriteAnimationData.variable(
        amount: 2,
        stepTimes: [2, 0.4],
        textureSize: Vector2.all(50),
        loop: true,
      ),
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

    // 左向き歩行アニメーション（4-5フレーム）
    final movingLeftSprites = [
      Sprite(
        spriteSheet01,
        srcPosition: Vector2(50 * 3, 0), // 4番目のフレーム (インデックス3)
        srcSize: Vector2.all(50),
      ),
      Sprite(
        spriteSheet01,
        srcPosition: Vector2(50 * 4, 0), // 5番目のフレーム (インデックス4)
        srcSize: Vector2.all(50),
      ),
    ];
    movingLeftAnimation = SpriteAnimation.spriteList(
      movingLeftSprites,
      stepTime: 0.2,
      loop: true,
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
    game.cameraController.resetBackgroundParallax();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (gameRuntimeState.isAutoPlay) {
      _performAutoPlay(dt);
      _handleUnderGroundAndGroundCollisionLogic(dt);
      return;
    }

    // 属性レベルの取得
    final attr = game.missionManager.getCurrentAttribute();
    final level = game.missionManager.getAttributeLevel();

    // 背景パララックスの更新
    final double currentPlayerX = position.x;
    final double playerDx = currentPlayerX - _lastPlayerX;
    if (playerDx != 0) {
      // プレイヤーが移動した場合のみ背景を更新
      game.cameraController.updateBackgroundParallax(playerDx);
    }
    _lastPlayerX = currentPlayerX; // 現在のX座標を更新

    // ストレス値の自動回復 と ストレスに応じた健康被害
    updateStress(currentStress - 10 * dt);
    if (currentStress >= 25 && !unbeatable) {
      updateHp(currentHp - (currentStress / maxStress));
    }

    // Empathy Lv3: NPCの近くで回復
    if (attr == GameRuntimeState.routeEmpathy && level >= 3) {
      final npcs = game.world.children.whereType<Npc>();
      bool isNearNpc = false;
      for (final npc in npcs) {
        if ((absolutePosition - npc.absolutePosition).length < 100) {
          isNearNpc = true;
          break;
        }
      }
      if (isNearNpc) {
        recoveryHp(100 * dt); // 毎秒100回復
        updateStress(currentStress - 200 * dt); // 毎秒200ストレス軽減
      }
    }

    // 地下でのベース処理
    if (inUnderGround) {
      // 地下での自動hp回復
      if (currentHp < (maxHp / 2) && currentStress < 25) {
        recoveryHp(30 * dt);
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

    // ゲームオーバー
    if (currentHp <= 0 && !game.isGameOver) {
      game.gameOver();
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
        paint.colorFilter = null; // フィルターを解除
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
        if (_lastMoveDirection.x > 0) {
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

    // 水平方向の移動
    if (_enableHorizontalPhysics) {
      if (isDigging) {
        // 掘削中の水平移動速度
        if (inUnderGround) {
          velocity.x =
              (isMovingRight ? effectiveSpeed * 0.5 : (isMovingLeft ? -effectiveSpeed * 0.5 : 0));
        } else {
          // 地上での掘削中の水平移動は無効
          velocity.x = 0;
        }
        animation = diggingAnimation;
      } else if (iscrouching) {
        // しゃがみ状態の水平移動速度
        if (velocity.x.abs() > 0.1) {
          // 完全に停止するまでのしきい値
          velocity.x *= 0.9;
        } else {
          velocity.x = 0;
        }
        animation = crouchingAnimation;
      } else {
    // 通常の水平移動速度
    double currentBaseSpeed = effectiveSpeed;
    if (isRunning) {
      currentBaseSpeed *= 1.5; // ダッシュ時は1.5倍
    }
    velocity.x = (isMovingRight ? currentBaseSpeed : (isMovingLeft ? -currentBaseSpeed : 0));

        if (isMovingRight) {
          animation = movingRightAnimation;
          _lastMoveDirection.x = 1.0;
        } else if (isMovingLeft) {
          animation = movingLeftAnimation;
          _lastMoveDirection.x = -1.0;
        }
      }
    } else {
      velocity.x = 0;
      if (isDigging) {
        animation = diggingAnimation;
      } else {
        // 水平移動が無効な場合でも、アイドルタイマーによってアニメーションが決定される
        // ここでは何もしない
      }
    }

    // 明示的に水平位置を更新
    position.x += velocity.x * dt;

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
        if (isMovingUp) {
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

        // まずは重力による影響を計算
        if (_applyGravity && !_isJumping) {
          double gravityForce = effectiveGravity;
          
          // 哲学能力：空中浮遊 (Levitation)
          final attr = game.missionManager.getCurrentAttribute();
          final level = game.missionManager.getAttributeLevel();
          if (attr == GameRuntimeState.routePhilosophy && level >= 2 && isJumpButtonPressed && velocity.y > 0) {
            gravityForce *= 0.1; // 落下速度を大幅に軽減
          }
          
          velocity.y += gravityForce * dt;
        }

        // isOnGroundの判定は、_solidCollisionsと現在の垂直速度に基づく
        bool newIsOnGround = false; // 新しいisOnGroundの状態を一時的に保持

        // プレイヤーの足元に幅を持つ当たり判定を作成
        final Rect playerFootRect = Rect.fromLTWH(
          absolutePosition.x -
              size.x * 0.05, // プレイヤーの中心から幅の半分だけ左にオフセット (幅0.1の半分)
          absolutePosition.y + size.y / 2, // プレイヤーの足元の最下部に正確に合わせる
          size.x * 0.1, // プレイヤーの幅の10%を使用
          2, // 厚み
        );

        // _solidCollisions内の各衝突をチェック
        for (final collision in _solidCollisions) {
          if (collision.toRect().overlaps(playerFootRect)) {
            newIsOnGround = true;
            break;
          }
        }

        // 垂直速度が0以上かつ下向きの速度がある場合は接地とみなす
        if (newIsOnGround && velocity.y >= 0) {
          velocity.y = 0; // 地面にいる場合は垂直速度を0に固定
          _isJumping = false; // 着地したのでジャンプ終了
        }

        isOnGround = newIsOnGround; // 新しい接地状態を適用

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
          } else if (velocity.y > 50) {
            // 落下中
            animation = fallingAnimation;
          }
        } else if (!isDigging && !iscrouching) {
          // 地上にいて掘削中でなく、しゃがみ中でもない場合
          // 地上にいて掘削中でない場合
          if (isMovingRight) {
            animation = movingRightAnimation;
            _lastMoveDirection.x = 1.0;
          } else if (isMovingLeft) {
            animation = movingLeftAnimation;
            _lastMoveDirection.x = -1.0;
          } else {
            // 移動していない場合、アニメーションはアイドルタイマーによって決定される
            // ここでは何もしない
          }
        }
      }

      // 全ての計算後に最終的な垂直速度を適用
      position.y += velocity.y * dt;

      // 運搬中のアイテムをプレイヤーの頭上に固定
      if (carriedItem != null) {
        carriedItem!.position = Vector2(size.x / 2, 0);
      }
    }

    // 画面の端でプレイヤーを停止させる
    if (game.sceneManager.currentScene != null &&
        game.sceneManager.currentScene!.groundComponent != null) {
      final ground = game.sceneManager.currentScene!.groundComponent!;
      position.x = position.x.clamp(
        ground.position.x + 10,
        ground.position.x + ground.size.x - 10,
      );

      // 落下限界点の定義
      if (!inUnderGround &&
          velocity.y >= 0 &&
          position.y > ground.position.y + 300) {
        position.y = ground.position.y + ground.groundHeight;
      }
    }

    // プレイヤーの向きに応じてリスナーの 'at' ベクトルを設定
    Vector2 listenerAt;
    if (velocity.x != 0) {
      // 水平移動がある場合
      listenerAt = Vector2(velocity.x.sign, 0.0); // 移動方向に合わせる
      _lastMoveDirection = listenerAt; // 最後の移動方向を更新
    } else {
      // 移動していない場合は、最後に移動していた方向を維持
      listenerAt = _lastMoveDirection;
    }

    game.audioManager.updateListener(
      position, // プレイヤーの現在の位置
      listenerAt, // プレイヤーが向いている方向
      Vector2(0.0, 1.0), // 2Dゲームにおける上方向
    );

    _handleUnderGroundAndGroundCollisionLogic(dt);
  }

  // オートプレイ用のロジック
  void _performAutoPlay(double dt) {
    // Stage 6 (Despair) で右に向かって自動で歩き続ける
    isMovingRight = true;
    isMovingLeft = false;
    isMovingUp = false;
    isMovingDown = false;

    // 通常の移動処理
    velocity.x = effectiveSpeed * 0.7; // 少しゆっくり歩く
    animation = movingRightAnimation;
    position.x += velocity.x * dt;

    // パララックス更新
    final double playerDx = velocity.x * dt;
    game.cameraController.updateBackgroundParallax(playerDx);
    _lastPlayerX = position.x;

    // 崖（世界の右端）に到達したらリセット（飛び降り または 帰還）
    if (position.x > 1000) { 
      debugPrint('AutoPlay: Reached the edge. Returning to Stage 1...');
      game.routeClear(); // 周回クリア処理
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
    
    // 属性とレベルの取得
    final attr = game.missionManager.getCurrentAttribute();
    final level = game.missionManager.getAttributeLevel();
    final isViolenceLv3 = attr == GameRuntimeState.routeViolence && level >= 3;

    // 攻撃音（属性レベルに応じてピッチや音質をリアルタイム変化させる）
    double playbackRate = 1.1;
    double volume = 1.0;
    
    if (attr == GameRuntimeState.routeViolence) {
      playbackRate -= (level * 0.1); // 重厚な音へ
      volume += (level * 0.2);
    } else if (attr == GameRuntimeState.routeEfficiency) {
      playbackRate += (level * 0.1); // 鋭い音へ
    }
    
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
      paint: Paint()..color = (isViolenceLv3 ? Colors.redAccent : Colors.white).withOpacity(0.4),
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
        if (isViolenceLv3) {
          // 即死級ダメージ（healthを0にするなど）
          obj.onHit();
          obj.onHit(); // 2回呼んで確実に壊すか、DestructibleObject側の調整が必要
        } else {
          obj.onHit();
        }
      }
    }

    // 敵
    final enemies = currentScene.children.whereType<EnemyBase>();
    for (final enemy in enemies) {
      if (enemy.toAbsoluteRect().overlaps(attackRect)) {
        debugPrint('Melee Hit: Enemy at ${enemy.position}');
        if (game.gameRuntimeState.currentOutdoorSceneId == 'outdoor_2') {
          game.missionManager.onAction(GameRuntimeState.routeViolence);
        }
        
        if (isViolenceLv3) {
          // Violence Lv3: 即死 + アイテム化
          enemy.dieAndDropItem();
        } else {
          // ノックバックの計算: 向きと威力(scale)に基づく
          final impulse = Vector2(facingDirection.x * 300 * scale, -50 * scale);
          enemy.hitByMelee(impulse);
        }
      }
    }
    
    // NPC
    final npcs = currentScene.children.whereType<Npc>();
    for (final npc in npcs) {
      if (npc.toAbsoluteRect().overlaps(attackRect)) {
        debugPrint('Melee Hit: NPC at ${npc.position}');
        if (isViolenceLv3) {
          // Violence Lv3: NPCも殺害してアイテム化
          npc.dieAndDropItem();
        }
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
    final bool isDiggingOnGround = diggingState != null && diggingState;

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
    // Efficiency Lv3 または canRun フラグが真の場合にダッシュ可能
    final attr = game.missionManager.getCurrentAttribute();
    final level = game.missionManager.getAttributeLevel();
    final isEfficiencyLv3 = attr == GameRuntimeState.routeEfficiency && level >= 3;

    if (!gameRuntimeState.canRun && !isEfficiencyLv3) return;
    
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
    iscrouching = GameUI.downButtonPressedNotifier.value && !isDigging;
  }

  // ステータス管理メソッド ==============================================================================

  // HPを更新するメソッド
  void updateHp(double newHp) {
    final state = game.gameRuntimeState;
    double effectiveMaxHp = maxHp + (state.hpBonus * state.hpCalibrationScale);
    hpNotifier.value = newHp.clamp(0.0, effectiveMaxHp);
  }

  // 自然回復
  void recoveryHp(double recoveryHp) {
    updateHp(hpNotifier.value + recoveryHp);
  }

  // ストレス値を更新するメソッド
  void updateStress(double newStress) {
    final state = game.gameRuntimeState;
    double effectiveMaxStress = maxStress + (state.stressBonus * state.stressCalibrationScale);
    stressNotifier.value = newStress.clamp(0.0, effectiveMaxStress);
  }

  // 最大ストレス値を増やすメソッド
  void addMaxStress(double addStress) {
    maxStress = (maxStress + addStress).clamp(50.0, 300.0);
    gameRuntimeState.maxStress = maxStress; // GameRuntimeStateを更新
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
    
    // 能動性（余計な行動）の加算
    // 石やクオーツなどの基本アイテムを拾うのは「余計な行動」とする
    if (item.type == ItemType.gem || item.name == '石') {
      gameRuntimeState.addExtraAction(game);
      
      // Stage 1の石拾いミッション更新
      if (item.name == '石') {
        game.missionManager.onPickupStone(itemBag.getItemCount('石'));
      }
    }

    // ロケットパーツの拾得時のミッション更新 (Stage 1)
    if (item.name == 'バルブ' || item.name == '点火装置' || item.name == 'ノズル' || item.name == '石') {
      game.missionManager.onPickupRocketPart();
    }

    // コレクションアイテム拾得時のルート進行 (Stage 2-6)
    if (item.type == ItemType.collection && 
        item.name != 'バルブ' && item.name != '点火装置' && item.name != 'ノズル' && 
        item.name != '石') {
      game.missionManager.onPickupPhilosophyItem(); // 汎用的な進行トリガーとして使用
    }
  }

  // アイテム運搬メソッド --------------------------------------------------------------------------------
  // アイテム運搬を開始するメソッド
  Future<void> startCarrying(Item item) async {
    // 運搬アイテムの重複チェック
    if (carriedItem != null) {
      if (carriedItem!.name == item.name) {
        // 同じアイテムをすでに持っている場合は、位置だけ再設定して早期リターン
        carriedItem!.position = Vector2(0, -30);
        isCarryingItemNotifier.value = true;
        return;
      }
      debugPrint('すでに別のアイテムを運搬中です: ${carriedItem!.name}');
      return;
    }

    // 物理挙動を無効にする
    item.physicsBehavior.setEnabled(false);
    item.physicsBehavior.velocity = Vector2.zero();

    // インベントリからアイテムを消費（初期化時のロード時は、すでにバッグにないはず）
    if (itemBag.getItemCount(item.name) > 0) {
      itemBag.removeItem(item.name);
    }

    // プレイヤーの子として追加
    if (item.isMounted) {
      item.removeFromParent();
    }
    add(item); 
    
    // アンカーを中央にし、プレイヤーの頭上に配置
    item.anchor = Anchor.center;
    item.position = Vector2(size.x / 2, -30); // プレイヤーの頭上(Playerの中心からの相対座標)

    // 運搬中はアイテムの衝突判定を無効にする
    await item.loaded;
    final hitboxes = item.children.whereType<ShapeHitbox>();
    if (hitboxes.isNotEmpty) {
      hitboxes.first.collisionType = CollisionType.inactive;
    }

    // スプライトを再ロードして表示を確実にする
    if (item.spritePath.isNotEmpty) {
      item.sprite = await game.loadSprite(item.spritePath);
    }

    carriedItem = item;
    // UIを確実に更新するために、一度falseにしてからtrueにする（再起動時のロード対策）
    isCarryingItemNotifier.value = false;
    isCarryingItemNotifier.value = true;
    
    GameUI.setPlaceButtonState(ActionButtonState.normal);
    GameUI.setStoreButtonState(ActionButtonState.normal);

    // GameRuntimeStateに運搬アイテムの情報を保存
    gameRuntimeState.carriedItemName = item.name;
    debugPrint('Player: Started carrying ${item.name}. Position set to ${item.position}');
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

  // ワールドにアイテムオブジェクトを配置するメソッド
  Future<void> placeWorldObject(Item object) async {
    final offset = facingDirection * 25;
    final newPosition = Vector2(position.x + offset.x, position.y);

    // 運搬を終了
    stopCarrying();

    final item = ItemFactory.createItemByName(object.name, newPosition);
    if (item != null) {
      item.isCollected = true;
      game.world.add(item);
      await item.loaded; // ItemのonLoadが完了するまで待機
      gameRuntimeState.addExtraAction(game); // 余計な行動としてカウント
    }

    // GameRuntimeStateの運搬アイテム情報をリセット
    gameRuntimeState.carriedItemName = null;
  }

  Future<void> throwWorldObject(Item object) async {
    final offset = facingDirection * 25;
    final newPosition = Vector2(position.x + offset.x, position.y - (size.y / 2));

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

    final item = ItemFactory.createItemByName(object.name, finalPosition);
    if (item != null) {
      item.isCollected = true;
      game.world.add(item);
      await item.loaded; // ItemのonLoadが完了するまで待機
      gameRuntimeState.addExtraAction(game); // 余計な行動としてカウント

      // プレイヤーの向きに応じて水平方向の力を設定
      final horizontalThrowForce =
          snapshotSpeedX.abs() * powerOfPlayer * snapshotFacingX;
      item.physicsBehavior.setVelocity(Vector2(horizontalThrowForce, -30));
      item.physicsBehavior.setEnabled(true);
    }

    // GameRuntimeStateの運搬アイテム情報をリセット
    gameRuntimeState.carriedItemName = null;
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
    if (game.gameRuntimeState.currentOutdoorSceneId == 'outdoor_3') {
      game.missionManager.onAction(GameRuntimeState.routeEfficiency); // ルート進行
    }
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

  void _handleUnderGroundAndGroundCollisionLogic(double dt) {
    final currentScene = game.sceneManager.currentScene;
    if (currentScene is! AbstractOutdoorScene) {
      return; // 屋外シーン以外では処理しない
    }
    final outdoorScene = currentScene; // AbstractOutdoorScene型であることが保証される

    final ground = outdoorScene.groundComponent; // outdoorSceneから取得
    final underGround = outdoorScene.underGround; // outdoorSceneから取得

    // 次のフレームの中心位置
    Vector2 predictedPosition = position + velocity * dt;

    // 掘削中でない場合のみ、未採掘ブロックとの衝突を処理
    if (inUnderGround && !isDigging) {
      Vector2 predictedPlayerHitboxEdge = Vector2.copy(
        predictedPosition,
      ); // predictedPositionのコピーを作成

      if (isMovingRight) {
        predictedPlayerHitboxEdge.x = predictedPosition.x + 15;
      }
      if (isMovingLeft) {
        predictedPlayerHitboxEdge.x = predictedPosition.x - 15;
      }

      // 方向に応じた予測衝突座標
      double blockEdgeWorldX = 0;
      // 貫通しているかのフラグ
      bool isPenetratingX = false;
      // 方向に応じた押し返しの量
      double pushBackAmountX = 0;

      if (!underGround.isDug(predictedPlayerHitboxEdge)) {
        if (isMovingRight) {
          blockEdgeWorldX =
              underGround.getGridCellTopLeftWorld(predictedPosition).x +
              UnderGround.digAreaSize;
          isPenetratingX = predictedPlayerHitboxEdge.x > blockEdgeWorldX;
          pushBackAmountX = -15;
        }
        if (isMovingLeft) {
          blockEdgeWorldX =
              underGround.getGridCellTopLeftWorld(predictedPosition).x;
          isPenetratingX = predictedPlayerHitboxEdge.x < blockEdgeWorldX;
          pushBackAmountX = 15;
        }

        if (isPenetratingX) {
          velocity.x = 0;
          position.x = blockEdgeWorldX + pushBackAmountX;
        }
      }

      // 地形に頭突きしたときの処理 ------------------------------------------------------- //
      final playerHeadY = position.y - (size.y / 2);
      final blockAtHead = underGround.getGridCellTopLeftWorld(
        Vector2(absoluteCenter.x, playerHeadY),
      );

      // 地上に頭突きしたときの処理
      if (playerHeadY <= ground!.position.y + ground.groundHeight + 5 &&
          velocity.y < 0) {
        position.y = ground.position.y - (size.y / 2);
        debugPrint('地上に頭突きしたときの処理');
      }

      // 未採掘エリアに頭突きしたときの処理
      if (!underGround.isDug(blockAtHead)) {
        velocity.y = 0;
        position.y = blockAtHead.y + UnderGround.digAreaSize + (size.y / 2);
      }

      // 採掘済みエリアで足が浮いていたら重力を効かせる -------------------------------- //
      final playerFootY = position.y + 25;
      final blockAtFoot = underGround.getGridCellTopLeftWorld(
        Vector2(absoluteCenter.x, playerFootY),
      );
      if (!underGround.isDug(blockAtFoot)) {
        velocity.y = 0;
        position.y = blockAtFoot.y - 23;
      }
    } else if (inUnderGround &&
        isDigging &&
        velocity.y < 0 &&
        predictedPosition.y < ground!.position.y + ground.groundHeight) {
      // --- 採掘中は地表に出ない --- //
      final groundBottomY = ground.position.y + ground.groundHeight;
      position.y = groundBottomY;
    }

    // アイテム吸引 (Efficiency能力)
    if (vacuumRange > 0) {
      final items = game.world.children.whereType<Item>().where((i) => !i.isCollected);
      for (final item in items) {
        final dist = (absoluteCenter - item.absolutePosition).length;
        if (dist < vacuumRange) {
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

  void updateEffect() {
    // HPが300以下の場合の画面全体のエフェクト管理
    if (currentHp <= 350) {
      if (game.camera.viewport.children.whereType<HpLowEffect>().isEmpty) {
        game.camera.viewport.add(HpLowEffect()); 
      }
    } else {
      // HPが300より大きい場合、既存のHpLowEffectがあれば削除
      game.camera.viewport.children.whereType<HpLowEffect>().forEach((e) {
        e.removeFromParent();
      });
    }
  }

  // 物理挙動管理 メソッド ==============================================================================

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
      _collidingEnemies.add(other);
      isTouchingEnemy = true;
      
      final attr = game.missionManager.getCurrentAttribute();
      final level = game.missionManager.getAttributeLevel();
      final isEmpathyLv3 = attr == GameRuntimeState.routeEmpathy && level >= 3;

      if (isEmpathyLv3) {
        // Empathy Lv3: 硬い音を再生
        requestPlayPlayerSound('hits', volume: 0.5, playbackRate: 0.5); // 低ピッチで硬い音
      } else {
        requestPlayPlayerSound('hits', volume: 0.8, playbackRate: 1.0);
      }

      // ストレス値とHPの更新
      // 衝突している敵からのストレス増加
      if (!unbeatable && _collidingEnemies.isNotEmpty) {
        double totalAttackStress = 0.0;
        for (final enemy in _collidingEnemies) {
          double stress = enemy.attackStress;
          if (isEmpathyLv3) stress *= 0.2; // ダメージ80%軽減
          totalAttackStress += stress;
        }
        updateStress(currentStress + totalAttackStress);
      }

      // ダメージエフェクトの適用 (プレイヤー自身に - ColorFilterを使用)
      if (!_isTintedRed) {
        _isTintedRed = true;
        _tintTimer = 0.2; // 0.2秒間赤くする
        paint.colorFilter = ColorFilter.mode(
          isEmpathyLv3 ? Colors.white.withOpacity(0.5) : const Color.fromARGB(200, 255, 0, 0), // Empathy Lv3は白っぽく光る
          BlendMode.srcATop, // レイヤーを重ねるモード
        );
      }
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
      final outdoorScene =
          currentScene as GameScene; // ここで非nullableなGameSceneとしてキャスト

      // UnderGroundとの衝突処理
      if (other == currentScene.underGround) {
        final collisionPoint = intersectionPoints.reduce((a, b) {
          return absoluteCenter.distanceTo(a) < absoluteCenter.distanceTo(b)
              ? a
              : b;
        });

        if (isDigging) {
          // 掘削中の場合
          if (!(outdoorScene as dynamic).isDug(collisionPoint)) {
            // ここでoutdoorSceneのupdateDigAreasを呼び出す
            (outdoorScene as dynamic).updateDigAreas(this);
            debugPrint('Dug new area at $collisionPoint');
            return;
          } else {
            return;
          }
        } else {
          _solidCollisions.add(other);
        }
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
