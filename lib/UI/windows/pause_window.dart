import 'package:flutter/material.dart';
import '../window_manager.dart';
import '../../component/item/item_bag.dart'; // ItemBagをインポート
import 'item_bag_window.dart'; // ItemBagWindowをインポート
import '../../main.dart'; // MyGameのために追加
import 'title_window.dart'; // TitleWindowをインポート

class PauseWindow extends StatelessWidget {
  final WindowManager windowManager;
  final ItemBag itemBag; // ItemBagを追加
  final MyGame game; // MyGameを追加

  const PauseWindow({
    super.key, 
    required this.windowManager, 
    required this.itemBag,
    required this.game, // コンストラクタで受け取る
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent, // 背景の透過
      child: Center(
        child: Container(
          width: windowManager.screenWidth * 0.5,
          height: windowManager.screenHeight * 0.6,
          decoration: BoxDecoration(
            color: Colors.blueGrey[800], // ウィンドウの背景色
            borderRadius: BorderRadius.circular(20), // 角の丸み
            border: Border.all(color: Colors.white, width: 2), // 枠線
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'PAUSED',
                style: TextStyle(
                  fontSize: windowManager.screenHeight * 0.07, // 画面高さの7%
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'TRS-Million-Rg',
                  letterSpacing: 5,
                ),
              ),
              SizedBox(height: windowManager.screenHeight * 0.03), // 画面高さの3%
              ElevatedButton(
                onPressed: () {
                  windowManager.hideWindow();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: EdgeInsets.symmetric(
                    horizontal: windowManager.screenWidth * 0.05, // 画面幅の5%
                    vertical: windowManager.screenHeight * 0.02, // 画面高さの2%
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'resume',
                  style: TextStyle(
                    fontSize: windowManager.screenHeight * 0.035, // 画面高さの3.5%
                    color: Colors.white,
                    fontFamily: 'TRS-Million-Rg',
                  ),
                ),
              ),
              SizedBox(height: windowManager.screenHeight * 0.015), // 画面高さの1.5%
              ElevatedButton(
                onPressed: () {
                  windowManager.hideWindow();
                  windowManager.showWindow(
                    GameWindowType.title,
                    TitleWindow(
                      windowManager: windowManager,
                      onStart: () {
                        // タイトルから戻った時も羅針盤メッセージを表示（クリア済みならスキップ）
                        final state = game.gameRuntimeState;
                        final currentSceneId = state.currentOutdoorSceneId ?? 'outdoor_1';
                        game.routeManager.showCompassMessage(currentSceneId);
                      },
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 85, 51, 0), // タイトルに戻るボタンの色
                  padding: EdgeInsets.symmetric(
                    horizontal: windowManager.screenWidth * 0.05, // 画面幅の5%
                    vertical: windowManager.screenHeight * 0.02, // 画面高さの2%
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'back to title',
                  style: TextStyle(
                    fontSize: windowManager.screenHeight * 0.035, // 画面高さの3.5%
                    color: Colors.white,
                    fontFamily: 'TRS-Million-Rg',
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