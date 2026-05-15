import 'package:flutter/material.dart';
import '../window_manager.dart';

class TitleWindow extends StatelessWidget {
  final WindowManager windowManager;
  final VoidCallback? onStart;

  const TitleWindow({super.key, required this.windowManager, this.onStart});

  @override
  Widget build(BuildContext context) {
    debugPrint('TitleWindow: build called. screenWidth: ${windowManager.screenWidth}, screenHeight: ${windowManager.screenHeight}');
    final screenWidth = windowManager.screenWidth;
    final screenHeight = windowManager.screenHeight;
    final isMobile = screenWidth < 600 || screenHeight < 500;

    return Material(
      color: Colors.blue, // 全画面を覆う暗い背景を一時的に青に変更
      child: SizedBox.expand(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ANAGAATTARA HAIRITAI',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isMobile ? 24 : screenWidth * 0.02,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                  letterSpacing: isMobile ? 4 : 8,
                  shadows: const [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.blueAccent,
                      offset: Offset(5.0, 5.0),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isMobile ? 30 : screenHeight * 0.05),
              ElevatedButton(
                onPressed: () {
                  windowManager.hideWindow(); // タイトル画面を閉じる
                  if (onStart != null) onStart!();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 40 : windowManager.screenWidth * 0.08,
                    vertical: isMobile ? 15 : windowManager.screenHeight * 0.03,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  'START GAME',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : windowManager.screenHeight * 0.04,
                    color: Colors.white,
                    fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                    letterSpacing: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 