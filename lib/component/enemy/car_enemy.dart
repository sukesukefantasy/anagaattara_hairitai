import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // TextStyleとColorsのために追加
import '../../main.dart';
import '../player.dart';
import 'enemy_base.dart'; // EnemyBaseクラスをインポート
import '../../game_manager/audio_manager.dart'; // AudioManagerをインポート
import 'package:flutter_soloud/flutter_soloud.dart'; // SoundHandleのために追加
import 'package:flame/collisions.dart'; // Add this line

class CarEnemy extends EnemyBase {
  SoundHandle? _carSoundHandle; // 車の音のSoundHandle

  CarEnemy({
    required super.position,
    required super.size,
    required super.direction, // directionを受け取る
    super.priority = 60, // 建物、プレイヤー、歩行者より手前
  }) {
    anchor = Anchor.bottomCenter; // アンカーを底辺中央に設定
  }

  @override
  double get speed => 150.0 + random.nextDouble() * 100.0; // 150.0から250.0の間でランダムな速度

  @override
  double get attackStress => 10.0; // 車の敵の攻撃力（ストレス値）

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // スプライトシートからアニメーションを生成し、textureSizeを明示的に設定
    animation = SpriteAnimation.fromFrameData(
      await game.images.load('amburance.png'),
      SpriteAnimationData.sequenced(
        amount: 4, // 4つのフレーム
        stepTime: 0.1, // アニメーション速度
        textureSize: Vector2(63, 26), // 1フレームあたりのサイズを設定 (252 / 4 = 63)
        loop: true,
      ),
    );

    // ヒットボックスを追加
    add(
      RectangleHitbox(
        size: Vector2(size.x * 0.8, size.y * 0.5), // 車のサイズに合わせて調整、少し小さくする
        position: Vector2(size.x * 0.2, size.y * 0.25), // 中央に配置
        collisionType: CollisionType.active,
        isSolid: true,
      ),
    );

    // 初期ロード時に車の音を再生し、ハンドルを保持
    _carSoundHandle = await game.audioManager.playCarSound(absolutePosition);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _performMovement(dt);
  }

  void _performMovement(double dt) {
    // 水平移動
    position.x += speed * dt * direction;

    final playerDistance = game.player != null ? (position - game.player!.position).length : double.infinity;

    if (playerDistance < AudioManager.maxDistance) {
      // 音が再生中であれば音源の位置を更新
      if (_carSoundHandle != null && game.audioManager.soloud.getIsValidVoiceHandle(_carSoundHandle!)) {
        game.audioManager.soloud.set3dSourcePosition(
          _carSoundHandle!,
          absolutePosition.x,
          absolutePosition.y,
          0.0,
        );
      }
    }

    // 移動範囲の制限: directionに応じて判定を修正
    if (direction == -1.0) { // 左向きの場合
      if (position.x < -MyGame.worldWidth - size.x) {
        removeFromParent(); // 画面左端を超えたらインスタンスを廃棄
      }
    } else { // 右向きの場合
      if (position.x > game.camera.visibleWorldRect.right + size.x) {
        removeFromParent(); // 画面右端を超えたらインスタンスを廃棄
      }
    }
  }

  /* @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
    }
  } */

  @override
  void onRemove() {
    super.onRemove();
    // コンポーネントが削除されるときに音を停止
    stopCarSound(); // 明示的に音を停止
  }

  // 車の音を停止するための公開メソッド
  void stopCarSound() {
    if (_carSoundHandle != null && game.audioManager.soloud.getIsValidVoiceHandle(_carSoundHandle!)) {
      game.audioManager.soloud.stop(_carSoundHandle!); // 直接SoLoudを停止
      _carSoundHandle = null;
    }
  }
} 