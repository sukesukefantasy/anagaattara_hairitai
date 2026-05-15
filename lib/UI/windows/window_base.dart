import 'package:flutter/material.dart';
import '../window_manager.dart';

/// すべてのゲーム内ウィンドウの共通基盤となるラッパーウィジェット
class GameWindow extends StatelessWidget {
  final WindowManager windowManager;
  final Widget child;
  final Color? backgroundColor;
  final double? widthFactor;
  final double? heightFactor;
  final double? mobileWidthFactor;
  final double? mobileHeightFactor;
  final String? title;
  final bool showCloseButton;

  const GameWindow({
    super.key,
    required this.windowManager,
    required this.child,
    this.backgroundColor,
    this.widthFactor,
    this.heightFactor,
    this.mobileWidthFactor,
    this.mobileHeightFactor,
    this.title,
    this.showCloseButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = windowManager.screenWidth;
    final screenHeight = windowManager.screenHeight;
    final isMobile = screenWidth < 600 || screenHeight < 500;

    final wFactor = isMobile ? (mobileWidthFactor ?? 0.9) : (widthFactor ?? 0.6);
    final hFactor = isMobile ? (mobileHeightFactor ?? 0.9) : (heightFactor ?? 0.8);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: screenWidth * wFactor,
          height: screenHeight * hFactor,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.black.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              if (title != null || showCloseButton)
                _buildHeader(isMobile, screenWidth),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile, double screenWidth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (title != null)
            Text(
              title!,
              style: TextStyle(
                fontSize: isMobile ? 18 : screenWidth * 0.02,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                letterSpacing: 4,
              ),
            ),
          if (showCloseButton)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => windowManager.hideWindow(),
              ),
            ),
        ],
      ),
    );
  }
}

/// ウィンドウ内のコンテンツウィジェットで共通のレスポンシブプロパティを利用するためのミックスイン
mixin GameWindowResponsiveMixin {
  bool getIsMobile(WindowManager wm) =>
      wm.screenWidth < 600 || wm.screenHeight < 500;

  double getResponsiveFontSize(WindowManager wm, {double mobile = 14, double? desktopFactor}) {
    if (getIsMobile(wm)) return mobile;
    return wm.screenWidth * (desktopFactor ?? 0.02);
  }
}
