import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import '../../../main.dart';
import 'car_enemy.dart';
import 'walking_enemy.dart';
import 'enemy_base.dart'; // EnemyBaseをインポート
import '../../scene/outdoor_scene.dart'; // OutdoorSceneのgroundHeight/underGroundHeightにアクセスするため

class EnemyManager {
  final Random _random = Random();
  final double _spawnInterval = 0.2; // 敵をスポーンさせる間隔（秒）を1.5から0.5に短縮
  double _timeSinceLastSpawn = 0.0;
  final MyGame game; // MyGameインスタンスを注入

  EnemyManager(this.game);

  // スケジュール定義
  static const Map<int, Map<int, Map<String, dynamic>>> _schedule = {
    // 月曜から金曜 (1-5)
    1: {
      7: {
        'walking': [50, 60],
        'car': [5, 7],
        'left_direction_ratio': 0.9,
      }, // 通勤ラッシュ（左向きが多い）
      9: {
        'walking': [5, 10],
        'car': [2, 3],
        'left_direction_ratio': 0.5,
      }, // 午前
      12: {
        'walking': [15, 20],
        'car': [0, 1],
        'left_direction_ratio': 0.5,
      }, // 昼時
      13: {
        'walking': [5, 10],
        'car': [0, 1],
        'left_direction_ratio': 0.5,
      }, // 午後
      17: {
        'walking': [50, 60],
        'car': [5, 7],
        'left_direction_ratio': 0.1,
      }, // 帰宅ラッシュ（右向きが多い）
      21: {
        'walking': [7, 12],
        'car': [1, 3],
        'left_direction_ratio': 0.5,
      }, // 夜時
      23: {
        'walking': [0, 0],
        'car': [0, 0],
        'left_direction_ratio': 0.5,
      }, // 深夜
      5: {
        'walking': [1, 3],
        'car': [0, 1],
        'left_direction_ratio': 0.5,
      }, // 早朝
    },
    // 土日 (6-7)
    6: {
      7: {
        'walking': [1, 4],
        'car': [0, 0],
        'left_direction_ratio': 0.5,
      }, // 起きるころ
      9: {
        'walking': [5, 10],
        'car': [2, 3],
        'left_direction_ratio': 0.5,
      }, // 午前
      12: {
        'walking': [20, 30],
        'car': [0, 1],
        'left_direction_ratio': 0.5,
      }, // 昼時
      13: {
        'walking': [10, 20],
        'car': [2, 4],
        'left_direction_ratio': 0.5,
      }, // 午後
      17: {
        'walking': [10, 20],
        'car': [3, 5],
        'left_direction_ratio': 0.5,
      }, // 夕方
      21: {
        'walking': [20, 30],
        'car': [0, 0],
        'left_direction_ratio': 0.5,
      }, // 夜時
      23: {
        'walking': [0, 0],
        'car': [0, 0],
        'left_direction_ratio': 0.5,
      }, // 深夜
      5: {
        'walking': [0, 0],
        'car': [0, 0],
        'left_direction_ratio': 0.5,
      }, // 早朝
    },
    7: {
      7: {
        'walking': [1, 4],
        'car': [0, 0],
        'left_direction_ratio': 0.5,
      }, // 起きるころ
      9: {
        'walking': [5, 10],
        'car': [2, 3],
        'left_direction_ratio': 0.5,
      }, // 午前
      12: {
        'walking': [20, 30],
        'car': [0, 1],
        'left_direction_ratio': 0.5,
      }, // 昼時
      13: {
        'walking': [10, 20],
        'car': [2, 4],
        'left_direction_ratio': 0.5,
      }, // 午後
      17: {
        'walking': [10, 20],
        'car': [3, 5],
        'left_direction_ratio': 0.5,
      }, // 夕方
      21: {
        'walking': [20, 30],
        'car': [0, 0],
        'left_direction_ratio': 0.5,
      }, // 夜時
      23: {
        'walking': [0, 0],
        'car': [0, 0],
        'left_direction_ratio': 0.5,
      }, // 深夜
      5: {
        'walking': [0, 0],
        'car': [0, 0],
        'left_direction_ratio': 0.5,
      }, // 早朝
    },
  };

