import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../player.dart';
import 'vehicle.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'dart:math';
import '../../UI/game_ui.dart';

import '../game_stage/building/station.dart';
import '../common/hitboxes/door_hitbox.dart';

enum TrainState {
  idle,
  movingToStation,
  stopping,
  waitingAtStation,
  leavingStation,
}

class Train extends Vehicle {
  late SpriteComponent _vehicleSprite;
  late SpriteComponent _doorSprite;

  bool _isDoorOpen = false;

  // ドアの状態に対応するスプライト
  late Sprite _doorClosedSprite;
  late Sprite _doorOpenSprite;

  // ドアのオーディオ
  late AudioSource _doorOpenAudioSource;
  late AudioSource _doorCloseAudioSource;
  SoundHandle? _currentDoorSoundHandle;

  final Station station;
  TrainState currentState = TrainState.idle;
  double _velocity = 0.0;
  final double _maxSpeed = 1000.0;
  final double _acceleration = 50.0;
  final double _deceleration = 100.0;
  late Vector2 _targetPosition;
  bool _isMovingRight = true;
  bool _isPlayerNearDoor = false;
  DoorHitbox? _doorHitbox;

  Train({required super.position, required this.station});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _doorOpenAudioSource = await game.audioManager.loadAndCacheSound(
      'assets/audio/buildings/DoorOpen01.ogg',
    );
    _doorCloseAudioSource = await game.audioManager.loadAndCacheSound(
      'assets/audio/buildings/DoorClose02.ogg',
    );

    // --- スプライトの読み込み ---

    // 乗り物本体のスプライト
    final vehicleBodySprite = await Sprite.load(
      'CITY_MEGA.png',
      srcPosition: Vector2(1800, 1776),
      srcSize: Vector2(118, 64),
    );

    // 開いたドアのスプライト
    _doorOpenSprite = await Sprite.load(
      'CITY_MEGA.png',
      srcPosition: Vector2(1800, 1726),
      srcSize: Vector2(24, 29),
    );

    // 閉じたドアのスプライト
    _doorClosedSprite = await Sprite.load(
      'CITY_MEGA.png',
      srcPosition: Vector2(1847, 1801),
      srcSize: Vector2(24, 29),
    );

    // --- コンポーネントの作成と追加 ---

    // 乗り物の本体
    _vehicleSprite = SpriteComponent(
      sprite: vehicleBodySprite,
      size: vehicleBodySprite.srcSize * 2,
    );
    add(_vehicleSprite);

    // ドア（乗り物の本体からの相対位置に配置）
    _doorSprite = SpriteComponent(
      sprite: _doorClosedSprite,
      position: Vector2(47 * 2, 25 * 2),
      size: Vector2(24 * 2, 29 * 2),
    );
    add(_doorSprite);

    // ドア周辺の当たり判定
    _doorHitbox = DoorHitbox(
      position: _doorSprite.position,
      size: _doorSprite.size,
      onPlayerEnter: () {
        _isPlayerNearDoor = true;
        _updateInteractAction();
      },
      onPlayerLeave: () {
        _isPlayerNearDoor = false;
        _updateInteractAction();
      },
    );
    add(_doorHitbox!);

    // このコンポーネント全体のサイズを設定
    size = _vehicleSprite.size;

    // 車両本体の当たり判定を追加（プレイヤーがすり抜けるが衝突は検知する）
    add(
      RectangleHitbox(
        size: _vehicleSprite.size,
        position: Vector2.zero(), // 車両本体の左上を基準
        collisionType: CollisionType.passive,
        isSolid: false, // プレイヤーがすり抜けられるように非ソリッドに設定
      ),
    );

    _targetPosition = Vector2(
      station.position.x + station.size.x / 2 - size.x / 2,
      position.y,
    );

