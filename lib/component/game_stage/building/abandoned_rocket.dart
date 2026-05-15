import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../main.dart';

/// 放棄されたロケット。景観オブジェクト。
/// カーゴの射出はプレイヤーに追従する [PlayerCargoTerminal] から行う。
class AbandonedRocket extends SpriteComponent with HasGameReference<MyGame> {
  AbandonedRocket({required super.position});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // TODO: 画像挿入 (ロケット本体)
    try {
      sprite = await Sprite.load(
        'rocket.png',
        srcPosition: Vector2(0, 0),
        srcSize: Vector2(64, 128),
      );
    } catch (e) {
      debugPrint('Error loading rocket.png: $e');
    }
    size = sprite!.srcSize;
    anchor = Anchor.bottomCenter;

    // TODO: 正式な画像が挿入されたら削除
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.blueGrey.withOpacity(0.5),
      priority: -1,
    ));
  }
}
