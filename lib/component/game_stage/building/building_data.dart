// シーン名と背景データを照合し、マップするファイル

import 'package:flame/components.dart';

class BackgroundData {
  final String imagePath;
  final double parallaxEffect;
  final int priority;
  final Vector2 srcPosition;
  final Vector2 srcSize;
  final double? groundOffset;

  /// 描画・配置は [srcSize] をそのままワールド単位（px）として使う。
  const BackgroundData({
    required this.imagePath,
    required this.parallaxEffect,
    required this.priority,
    required this.srcPosition,
    required this.srcSize,
    this.groundOffset,
  });
}

final Map<String, List<BackgroundData>> backgroundDataMap = {
  'outdoor_0': [
    // 遠景（母星の山々など）
    BackgroundData(
      imagePath: 'outdoor_1.png',
      parallaxEffect: -0.9,
      priority: 2,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
    // 宇宙の遠景（星空）- 最初は透明にしておく
    BackgroundData(
      imagePath: 'outdoor_true.png', // 星空っぽい画像として流用
      parallaxEffect: -0.95,
      priority: 1,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
  ],
  'outdoor_1': [
    // 遠景（ビル群など）
    BackgroundData(
      imagePath: 'outdoor_1.png',
      parallaxEffect: -0.9,
      priority: 2, // 空より手前に配置
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
    // 近景
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0.5,
      priority: 100,
      srcPosition: Vector2(64, 1905),
      srcSize: Vector2(1599, 110),
      groundOffset: 40.0, // Ground.groundHeight
    ),
  ],
  'outdoor_2': [
    BackgroundData(
      imagePath: 'outdoor_2.png',
      parallaxEffect: -0.2,
      priority: 2, // 空より手前に配置
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
  ],
  'outdoor_3': [
    BackgroundData(
      imagePath: 'outdoor_3.png',
      parallaxEffect: -0.2,
      priority: 2,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
  ],
  'outdoor_4': [
    BackgroundData(
      imagePath: 'outdoor_4.png',
      parallaxEffect: -0.2,
      priority: 2,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
  ],
  'outdoor_philosophy': [
    BackgroundData(
      imagePath: 'outdoor_philosophy.png',
      parallaxEffect: -0.2,
      priority: 2,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
  ],
  'outdoor_despair': [
    BackgroundData(
      imagePath: 'outdoor_despair.png',
      parallaxEffect: -0.2,
      priority: 2,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
  ],
  'outdoor_true': [
    BackgroundData(
      imagePath: 'outdoor_true.png',
      parallaxEffect: -0.2,
      priority: 2,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(1599, 299),
    ),
  ],
  'shop_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0,
      priority: 100,
      srcPosition: Vector2(1504, 624),
      srcSize: Vector2(368, 66),
      groundOffset: 0,
    ),
  ],
  'health_center_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0,
      priority: 100,
      srcPosition: Vector2(64, 720),
      srcSize: Vector2(224, 66),
      groundOffset: 0,
    ),
  ],
  'apartment_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0,
      priority: 100,
      srcPosition: Vector2(336, 719),
      srcSize: Vector2(352, 69),
      groundOffset: 0,
    ),
  ],
  'cafe_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0,
      priority: 100,
      srcPosition: Vector2(992, 720),
      srcSize: Vector2(448, 69),
      groundOffset: 0,
    ),
  ],
  'sushi_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0,
      priority: 100,
      srcPosition: Vector2(736, 736),
      srcSize: Vector2(208, 69),
      groundOffset: 0,
    ),
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0,
      priority: 100,
      srcPosition: Vector2(736, 656),
      srcSize: Vector2(208, 69),
      groundOffset: 0,
    ),
  ],
  'burger_store_interior': [
    BackgroundData(
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0,
      priority: 100,
      srcPosition: Vector2(1504, 816),
      srcSize: Vector2(320, 66),
      groundOffset: 0,
    ),
  ],
};
