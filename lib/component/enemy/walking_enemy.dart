import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import '../../main.dart';
import '../player.dart';
import 'enemy_base.dart'; // EnemyBaseをインポート
import '../game_stage/building/station.dart'; // Stationをインポート

class WalkingEnemy extends EnemyBase {
  double _walkCycleTime = 0.0;
  static const double _bounceHeight = 5.0; // 上下運動の高さ
  final double _walkCycleSpeed; // finalに変更
  late double _groundY; // 地面の高さ（ノックバックからの復帰用）
  bool _readyToPlaySound = true; // 新しいフラグ
  bool _isOnSolidPlatform = false; // 新しいフラグ
  double _footstepSoundCooldown = 0.0; // クールダウンタイマー
  static const double _footstepCooldownDuration = 0.2; // 0.2秒間のクールダウン

  WalkingEnemy({
    required super.position,
    required super.size,
    required super.direction, // directionを受け取る
    double walkCycleSpeed = 5.0, // パラメータ名からアンダースコアを削除
    super.priority = 45, // 優先度を45に設定してリンターエラーを解消
    super.mass = 1.0, // 質量を指定
  })  : _walkCycleSpeed = walkCycleSpeed {
    anchor = Anchor.bottomCenter; // アンカーを底辺中央に設定
  }

  @override
  double get speed => 50.0 + random.nextDouble() * 50.0; // 50.0から100.0の間でランダムな速度

  @override
  double get attackStress => 5.0; // ウォーキングエネミーの攻撃力（ストレス値）

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _groundY = position.y;

    final enemyImage = await game.images.load('enemy.png');

    final int randomRow = random.nextInt(8);
    final int randomCol = random.nextInt(8);

    // SpriteAnimationComponentのアニメーションプロパティに、取得した単一スプライトを設定
    // SpriteAnimationData.sequenced を使用し、amount を 1 に設定することで単一フレームを表示
    animation = SpriteAnimation.fromFrameData(
      enemyImage,
      SpriteAnimationData.sequenced(
        amount: 1, // 単一フレーム
        stepTime: 0.5, // アニメーション速度 (単一フレームなので影響は少ないが必須)
        textureSize: Vector2(12, 12), // 個々のスプライトのサイズ
        texturePosition: Vector2(1 + (randomCol * 12), 1 + (randomRow * 12)), // 切り出すスプライトの位置
      ),
    );

    // ヒットボックスを追加 (プレイヤーがすり抜けるが衝突は検知する)
    add(
      RectangleHitbox(
        size: Vector2(size.x * 0.3, size.y * 0.5), // サイズを小さくする
        position: Vector2(size.x * 0.35, size.y * 0.25), // 中央に配置
        collisionType: CollisionType.active, // activeに変更
        isSolid: true, // trueに変更
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _performMovement(dt);
  }

  void _performMovement(double dt) {
    _walkCycleTime += dt * _walkCycleSpeed;

    // 水平移動: directionを考慮
    position.x += speed * dt * direction;

    // 固体プラットフォームの上にいる場合は上下運動を停止
    if (!_isOnSolidPlatform) {
      // position.y を直接書き換えるのではなく、変化量だけを適用する
      final oldCycleY = sin(_walkCycleTime - dt * _walkCycleSpeed) * _bounceHeight;
      final newCycleY = sin(_walkCycleTime) * _bounceHeight;
      position.y -= (newCycleY - oldCycleY); // サイン波による上下移動を適用

      // 簡易的な重力: 本来の地面位置 (_groundY) より浮いている場合は下に引き戻す
      if (position.y < _groundY) {
        position.y += 150 * dt; // 秒間150ピクセルで落下
        if (position.y > _groundY) {
          position.y = _groundY;
        }
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

    // 足音再生のタイミング
    // sin(_walkCycleTime)が約1（最高点）に達したときに音を鳴らす
    // クールダウンがゼロの場合のみ再生
    if (sin(_walkCycleTime) > 0.99 && _readyToPlaySound && _footstepSoundCooldown <= 0) { 
      game.audioManager.playFootstepSound(absolutePosition);
      _readyToPlaySound = false; // 音を再生したので、次のサイクルまで再生準備をオフにする
      _footstepSoundCooldown = _footstepCooldownDuration; // クールダウンを開始
    }

    // sin(_walkCycleTime)が低い値（例: 0.5未満）に戻ったら、次のピークで再生できるように準備をリセット
    if (sin(_walkCycleTime) < 0.5) {
      _readyToPlaySound = true;
    }

    // クールダウンタイマーを更新
    if (_footstepSoundCooldown > 0) {
      _footstepSoundCooldown -= dt;
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      // debugPrint('WalkingEnemy collided with Player!');
    } else if (other is Station) {
      // Stationがソリッドなヒットボックスを持つことを確認
      if (other.platformHitbox.isSolid) {
        _isOnSolidPlatform = true;

        // 駅のプラットフォームのワールド座標での上端Y座標を計算
        // Stationのpositionは左上基準、platformHitboxのtop YはStation内の相対座標
        // platformHitboxの定義: Vector2(6 * 2, 53 * 2) が左上 (y=106)
        final stationPlatformTopY = other.position.y + (53 * 2);

        // 敵の足元が駅のプラットフォームのY座標より下にある場合、スナップする
        if (position.y > stationPlatformTopY) {
          position.y = stationPlatformTopY; // 敵の足元をStationのプラットフォームの最上部にスナップ
        }
      }
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is Station) {
      _isOnSolidPlatform = false;
    }
  }
}
