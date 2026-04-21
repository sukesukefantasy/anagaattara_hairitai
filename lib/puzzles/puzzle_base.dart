import 'package:flutter/material.dart';
import '../../main.dart';

/// パズルゲームの基底クラス
abstract class PuzzleBase {
  final String id;
  final String title;
  final String description;

  PuzzleBase({
    required this.id,
    required this.title,
    required this.description,
  });

  /// パズルのUIウィジェットを生成する
  Widget buildWidget(BuildContext context, MyGame game, VoidCallback onComplete);

  /// パズルを初期化（動的生成など）
  void initialize();
}
