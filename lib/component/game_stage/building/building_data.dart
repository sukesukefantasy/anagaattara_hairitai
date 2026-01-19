// シーン名と背景データを照合し、マップするファイル

import 'package:flame/components.dart';

class BackgroundData {
  final double baseSize;
  final String imagePath;
  final double parallaxEffect;
  final int priority;
  final Vector2 srcPosition;
  final Vector2 srcSize;
  final double? groundOffset;

  const BackgroundData({
    required this.baseSize,
    required this.imagePath,
    required this.parallaxEffect,
    required this.priority,
    required this.srcPosition,
    required this.srcSize,
    this.groundOffset,
  });
}

final Map<String, List<BackgroundData>> backgroundDataMap = {
  'outdoor': [
    // 遠景（ビル群など）
    BackgroundData(
      baseSize: 800,
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: -0.9,
      priority: 2, // 空より手前に配置
      srcPosition: Vector2(64, 2400), // CITY_MEGA.pngのビル群部分の座標
      srcSize: Vector2(1599, 319),
    ),
    // 近景
    BackgroundData(
      baseSize: 300,
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
      baseSize: 450,
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: -0.2,
      priority: 2, // 空より手前に配置
      srcPosition: Vector2(64, 2068), // CITY_MEGA.pngの都会の部分の座標
      srcSize: Vector2(1600, 268),
    ),
  ],
  'shop_interior': [
    BackgroundData(
      baseSize: 120,
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
      baseSize: 120,
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
      baseSize: 120,
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
      baseSize: 120,
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
      baseSize: 120,
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0,
      priority: 100,
      srcPosition: Vector2(736, 736),
      srcSize: Vector2(208, 69),
      groundOffset: 0,
    ),
    BackgroundData(
      baseSize: 120,
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
      baseSize: 120,
      imagePath: 'CITY_MEGA.png',
      parallaxEffect: 0,
      priority: 100,
      srcPosition: Vector2(1504, 816),
      srcSize: Vector2(320, 66),
      groundOffset: 0,
    ),
  ],
}; 