  // 現在のスケジュールに基づいて、左向きの敵をスポーンさせる割合を返します。
  double _getLeftDirectionRatio() {
    final currentHour = game.timeService.hour;
    final currentDay = game.timeService.day;

    final daySchedule =
        currentDay >= 1 && currentDay <= 5
            ? _schedule[1]
            : _schedule[currentDay];

    if (daySchedule == null) {
      return 0.5; // デフォルト値
    }

    int? targetHour;
    for (final hour in daySchedule.keys.toList()..sort()) {
      if (currentHour >= hour) {
        targetHour = hour;
      } else {
        break;
      }
    }

    if (targetHour == null) {
      final sortedHours = daySchedule.keys.toList()..sort();
      if (currentHour >= sortedHours.last || currentHour < sortedHours.first) {
        targetHour = 23;
      }
    }

    final counts = daySchedule[targetHour];
    return (counts?['left_direction_ratio'] as double?) ?? 0.5; // デフォルトは0.5
  }

  Map<String, int> _getMaxEnemyCounts() {
    final currentHour = game.timeService.hour;
    final currentDay = game.timeService.day;

    final daySchedule =
        currentDay >= 1 && currentDay <= 5
            ? _schedule[1]
            : _schedule[currentDay];

    if (daySchedule == null) {
      return {'walking': 0, 'car': 0};
    }

    // 現在の時間がどの時間帯に属するかを判断
    int? targetHour;
    for (final hour in daySchedule.keys.toList()..sort()) {
      if (currentHour >= hour) {
        targetHour = hour;
      } else {
        break;
      }
    }

    if (targetHour == null) {
      // 5時より前、かつ23時以降の深夜帯の処理
      // scheduleのキーがソートされていることを前提とする
      final sortedHours = daySchedule.keys.toList()..sort();
      if (currentHour >= sortedHours.last || currentHour < sortedHours.first) {
        // 23時以降か5時以前
        targetHour = 23; // 深夜のスケジュールを使用
      }
    }

    final counts = daySchedule[targetHour];

    if (counts == null) {
      return {'walking': 0, 'car': 0};
    }

    final walkingRange = counts['walking']! as List<int>;
    final carRange = counts['car']! as List<int>;

    final maxWalking =
        _random.nextInt(walkingRange[1] - walkingRange[0] + 1) +
        walkingRange[0];
    final maxCar = _random.nextInt(carRange[1] - carRange[0] + 1) + carRange[0];

    return {'walking': maxWalking, 'car': maxCar};
  }

  // 新しい敵をスポーンする必要があるかを判断し、インスタンスを返すメソッド
  EnemyBase? trySpawnEnemy(
    double dt,
    int currentWalkingEnemies,
    int currentCarEnemies,
  ) {
    _timeSinceLastSpawn += dt; // 経過時間を更新

    if (_timeSinceLastSpawn >= _spawnInterval) {
      _timeSinceLastSpawn = 0.0; // タイマーをリセット

      final maxCounts = _getMaxEnemyCounts();
      final maxWalkingEnemies = maxCounts['walking']!;
      final maxCarEnemies = maxCounts['car']!;

      // ランダムな進行方向を決定
      final directionRatio = _getLeftDirectionRatio();
      final direction =
          _random.nextDouble() < directionRatio ? -1.0 : 1.0; // 左向きか右向きか

      // 最大数に達していない敵をランダムにスポーン
      if (currentWalkingEnemies < maxWalkingEnemies &&
          currentCarEnemies < maxCarEnemies) {
        // 両方スポーン可能ならランダムに選択
        if (_random.nextBool()) {
          return _createEnemyInstance(
            isWalkingEnemy: true,
            direction: direction,
          );
        } else {
          return _createEnemyInstance(
            isWalkingEnemy: false,
            direction: direction,
          );
        }
      } else if (currentWalkingEnemies < maxWalkingEnemies) {
        // 歩行者のみスポーン可能
        return _createEnemyInstance(isWalkingEnemy: true, direction: direction);
      } else if (currentCarEnemies < maxCarEnemies) {
        // 車のみスポーン可能
        return _createEnemyInstance(
          isWalkingEnemy: false,
          direction: direction,
        );
      }
    }
    return null; // スポーンしない場合
  }

