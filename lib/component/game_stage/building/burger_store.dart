import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../UI/game_ui.dart';
import '../../player.dart';
import '../../common/hitboxes/door_hitbox.dart';
import 'building.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'dart:math';
import '../../../main.dart';
import '../../../scene/burger_store_interior_scene.dart'; // BurgerStoreInteriorSceneをインポート
import '../../../scene/abstract_outdoor_scene.dart'; // AbstractOutdoorSceneをインポート

class BurgerStore extends Building {
  late SpriteComponent _buildingSprite;
  late SpriteComponent _doorSprite;

  bool _isDoorOpen = false;
  bool _isPlayerNearDoor = false;

  late Sprite _doorClosedSprite;
  late Sprite _doorOpenSprite;

  late AudioSource _doorOpenAudioSource;
  late AudioSource _doorCloseAudioSource;
  SoundHandle? _currentDoorSoundHandle;

  BurgerStore({
    required super.position,
  }) : super(type: 'burger_store'); // `type` を追加

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _doorOpenAudioSource = await game.audioManager.loadAndCacheSound(
      'assets/audio/buildings/DoorOpen01.ogg',
    );
    _doorCloseAudioSource = await game.audioManager.loadAndCacheSound(
      'assets/audio/buildings/DoorClose02.ogg',
    );

    final buildingBodySprite = await Sprite.load(
      'CITY_MEGA.png',
      srcPosition: Vector2(1250, 1760),
      srcSize: Vector2(106, 80),
    );

    _doorClosedSprite = await Sprite.load(
      'CITY_MEGA.png',
      srcPosition: Vector2(1263, 1810),
      srcSize: Vector2(18, 30),
    );

    _doorOpenSprite = await Sprite.load(
      'CITY_MEGA.png',
      srcPosition: Vector2(1263, 1554),
      srcSize: Vector2(18, 30),
    );

    _buildingSprite = SpriteComponent(
      sprite: buildingBodySprite,
      size: buildingBodySprite.srcSize * 2,
    );
    add(_buildingSprite);

    _doorSprite = SpriteComponent(
      sprite: _doorClosedSprite,
      position: Vector2((1263 - 1250) * 2, (1810 - 1760) * 2), // 相対位置を計算
      size: Vector2(18 * 2, 30 * 2),
    );
    add(_doorSprite);

    add(DoorHitbox(
      position: _doorSprite.position,
      size: _doorSprite.size,
      onPlayerEnter: () {
        _isPlayerNearDoor = true;
        openOrCloseDoor(true);
        _updateInteractAction();
      },
      onPlayerLeave: () {
        _isPlayerNearDoor = false;
        openOrCloseDoor(false);
        _updateInteractAction();
      },
    ));

    size = _buildingSprite.size;
  }

  void _updateInteractAction() {
    if (_isPlayerNearDoor) {
      GameUI.setInteractAction(() {
        debugPrint('ハンバーガー店とインタラクトしました。');
        // 建物から出る際のプレイヤーの目標位置を設定
        String? currentOutdoorSceneId;
        if (game.sceneManager.currentScene is AbstractOutdoorScene) {
          currentOutdoorSceneId = game.gameRuntimeState.currentOutdoorSceneId;
        }
        game.sceneManager.enterBurgerStoreScene(this, initialPlayerPosition: null, outdoorSceneId: currentOutdoorSceneId); // outdoorSceneIdを渡す
      }, Icons.restaurant);
    } else {
      GameUI.setInteractAction(null, null);
    }
  }

  void openOrCloseDoor(bool isPlayerColliding) {
    if (_isDoorOpen == isPlayerColliding) return;
    _isDoorOpen = isPlayerColliding;

    if (_isDoorOpen) {
      _doorSprite.sprite = _doorOpenSprite;
      playDoorSound(_doorOpenAudioSource);
    } else {
      _doorSprite.sprite = _doorClosedSprite;
      playDoorSound(_doorCloseAudioSource);
    }
  }

  void playDoorSound(AudioSource audioSource) async {
    // If there's an existing sound, stop it.
    final SoundHandle? oldHandle = _currentDoorSoundHandle;
    _currentDoorSoundHandle = null; // Immediately clear to prevent race conditions on this handle

    if (oldHandle != null && game.audioManager.soloud.getIsValidVoiceHandle(oldHandle)) {
      game.audioManager.stopSound(oldHandle);
    }

    final double playbackRate = 0.8 + Random().nextDouble() * 0.2;
    try {
      final SoundHandle newHandle = await game.audioManager.soloud.play(
        audioSource,
        volume: 1.0,
      );
      game.audioManager.soloud.setRelativePlaySpeed(newHandle, playbackRate);
      _currentDoorSoundHandle = newHandle; // Assign new handle only after successful play
    } catch (e) {
      debugPrint("Error playing door sound in Player: $e");
    }
  }
} 