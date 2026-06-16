// シーン名と背景データを照合し、マップするファイル

import 'package:flame/components.dart';

import '../../../game/pseudo3d_camera.dart';
import '../../../game/world_scale.dart';
import '../lighting/light_emitter_spec.dart';
import '../lighting/lighting_participation.dart';

/// 縦／横スプライトシートの周期アニメ（遠景など）。
class BackgroundSheetAnimation {
  final int columns;
  final int rows;
  final double stepTime;
  final double intervalSeconds;
  final int idleFrameIndex;
  final int playStartFrame;
  final int playEndFrame;

  const BackgroundSheetAnimation({
    required this.columns,
    required this.rows,
    required this.stepTime,
    required this.intervalSeconds,
    this.idleFrameIndex = 0,
    int? playStartFrame,
    int? playEndFrame,
  })  : playStartFrame = playStartFrame ?? 1,
        playEndFrame = playEndFrame ?? (rows - 1);

  int get frameCount => columns * rows;

  /// burst 再生時間（playStartFrame..playEndFrame、各 [stepTime]）。
  double get burstDurationSeconds =>
      (playEndFrame - playStartFrame + 1) * stepTime;
}

/// シート burst アニメに同期する流れ星ライト（Ground 走査 + 遠景フラッシュ）。
class BackgroundSheetLightSync {
  /// 走査開始ワールド X（右端）。
  final double fromWorldX;

  /// 走査終了ワールド X（左端）。
  final double toWorldX;

  /// Ground 上の Y（0=上端、1=下端）。
  final double groundYNormalized;

  /// 遠景スプライト上の空フラッシュ Y（0=上端、1=下端）。
  final double skyYNormalized;

  /// 遠景空フラッシュ半径（ローカル px）。
  final double skyFlashRadius;

  /// const で持てないため factory getter 経由で解決する。
  final LightEmitterSpec Function() emitterSpec;

  const BackgroundSheetLightSync({
    this.fromWorldX = WorldScale.stageRightX,
    this.toWorldX = WorldScale.stageLeftX,
    this.groundYNormalized = 0.35,
    this.skyYNormalized = 0.22,
    this.skyFlashRadius = 220,
    this.emitterSpec = _defaultShootingStarSpec,
  });
}

LightEmitterSpec _defaultShootingStarSpec() => LightEmitterSpec.shootingStar;

class BackgroundData {
  final String imagePath;
  final Vector2 srcPosition;
  final Vector2 srcSize;
  final double? groundOffset;

  /// プレイフィールドからの奥行き（m）。奥=正、手前=負。
  ///
  /// 屋外のパララックス／奥行きズームは [Pseudo3DCamera] が参照する。
  /// [srcSize] は referenceZoom 時のピクセル基準（定義台帳、ロジックは持たない）。
  final double depthMeters;

  /// 時間帯暗転・ローカルライトへの参加度
  final LightingParticipation lighting;

  /// [WorldScale.renderPriorityForDepth] の手動上書き
  final int? renderPriorityOverride;

  /// 非 null のとき [srcSize] は1フレーム分のサイズとしてシートから切り出す。
  final BackgroundSheetAnimation? sheetAnimation;

  /// 非 null のとき burst 中に [BackgroundSheetLightSync] で流れ星ライトを同期する。
  final BackgroundSheetLightSync? sheetLightSync;

  /// true のとき [srcSize.x] 単位でステージ横幅を水平タイルループする。
  final bool loopHorizontal;

  /// [loopHorizontal] 時、ステージ外側へ追加する余白スロット数（片側）。
  final int loopMarginSlots;

  /// 描画・配置は [srcSize] をそのままワールド単位（px）として使う。
  const BackgroundData({
    required this.imagePath,
    required this.srcPosition,
    required this.srcSize,
    this.groundOffset,
    this.depthMeters = WorldScale.playfieldDepthMeters,
    this.lighting = LightingParticipation.none,
    this.renderPriorityOverride,
    this.sheetAnimation,
    this.sheetLightSync,
    this.loopHorizontal = false,
    this.loopMarginSlots = 1,
  });

  int resolveRenderPriority() =>
      WorldScale.renderPriorityForDepth(
        depthMeters,
        override: renderPriorityOverride,
      );
}