  // 敵インスタンスを生成するヘルパーメソッド
  EnemyBase _createEnemyInstance({
    required bool isWalkingEnemy,
    required double direction,
  }) {
    double spawnX; // スポーンX座標は方向によって変わる
    final currentScene = game.sceneManager.currentScene; // 現在のシーンを取得

    // シーンが存在し、かつgroundComponentが設定されている場合
    if (currentScene != null && currentScene.groundComponent != null) {
      final ground = currentScene.groundComponent!;
      final groundLeft = ground.position.x;
      final groundRight = ground.position.x + ground.size.x;

      if (direction == -1.0) {
        // 左向きの場合、Groundの右端から出現
        spawnX = groundRight + 100; // Groundの右端から100ピクセル外
      } else {
        // 右向きの場合、Groundの左端から出現
        spawnX = groundLeft - 100; // Groundの左端から100ピクセル外
      }
    } else {
      // Groundが利用できない場合のフォールバック（既存の画面範囲でのスポーンロジック）
      debugPrint(
        'Warning: Ground component not available for enemy spawning. Falling back to screen bounds.',
      );
      if (direction == -1.0) {
        // 左向きの場合、画面右端から出現
        spawnX = game.camera.visibleWorldRect.right + 100; // カメラの右端から100ピクセル外
      } else {
        // 右向きの場合、画面左端から出現
        spawnX = game.camera.visibleWorldRect.left - 100; // カメラの左端から100ピクセル外
      }
    }

    if (isWalkingEnemy) {
      final walkCycleSpeed =
          3.0 + _random.nextDouble() * 4.0; // ウォーキングエネミーの歩行サイクル速度をランダムに決定
      return WalkingEnemy(
        position: Vector2(
          spawnX,
          game.initialGameCanvasSize.y, // Anchor.bottomCenterに合わせたY座標（地面に揃える）
        ),
        size: Vector2.all(50),
        direction: direction,
        walkCycleSpeed: walkCycleSpeed,
      );
    } else {
      return CarEnemy(
        position: Vector2(
          spawnX,
          game.initialGameCanvasSize.y, // Anchor.bottomCenterに合わせたY座標（地面に揃える）
        ),
        size: Vector2(252, 104),
        direction: direction,
      );
    }
  }

  // シーンロード時に敵インスタンスを生成するヘルパーメソッド
  EnemyBase createEnemyOnLoad({bool? isWalkingEnemy, double? direction}) {
    final randomDirection =
        _random.nextDouble() < _getLeftDirectionRatio() ? -1.0 : 1.0;
    final finalDirection = direction ?? randomDirection;

    final currentScene = game.sceneManager.currentScene; // 現在のシーンを取得

    double spawnX;
    // シーンが存在し、かつgroundComponentが設定されている場合
    if (currentScene != null && currentScene.groundComponent != null) {
      final ground = currentScene.groundComponent!;
      final groundLeft = ground.position.x;
      final groundRight = ground.position.x + ground.size.x;
      // Groundの範囲内でランダムなX座標を決定
      spawnX =
          ground.isScrollForward
              ? (_random.nextDouble() * (groundRight - groundLeft))
              : -1 * (_random.nextDouble() * (groundRight - groundLeft));
    } else {
      // Groundが利用できない場合のフォールバック（既存の画面範囲でのスポーンロジック）
      debugPrint(
        'Warning: Ground component not available for enemy spawning on load. Falling back to screen bounds.',
      );
      final minX = game.camera.visibleWorldRect.left; // カメラの左端
      final maxX = game.camera.visibleWorldRect.right; // カメラの右端
      spawnX = minX + _random.nextDouble() * (maxX - minX);
    }

    final bool spawnWalking = isWalkingEnemy ?? _random.nextBool();

    if (spawnWalking) {
      final walkCycleSpeed =
          3.0 + _random.nextDouble() * 4.0; // ウォーキングエネミーの歩行サイクル速度をランダムに決定
      //debugPrint('WalkingEnemy spawned at X: $spawnX');
      return WalkingEnemy(
        position: Vector2(
          spawnX,
          game.initialGameCanvasSize.y, // Anchor.bottomCenterに合わせたY座標（地面に揃える）
        ),
        size: Vector2.all(50),
        direction: finalDirection,
        walkCycleSpeed: walkCycleSpeed,
      );
    } else {
      return CarEnemy(
        position: Vector2(
          spawnX,
          game.initialGameCanvasSize.y, // Anchor.bottomCenterに合わせたY座標（地面に揃える）
        ),
        size: Vector2(252, 104),
        direction: finalDirection,
      );
    }
  }
}
