import 'package:flutter/material.dart';
import '../window_manager.dart';

class TitleWindow extends StatelessWidget {
  final WindowManager windowManager;

  const TitleWindow({super.key, required this.windowManager});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.blue, // 全画面を覆う暗い背景を一時的に青に変更
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ANAGAATTARA HAIRITAI',
              style: TextStyle(
                fontSize: windowManager.screenWidth * 0.02,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'TRS-Million-Rg',
                letterSpacing: 8,
                shadows: const [
                  Shadow(
                    blurRadius: 10.0,
                    color: Colors.blueAccent,
                    offset: Offset(5.0, 5.0),
                  ),
                ],
              ),
            ),
            SizedBox(height: windowManager.screenHeight * 0.05), // 画面高さの5%
            ElevatedButton(
              onPressed: () {
                windowManager.hideWindow(); // タイトル画面を閉じる
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: EdgeInsets.symmetric(
                  horizontal: windowManager.screenWidth * 0.08, // 画面幅の8%
                  vertical: windowManager.screenHeight * 0.03, // 画面高さの3%
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                'START GAME',
                style: TextStyle(
                  fontSize: windowManager.screenHeight * 0.04, // 画面高さの4%
                  color: Colors.white,
                  fontFamily: 'TRS-Million-Rg',
                  letterSpacing: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 