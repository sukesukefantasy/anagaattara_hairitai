import 'package:flutter/material.dart';

/// ウィンドウの種類を識別するためのEnum
enum GameWindowType {
  none,
  title,
  pause,
  itemBag,
  shop,
  message,
}

/// ウィンドウ表示の状態と内容を管理するChangeNotifier
/// null の場合はウィンドウが非表示
class WindowManager extends ChangeNotifier {
  GameWindowType _currentWindowType = GameWindowType.none;
  Widget? _currentWindowContent;
  // 画面サイズ情報を追加
  final double screenWidth;
  final double screenHeight;

  GameWindowType get currentWindowType => _currentWindowType;
  Widget? get currentWindowContent => _currentWindowContent;
  // これらのgetterは直接は不要になるが、互換性のため残すか、使用箇所を修正する
  double get currentWindowWidth => screenWidth;
  double get currentWindowHeight => screenHeight;

  // コンストラクタで画面サイズを受け取る
  WindowManager({required this.screenWidth, required this.screenHeight});

  void showWindow(GameWindowType type, Widget? content) {
    _currentWindowType = type;
    _currentWindowContent = content;
    notifyListeners();
  }

  void changeWindow(GameWindowType type) {
    _currentWindowType = type;
    notifyListeners();
  }

  void hideWindow() {
    _currentWindowType = GameWindowType.none;
    _currentWindowContent = null;
    notifyListeners();
  }
} 