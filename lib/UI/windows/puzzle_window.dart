import 'package:flutter/material.dart';
import '../../main.dart';
import '../../puzzles/puzzle_base.dart';
import '../window_manager.dart';
import 'window_base.dart';

class PuzzleWindow extends StatelessWidget with GameWindowResponsiveMixin {
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
    final isMobile = getIsMobile(windowManager);
    
    return GameWindow(
      windowManager: windowManager,
      title: puzzle.title,
      showCloseButton: true,
      backgroundColor: Colors.black.withOpacity(0.95),
      widthFactor: 0.85,
      heightFactor: 0.9,
      mobileWidthFactor: 0.95,
      mobileHeightFactor: 0.95,
      child: Column(
        children: [
          // パズル本体
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8.0 : 24.0,
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
                fontSize: isMobile ? 10 : 12,
                fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
