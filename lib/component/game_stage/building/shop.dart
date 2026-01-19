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
import '../../../UI/window_manager.dart';
import '../../item/item_bag.dart';
import '../../../UI/windows/shop_window.dart';
import '../../../scene/shop_interior_scene.dart'; // ShopInteriorSceneをインポート
import '../../../scene/abstract_outdoor_scene.dart'; // AbstractOutdoorSceneをインポート

class Shop extends Building {
  late SpriteComponent _buildingSprite;
  late SpriteComponent _doorSprite;

  bool _isDoorOpen = false;
  bool _isPlayerNearDoor = false;

  // ドアの状態に対応するスプライト
  late Sprite _doorClosedSprite;
  late Sprite _doorOpenSprite;

  // ドアのオーディオ
  late AudioSource _doorOpenAudioSource;
  late AudioSource _doorCloseAudioSource;
  SoundHandle? _currentDoorSoundHandle;

  final WindowManager windowManager;
  final ItemBag itemBag;

  Shop({
    required super.position,
    required this.windowManager,
    required this.itemBag,
  }) : super(type: 'shop'); // `type` を追加

  @override
  Future<void> onLoad() async {
    // オーディオの読み込み
    _doorOpenAudioSource =
        await game.audioManager.loadAndCacheSound('assets/audio/buildings/DoorOpen01.ogg');
    _doorCloseAudioSource =
        await game.audioManager.loadAndCacheSound('assets/audio/buildings/DoorClose02.ogg');

    // --- スプライトの読み込み ---

    // 建物本体のスプライト
    final buildingBodySprite = await Sprite.load(
      'CITY_MEGA.png',
      srcPosition: Vector2(1048, 1744),
      srcSize: Vector2(181, 95),
    );

    // 閉じたドアのスプライト
    _doorClosedSprite = await Sprite.load(
      'CITY_MEGA.png',
      srcPosition: Vector2(1167, 1810),
      srcSize: Vector2(17, 29),
    );

    // 開いたドアのスプライト
    _doorOpenSprite = await Sprite.load(
      'CITY_MEGA.png',
      srcPosition: Vector2(1167, 1554),
      srcSize: Vector2(17, 29),
    );

    // --- コンポーネントの作成と追加 ---

    // 建物の本体
    _buildingSprite = SpriteComponent(
      sprite: buildingBodySprite,
      size: buildingBodySprite.srcSize * 2,
    );
    add(_buildingSprite);

    // ドア（建物の本体からの相対位置に配置）
    _doorSprite = SpriteComponent(
      sprite: _doorClosedSprite,
      position: Vector2(119 * 2, 66 * 2),
      size: Vector2(17 * 2, 29 * 2),
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

    // このコンポーネント全体のサイズを設定
    size = _buildingSprite.size;
  }

  void _updateInteractAction() {
    if (_isPlayerNearDoor) {
      GameUI.setInteractAction(() {
        debugPrint('ショップとインタラクトしました。');
        // 建物から出る際のプレイヤーの目標位置を設定
        String? currentOutdoorSceneId;
        if (game.sceneManager.currentScene is AbstractOutdoorScene) {
          currentOutdoorSceneId = game.gameRuntimeState.currentOutdoorSceneId;
        }
        game.sceneManager.enterShopScene(this, initialPlayerPosition: null, outdoorSceneId: currentOutdoorSceneId); // outdoorSceneIdを渡す
      }, Icons.store);
    } else {
      GameUI.setInteractAction(null, null);
    }
  }

  // プレイヤーが近くにいる、などのイベントでこのメソッドを呼び出す
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