final Map<String, List<BackgroundData>> backgroundDataMap = {
  'outdoor_0': [
    BackgroundData(
      imagePath: 'outdoor_0.png',
      depthMeters: 500,
      lighting: LightingParticipation.none,
      loopHorizontal: true,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1983, 650),
      sheetAnimation: BackgroundSheetAnimation(
        columns: 1,
        rows: 9,
        stepTime: 1 / 10,
        intervalSeconds: 15,
      ),
      sheetLightSync: const BackgroundSheetLightSync(),
    ),
  ],
  'outdoor_1': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      depthMeters: WorldScale.nearForegroundDepthMeters,
      lighting: LightingParticipation.none,
      srcPosition: Vector2(64, 1905),
      srcSize: Vector2(1599, 110),
    ),
    BackgroundData(
      imagePath: 'outdoor_1.png',
      depthMeters: 500,
      lighting: LightingParticipation.none,
      loopHorizontal: true,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
    BackgroundData(
      imagePath: 'superdistantview_cumulonimbus.png',
      depthMeters: 800,
      lighting: LightingParticipation.none,
      loopHorizontal: true,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1776, 592),
    ),
  ],
  'outdoor_2': [
    BackgroundData(
      imagePath: 'outdoor_2.png',
      depthMeters: 100,
      lighting: LightingParticipation.none,
      loopHorizontal: true,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
    BackgroundData(
      imagePath: 'distantview_buildings.png',
      depthMeters: 500,
      lighting: LightingParticipation.none,
      loopHorizontal: true,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(2048, 290),
    ),
    BackgroundData(
      imagePath: 'superdistantview_cumulonimbus.png',
      depthMeters: 800,
      lighting: LightingParticipation.none,
      loopHorizontal: true,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1776, 592),
    ),
  ],
  'outdoor_3': [
    BackgroundData(
      imagePath: 'outdoor_3.png',
      depthMeters: 100,
      lighting: LightingParticipation.none,
      loopHorizontal: true,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
    BackgroundData(
      imagePath: 'superdistantview_cumulonimbus.png',
      depthMeters: 800,
      lighting: LightingParticipation.none,
      loopHorizontal: true,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1776, 592),
    ),
  ],
  'outdoor_4': [
    BackgroundData(
      imagePath: 'outdoor_4.png',
      depthMeters: 100,
      lighting: LightingParticipation.none,
      loopHorizontal: true,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
    BackgroundData(
      imagePath: 'superdistantview_cumulonimbus.png',
      depthMeters: 800,
      lighting: LightingParticipation.none,
      loopHorizontal: true,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1776, 592),
    ),
  ],
  'outdoor_philosophy': [
    BackgroundData(
      imagePath: 'outdoor_philosophy.png',
      depthMeters: 100,
      lighting: LightingParticipation.none,
      loopHorizontal: true,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
  ],
  'outdoor_despair': [
    BackgroundData(
      imagePath: 'outdoor_despair.png',
      depthMeters: 100,
      lighting: LightingParticipation.none,
      loopHorizontal: true,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
  ],
  'outdoor_true': [
    BackgroundData(
      imagePath: 'outdoor_true.png',
      depthMeters: 100,
      lighting: LightingParticipation.none,
      loopHorizontal: true,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
    BackgroundData(
      imagePath: 'superdistantview_cumulonimbus.png',
      depthMeters: 800,
      lighting: LightingParticipation.none,
      loopHorizontal: true,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1776, 592),
    ),
  ],
  'shop_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      depthMeters: WorldScale.playfieldDepthMeters,
      lighting: LightingParticipation.none,
      srcPosition: Vector2(1504, 624),
      srcSize: Vector2(368, 66),
      groundOffset: 0,
    ),
  ],
  'health_center_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      depthMeters: WorldScale.playfieldDepthMeters,
      lighting: LightingParticipation.none,
      srcPosition: Vector2(64, 720),
      srcSize: Vector2(224, 66),
      groundOffset: 0,
    ),
  ],
  'apartment_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      depthMeters: WorldScale.playfieldDepthMeters,
      lighting: LightingParticipation.none,
      srcPosition: Vector2(336, 719),
      srcSize: Vector2(352, 69),
      groundOffset: 0,
    ),
  ],
  'cafe_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      depthMeters: WorldScale.playfieldDepthMeters,
      lighting: LightingParticipation.none,
      srcPosition: Vector2(992, 720),
      srcSize: Vector2(448, 69),
      groundOffset: 0,
    ),
  ],
  'sushi_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      depthMeters: WorldScale.playfieldDepthMeters,
      lighting: LightingParticipation.none,
      srcPosition: Vector2(736, 736),
      srcSize: Vector2(208, 69),
      groundOffset: 0,
    ),
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      depthMeters: WorldScale.playfieldDepthMeters,
      lighting: LightingParticipation.none,
      srcPosition: Vector2(736, 656),
      srcSize: Vector2(208, 69),
      groundOffset: 0,
    ),
  ],
  'burger_store_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      depthMeters: WorldScale.playfieldDepthMeters,
      lighting: LightingParticipation.none,
      srcPosition: Vector2(1504, 816),
      srcSize: Vector2(320, 66),
      groundOffset: 0,
    ),
  ],
};
