import 'package:flutter/material.dart';
import '../window_manager.dart';
import '../../component/item/item_bag.dart';
import '../../main.dart';
import 'title_window.dart';
import 'window_base.dart';

class PauseWindow extends StatelessWidget with GameWindowResponsiveMixin {
  final WindowManager windowManager;
  final ItemBag itemBag;
  final MyGame game;

  const PauseWindow({
    super.key, 
    required this.windowManager, 
    required this.itemBag,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = getIsMobile(windowManager);
    final screenWidth = windowManager.screenWidth;
    final screenHeight = windowManager.screenHeight;

    return GameWindow(
      windowManager: windowManager,
      backgroundColor: Colors.blueGrey[800],
      widthFactor: 0.5,
      heightFactor: 0.6,
      mobileWidthFactor: 0.8,
      mobileHeightFactor: 0.8,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'PAUSED',
            style: TextStyle(
              fontSize: isMobile ? 32 : screenHeight * 0.07,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
              letterSpacing: 5,
            ),
          ),
          SizedBox(height: isMobile ? 20 : screenHeight * 0.03),
          ElevatedButton(
            onPressed: () {
              windowManager.hideWindow();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 40 : screenWidth * 0.05,
                vertical: isMobile ? 12 : screenHeight * 0.02,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'resume',
              style: TextStyle(
                fontSize: isMobile ? 18 : screenHeight * 0.035,
                color: Colors.white,
                fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
              ),
            ),
          ),
          SizedBox(height: isMobile ? 12 : screenHeight * 0.015),
          ElevatedButton(
            onPressed: () {
              windowManager.hideWindow();
              windowManager.showWindow(
                GameWindowType.title,
                TitleWindow(
                  windowManager: windowManager,
                  onStart: () {},
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 85, 51, 0),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 40 : screenWidth * 0.05,
                vertical: isMobile ? 12 : screenHeight * 0.02,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'back to title',
              style: TextStyle(
                fontSize: isMobile ? 18 : screenHeight * 0.035,
                color: Colors.white,
                fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
