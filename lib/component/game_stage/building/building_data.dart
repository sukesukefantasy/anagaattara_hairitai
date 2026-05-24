// シーン名と背景データを照合し、マップするファイル

import 'package:flame/components.dart';

import '../../../game/world_scale.dart';
import '../lighting/lighting_participation.dart';

class BackgroundData {
  final String imagePath;
  final double parallaxEffect;
  final Vector2 srcPosition;
  final Vector2 srcSize;
  final double? groundOffset;

  /// プレイフィールドからの奥行き（m）。奥=正、手前=負。
  final double depthMeters;

  /// 時間帯暗転・ローカルライトへの参加度
  final LightingParticipation lighting;

  /// [WorldScale.renderPriorityForDepth] の手動上書き
  final int? renderPriorityOverride;

  /// 描画・配置は [srcSize] をそのままワールド単位（px）として使う。
  const BackgroundData({
    required this.imagePath,
    required this.parallaxEffect,
    required this.srcPosition,
    required this.srcSize,
    this.groundOffset,
    this.depthMeters = WorldScale.playfieldDepthMeters,
    this.lighting = LightingParticipation.none,
    this.renderPriorityOverride,
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
      imagePath: 'outdoor_1.png',
      parallaxEffect: -0.9,
      depthMeters: WorldScale.farMountainDepthMeters,
      lighting: LightingParticipation.none,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
  ],
  'outdoor_1': [
    BackgroundData(
      imagePath: 'outdoor_1.png',
      parallaxEffect: -0.9,
      depthMeters: WorldScale.farMountainDepthMeters,
      lighting: LightingParticipation.none,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0.5,
      depthMeters: WorldScale.nearForegroundDepthMeters,
      lighting: LightingParticipation.none,
      srcPosition: Vector2(64, 1905),
      srcSize: Vector2(1599, 110),
      groundOffset: 40.0,
    ),
  ],
  'outdoor_2': [
    BackgroundData(
      imagePath: 'outdoor_2.png',
      parallaxEffect: -0.2,
      depthMeters: 100,
      lighting: LightingParticipation.none,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
  ],
  'outdoor_3': [
    BackgroundData(
      imagePath: 'outdoor_3.png',
      parallaxEffect: -0.2,
      depthMeters: 100,
      lighting: LightingParticipation.none,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
  ],
  'outdoor_4': [
    BackgroundData(
      imagePath: 'outdoor_4.png',
      parallaxEffect: -0.2,
      depthMeters: 100,
      lighting: LightingParticipation.none,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
  ],
  'outdoor_philosophy': [
    BackgroundData(
      imagePath: 'outdoor_philosophy.png',
      parallaxEffect: -0.2,
      depthMeters: 100,
      lighting: LightingParticipation.none,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
  ],
  'outdoor_despair': [
    BackgroundData(
      imagePath: 'outdoor_despair.png',
      parallaxEffect: -0.2,
      depthMeters: 100,
      lighting: LightingParticipation.none,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
  ],
  'outdoor_true': [
    BackgroundData(
      imagePath: 'outdoor_true.png',
      parallaxEffect: -0.2,
      depthMeters: 100,
      lighting: LightingParticipation.none,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
  ],
  'shop_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0,
      depthMeters: WorldScale.playfieldDepthMeters,
      lighting: LightingParticipation.none,
      renderPriorityOverride: 100,
      srcPosition: Vector2(1504, 624),
      srcSize: Vector2(368, 66),
      groundOffset: 0,
    ),
  ],
  'health_center_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0,
      depthMeters: WorldScale.playfieldDepthMeters,
      lighting: LightingParticipation.none,
      renderPriorityOverride: 100,
      srcPosition: Vector2(64, 720),
      srcSize: Vector2(224, 66),
      groundOffset: 0,
    ),
  ],
  'apartment_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0,
      depthMeters: WorldScale.playfieldDepthMeters,
      lighting: LightingParticipation.none,
      renderPriorityOverride: 100,
      srcPosition: Vector2(336, 719),
      srcSize: Vector2(352, 69),
      groundOffset: 0,
    ),
  ],
  'cafe_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0,
      depthMeters: WorldScale.playfieldDepthMeters,
      lighting: LightingParticipation.none,
      renderPriorityOverride: 100,
      srcPosition: Vector2(992, 720),
      srcSize: Vector2(448, 69),
      groundOffset: 0,
    ),
  ],
  'sushi_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0,
      depthMeters: WorldScale.playfieldDepthMeters,
      lighting: LightingParticipation.none,
      renderPriorityOverride: 100,
      srcPosition: Vector2(736, 736),
      srcSize: Vector2(208, 69),
      groundOffset: 0,
    ),
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0,
      depthMeters: WorldScale.playfieldDepthMeters,
      lighting: LightingParticipation.none,
      renderPriorityOverride: 100,
      srcPosition: Vector2(736, 656),
      srcSize: Vector2(208, 69),
      groundOffset: 0,
    ),
  ],
  'burger_store_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0,
      depthMeters: WorldScale.playfieldDepthMeters,
      lighting: LightingParticipation.none,
      renderPriorityOverride: 100,
      srcPosition: Vector2(1504, 816),
      srcSize: Vector2(320, 66),
      groundOffset: 0,
    ),
  ],
};
