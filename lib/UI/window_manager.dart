import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'responsive_ui_font.dart';
import 'windows/message_window.dart';
import 'windows/true_vault_dial_window.dart';
import 'windows/cargo_transfer_window.dart';
import '../main.dart';
import '../component/player_cargo_terminal.dart';

/// メッセージリクエストのデータ構造
class MessageRequest {
  final List<String> messages;
  /// メッセージUIを閉じたあとに実行（キューが空なら先にオーバーレイを外してゲーム再開後に await）
  final Future<void> Function()? onClosed;
  final List<String>? options; // 選択肢
  final Function(int)? onSelect; // 選択時のコールバック
  final Color? bodyTextColor;
  MessageRequest({
    required this.messages,
    this.onClosed,
    this.options,
    this.onSelect,
    this.bodyTextColor,
  });
}

/// ツイート（吹き出し）リクエストのデータ構造
class TweetRequest {
  final String id;
  final String message;
  final PositionComponent? target;
  final Vector2? offset;
  final bool clampToScreen;
  final Duration duration;
  final Color? textColor;
  final Color? backgroundColor;

  TweetRequest({
    required this.id,
    required this.message,
    this.target,
    this.offset,
    this.clampToScreen = false,
    this.duration = const Duration(seconds: 4),
    this.textColor,
    this.backgroundColor,
  });
}

/// ウィンドウの種類を識別するためのEnum
enum GameWindowType {
  none,
  title,
  pause,
  itemBag,
  shop,
  crafting,
  message,
  puzzle,
  calibration,
  loading,
  automationMenu,
  codex,
  trueVaultDial,
  tweet,
  cargoTransfer,
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

  // アクティブなツイートのリスト
  final List<TweetRequest> _activeTweets = [];
  List<TweetRequest> get activeTweets => List.unmodifiable(_activeTweets);

  GameWindowType get currentWindowType => _currentWindowType;
  Widget? get currentWindowContent => _currentWindowContent;
  // これらのgetterは直接は不要になるが、互換性のため残すか、使用箇所を修正する
  double get currentWindowWidth => screenWidth;
  double get currentWindowHeight => screenHeight;

  // 画面幅と高さに基づいた統一フォントサイズ（MessageWindow 等）
  double get fontSize => gameUiBaseFontSize(screenWidth, screenHeight);

  // コンストラクタで画面サイズを受け取る
  WindowManager({required this.screenWidth, required this.screenHeight});

  /// ツイートを表示する
  void showTweet(
    String message, {
    PositionComponent? target,
    Vector2? offset,
    bool clampToScreen = false,
    Duration duration = const Duration(seconds: 4),
    Color? textColor,
    Color? backgroundColor,
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final request = TweetRequest(
      id: id,
      message: message,
      target: target,
      offset: offset,
      clampToScreen: clampToScreen,
      duration: duration,
      textColor: textColor,
      backgroundColor: backgroundColor,
    );

    _activeTweets.add(request);
    notifyListeners();

    // 指定時間後に削除
    Future.delayed(duration, () {
      _activeTweets.removeWhere((t) => t.id == id);
      notifyListeners();
    });
  }

  /// メッセージをキューに追加して表示する（推奨される新しい方法）
  void showDialog(
    List<String> messages, {
    Future<void> Function()? onClosed,
    List<String>? options,
    Function(int)? onSelect,
    Color? bodyTextColor,
  }) {
    _messageQueue.add(
      MessageRequest(
        messages: messages,
        onClosed: onClosed,
        options: options,
        onSelect: onSelect,
        bodyTextColor: bodyTextColor,
      ),
    );
    
    bool canImmediatelyProcessMessageQueue =
        _currentWindowType == GameWindowType.none ||
        _currentWindowType == GameWindowType.automationMenu ||
        _currentWindowType == GameWindowType.codex ||
        _currentWindowType == GameWindowType.crafting ||
        _currentWindowType == GameWindowType.trueVaultDial;

    if (canImmediatelyProcessMessageQueue) {
      _processNextMessage();
    }
  }

  /// メッセージ用オーバーレイだけ外す（キューは触らない）。hideWindow とは別。
  void _dismissActiveMessageChrome() {
    if (_currentWindowType == GameWindowType.message) {
      _currentWindowType = GameWindowType.none;
      _currentWindowContent = null;
      notifyListeners();
    }
  }

  Future<void> _handleMessageClosed(MessageRequest request) async {
    if (_messageQueue.isEmpty) {
      _dismissActiveMessageChrome();
      await request.onClosed?.call();
    } else {
      await request.onClosed?.call();
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
      messageTextColor: request.bodyTextColor,
      onSelect: (index) {
        request.onSelect?.call(index);
      },
      onClosed: () => _handleMessageClosed(request),
    );
    notifyListeners();
  }

  void showWindow(GameWindowType type, Widget? content) {
    debugPrint('WindowManager: showWindow called. type: $type, content null: ${content == null}');
    _currentWindowType = type;
    _currentWindowContent = content;
    notifyListeners();
  }

  void changeWindow(GameWindowType type) {
    _currentWindowType = type;
    notifyListeners();
  }

  /// オーバーレイのみ閉じる（メッセージキューは保持）。
  void hideOverlay() {
    _currentWindowType = GameWindowType.none;
    _currentWindowContent = null;
    notifyListeners();
  }

  void hideWindow() {
    _currentWindowType = GameWindowType.none;
    _currentWindowContent = null;
    _messageQueue.clear(); // 強制終了時はキューもクリア
    notifyListeners();
  }

  /// True 深層・6桁ダイアル（金庫）
  void showTrueVaultDial(MyGame game) {
    showWindow(
      GameWindowType.trueVaultDial,
      TrueVaultDialWindow(
        game: game,
        windowManager: this,
      ),
    );
  }

  /// カーゴ資源蓄積UI
  void showCargoTransfer(MyGame game, PlayerCargoTerminal terminal) {
    showWindow(
      GameWindowType.cargoTransfer,
      CargoTransferWindow(
        game: game,
        windowManager: this,
        terminal: terminal,
      ),
    );
  }

  /// 指定のウィンドウタイプが現在表示中かどうかを返す
  bool isShowing(GameWindowType type) => _currentWindowType == type;
} 