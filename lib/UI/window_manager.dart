import 'package:flutter/material.dart';
import 'windows/message_window.dart';

/// メッセージリクエストのデータ構造
class MessageRequest {
  final List<String> messages;
  final VoidCallback? onFinish;
  final List<String>? options; // 選択肢
  final Function(int)? onSelect; // 選択時のコールバック
  MessageRequest({required this.messages, this.onFinish, this.options, this.onSelect});
}

/// ウィンドウの種類を識別するためのEnum
enum GameWindowType {
  none,
  title,
  pause,
  itemBag,
  shop,
  message,
  puzzle,
}

/// ウィンドウ表示の状態と内容を管理するChangeNotifier
/// null の場合はウィンドウが非表示
class WindowManager extends ChangeNotifier {
  GameWindowType _currentWindowType = GameWindowType.none;
  Widget? _currentWindowContent;
  // 画面サイズ情報を追加
  final double screenWidth;
  final double screenHeight;

  // メッセージのキュー
  final List<MessageRequest> _messageQueue = [];

  GameWindowType get currentWindowType => _currentWindowType;
  Widget? get currentWindowContent => _currentWindowContent;
  // これらのgetterは直接は不要になるが、互換性のため残すか、使用箇所を修正する
  double get currentWindowWidth => screenWidth;
  double get currentWindowHeight => screenHeight;

  // 画面幅と高さに基づいた統一フォントサイズ
  double get fontSize => (screenWidth < 600 || screenHeight < 500) ? 12.0 : 16.0;

  // コンストラクタで画面サイズを受け取る
  WindowManager({required this.screenWidth, required this.screenHeight});

  /// メッセージをキューに追加して表示する（推奨される新しい方法）
  void showDialog(List<String> messages, {VoidCallback? onFinish, List<String>? options, Function(int)? onSelect}) {
    _messageQueue.add(MessageRequest(messages: messages, onFinish: onFinish, options: options, onSelect: onSelect));
    
    // 他のウィンドウ（ポーズなど）が開いておらず、かつメッセージ表示中でなければ開始
    if (_currentWindowType == GameWindowType.none) {
      _processNextMessage();
    }
  }

  /// キュー内の次のメッセージを処理
  void _processNextMessage() {
    if (_messageQueue.isEmpty) {
      // メッセージ終了時に他のウィンドウ（パズルなど）が開始されていなければ非表示にする
      if (_currentWindowType == GameWindowType.message) {
        hideWindow();
      }
      return;
    }

    final request = _messageQueue.removeAt(0);
    
    // 内部的に showWindow を呼び出す
    _currentWindowType = GameWindowType.message;
    _currentWindowContent = MessageWindow(
      key: UniqueKey(), // 状態をリセットするためにKeyを追加
      messages: request.messages,
      fontSize: fontSize, // WindowManagerのfontSizeを渡す
      options: request.options,
      onSelect: (index) {
        request.onSelect?.call(index);
      },
      onFinish: () {
        // このメッセージの終了処理を実行
        request.onFinish?.call();
        // 次のメッセージがあれば表示
        _processNextMessage();
      },
    );
    notifyListeners();
  }

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
    _messageQueue.clear(); // 強制終了時はキューもクリア
    notifyListeners();
  }
} 