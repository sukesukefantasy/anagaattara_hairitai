import 'package:flame/components.dart';
import 'building.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flame/collisions.dart';

class Station extends Building {
  late SpriteComponent _buildingSprite;
  bool _isPlayerNear = false;
  late PolygonHitbox platformHitbox;

  // 駅のオーディオ
  /* late AudioSource _stationAudioSource;
  late AudioSource _trainComingAudioSource;
  SoundHandle? _currentStationSoundHandle; */

  Station({required super.position}) : super(type: 'station');

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    /* _stationAudioSource = await game.audioManager.loadAndCacheSound(
      'assets/audio/buildings/Station01.ogg',
    );
    _trainComingAudioSource = await game.audioManager.loadAndCacheSound(
      'assets/audio/buildings/TrainComing01.ogg',
    ); */

    // --- スプライトの読み込み ---
    // 建物本体のスプライト
    final buildingBodySprite = await Sprite.load(
      'CITY_MEGA.png',
      srcPosition: Vector2(1528, 1779),
      srcSize: Vector2(271, 61),
    );

    // --- コンポーネントの作成と追加 ---

    // 建物の本体
    _buildingSprite = SpriteComponent(
      sprite: buildingBodySprite,
      size: buildingBodySprite.srcSize * 2,
    );
    add(_buildingSprite);

    // 駅の上部にある当たり判定（床として機能）
    platformHitbox = PolygonHitbox(
      [
        Vector2(6 * 2, 53 * 2), // 左上
        Vector2(_buildingSprite.size.x - (6 * 2), 53 * 2), // 右上
        Vector2(_buildingSprite.size.x, _buildingSprite.size.y), // 右下
        Vector2(0, _buildingSprite.size.y), // 左下
      ],
      collisionType: CollisionType.active,
      isSolid: true,
    );
    add(platformHitbox);

    // インタラクション用の当たり判定
    /* add(DoorHitbox(
      position: Vector2(0, 0), // 駅全体を覆う
      size: size,
      onPlayerEnter: () {
        _isPlayerNear = true;
        _updateInteractAction();
      },
      onPlayerLeave: () {
        _isPlayerNear = false;
        _updateInteractAction();
      },
    )); */

    // このコンポーネント全体のサイズを設定
    size = _buildingSprite.size;
  }

  /* void _updateInteractAction() {
    if (_isPlayerNear) {
      GameUI.setInteractAction(() {
        debugPrint("駅にインタラクトしました！");
        // TODO: 駅のメニュー表示などの処理
        GameUI.setInteractAction(null, null);
      }, Icons.business);
    } else {
      GameUI.setInteractAction(null, null);
    }
  } */
} 