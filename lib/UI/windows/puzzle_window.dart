import 'package:flutter/material.dart';
import '../../main.dart';
import '../../puzzles/puzzle_base.dart';
import '../window_manager.dart';

class PuzzleWindow extends StatelessWidget {
  final WindowManager windowManager;
  final MyGame game;
  final PuzzleBase puzzle;
  final VoidCallback onComplete;

  const PuzzleWindow({
    super.key,
    required this.windowManager,
    required this.game,
    required this.puzzle,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    // 画面の向きに応じてサイズを調整 (スマホの横向きなどを考慮)
    final bool isSmallScreen = windowManager.screenWidth < 600;
    
    return Container(
      width: windowManager.screenWidth * (isSmallScreen ? 0.95 : 0.85),
      height: windowManager.screenHeight * (isSmallScreen ? 0.95 : 0.9),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 30, spreadRadius: 5),
        ],
      ),
      child: Column(
        children: [
          // ヘッダー (サイズを縮小)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    puzzle.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 18 : 24,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => windowManager.hideWindow(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // パズル本体
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 8.0 : 24.0,
                vertical: 8.0
              ),
              child: puzzle.buildWidget(context, game, () {
                windowManager.hideWindow();
                onComplete();
              }),
            ),
          ),
          // 説明文 (スマホでは小さく)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              puzzle.description,
              style: TextStyle(
                color: Colors.white70,
                fontSize: isSmallScreen ? 8 : 11
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
