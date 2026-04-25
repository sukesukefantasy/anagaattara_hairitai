import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../main.dart';
import '../../common/hitboxes/interact_hitbox.dart';

enum HideableType {
  trashCan,
  locker,
  box,
}

class HideableObject extends SpriteComponent with HasGameReference<MyGame> {
  final HideableType type;
  
  HideableObject({
    required this.type,
    required super.position,
    required super.size,
    required Sprite sprite,
  }) : super(sprite: sprite) {
    anchor = Anchor.bottomCenter;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // インタラクト用のヒットボックスを追加
    add(InteractHitbox(
      position: Vector2(0, 0),
      size: size,
      onInteract: _onHide,
      icon: Icons.meeting_room, // 隠れるアイコン
    ));
  }

  void _onHide() {
    if (game.player.isHiding) {
      game.player.exitHide();
    } else {
      game.player.enterHide(this);
    }
  }
}