    startJourney();
  }

  void startJourney() {
    position.x = game.size.x + size.x * 2;
    _isMovingRight = false;
    currentState = TrainState.movingToStation;
    _velocity = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    switch (currentState) {
      case TrainState.movingToStation:
        final direction = _isMovingRight ? 1 : -1;
        _velocity = min(_velocity + _acceleration * dt, _maxSpeed);
        position.x += direction * _velocity * dt;

        final distanceToTarget = (_targetPosition.x - position.x).abs();
        final stoppingDistance = (_velocity * _velocity) / (2 * _deceleration);

        if (distanceToTarget <= stoppingDistance) {
          currentState = TrainState.stopping;
        }
        break;

      case TrainState.stopping:
        final direction = _isMovingRight ? 1 : -1;
        _velocity = max(0.0, _velocity - _deceleration * dt);
        position.x += direction * _velocity * dt;

        if (_velocity == 0.0) {
          position.x = _targetPosition.x;
          currentState = TrainState.waitingAtStation;
          add(
            TimerComponent(period: 1.0, removeOnFinish: true, onTick: openDoor),
          );
        }
        break;

      case TrainState.leavingStation:
        final direction = _isMovingRight ? 1 : -1;
        _velocity = min(_velocity + _acceleration * dt, _maxSpeed);
        position.x += direction * _velocity * dt;

        // 指定座標まで到達したら自身を削除
        if (!_isMovingRight && position.x + game.size.x < -MyGame.worldWidth) {
          removeFromParent();
        }
        break;

      case TrainState.waitingAtStation:
      case TrainState.idle:
        break;
    }
  }

  void openDoor() {
    if (!isMounted || _isDoorOpen) return;
    _isDoorOpen = true;
    _doorSprite.sprite = _doorOpenSprite;
    if (_doorHitbox != null) {
      _doorHitbox!.collisionType = CollisionType.passive;
    }
    playDoorSound(_doorOpenAudioSource);
    _updateInteractAction();
    add(
      TimerComponent(
        period: 5.0,
        removeOnFinish: true,
        onTick: () {
          if (isMounted) closeDoor();
        },
      ),
    );
  }

  void closeDoor() {
    if (!isMounted || !_isDoorOpen) return;
    _isDoorOpen = false;
    _doorSprite.sprite = _doorClosedSprite;
    if (_doorHitbox != null) {
      _doorHitbox!.collisionType = CollisionType.inactive;
    }
    playDoorSound(_doorCloseAudioSource);
    _updateInteractAction();
    add(
      TimerComponent(
        period: 1.0,
        removeOnFinish: true,
        onTick: () {
          if (isMounted) leaveStation();
        },
      ),
    );
  }

  void leaveStation() {
    currentState = TrainState.leavingStation;
    _isMovingRight = false;
  }

  void _updateInteractAction() {
    final canInteract =
        currentState == TrainState.waitingAtStation &&
        _isDoorOpen &&
        _isPlayerNearDoor;

    if (canInteract) {
      GameUI.setInteractAction(() {
        game.gameClear();
        GameUI.setInteractAction(null, null);
      }, Icons.directions_transit);
    } else {
      GameUI.setInteractAction(null, null);
    }
  }

  /* @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      // プレイヤーが触れた時のインタラクションは自動走行とは別に定義可能
      // 今回の要件では自動でドアが開閉するため、ここでは何もしない
      debugPrint('Train onCollisionStart with Player');
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is Player) {
      debugPrint('Train onCollisionEnd with Player');
    }
  } */

  void playDoorSound(AudioSource audioSource) async {
    if (_currentDoorSoundHandle != null &&
        SoLoud.instance.getIsValidVoiceHandle(_currentDoorSoundHandle!)) {
      SoLoud.instance.stop(_currentDoorSoundHandle!);
    }

    final double playbackRate = 0.8 + Random().nextDouble() * 0.2;
    try {
      final SoundHandle handle = await SoLoud.instance.play(
        audioSource,
        volume: 1.0,
      );
      SoLoud.instance.setRelativePlaySpeed(handle, playbackRate);
      _currentDoorSoundHandle = handle;
    } catch (e) {
      debugPrint("Error playing door sound in Train: $e");
    }
  }
}
