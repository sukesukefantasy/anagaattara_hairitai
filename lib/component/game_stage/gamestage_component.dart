import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../main.dart'; // MyGameをインポート
import 'building/building_data.dart'; // BackgroundDataをインポート

class GameStageComponent extends RectangleComponent
    with HasGameReference<MyGame> {
  final BackgroundData data;
  late final Sprite _backgroundSprite;
  final bool isScrollForward;
  final bool loop;

  // スプライトシートにブレンドオーバーレイを描画
  final overlayPaint =
      Paint()
        ..color = const Color.fromARGB(255, 36, 36, 36).withAlpha(150)
        ..blendMode = BlendMode.srcOver;

  GameStageComponent({
    required this.data,
    this.isScrollForward = false,
    this.loop = false,
  })
    : super(
        size: Vector2(
          data.baseSize * (data.srcSize.x / data.srcSize.y),
          data.baseSize,
        ),
      );

  double get parallaxEffect => data.parallaxEffect;

  @override
  Future<void> onLoad() async {
    _backgroundSprite = await Sprite.load(
      data.imagePath,
      srcPosition: data.srcPosition,
      srcSize: data.srcSize,
    );
  }

  // 位置を更新するメソッド
  void resetPositions(Vector2 gameSize) {
    // 背景は常に画面の下部に位置するようにする
    position.y = (gameSize.y - size.y) + (data.groundOffset ?? 0);
  }

  @override
  void render(Canvas canvas) {
    // 通常の背景スプライト描画 (地上・地下共通)
    // コンポーネントのサイズ(size.x)を基準に繰り返し描画
    if (loop) {
      for (int i = 0; i < (size.x / MyGame.worldWidth).ceil() + 1; i++) {
        _backgroundSprite.render(
          canvas,
          position: Vector2(isScrollForward ? i * size.x - 1 : i * -size.x + 1, 0),
          size: size, // コンポーネント自身のサイズで描画
        );
      }
    } else {
      // loopがfalseの場合、一度だけ描画
      _backgroundSprite.render(
          canvas,
          position: isScrollForward ? Vector2.zero() : Vector2(-size.x, 0), // コンポーネント自身のローカル(0,0)から描画
          size: size, // コンポーネント自身のサイズで描画
        );
    }

    // 画面全体を暗くするオーバーレイを描画
    // game.player が null でないことを確認
    if (game.player != null && game.player!.inUnderGround && priority == 200) {
      final worldOriginInLocal = Vector2.zero() - absoluteTopLeftPosition;
      canvas.drawRect(
        Rect.fromLTWH(
          worldOriginInLocal.x -
              MyGame.worldWidth -
              game.size.x, // ワールド(0,0)のローカルX座標
          worldOriginInLocal.y, // ワールド(0,0)のローカルY座標
          worldOriginInLocal.x + (MyGame.worldWidth * 2),
          game.size.y,
        ),
        overlayPaint,
      );
    }
  }
} 