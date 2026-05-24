import 'dart:async';

import 'package:flutter/foundation.dart';

/// stageClear 時の Rive カットシーン表示を GameScreen と MyGame で共有する。
class StageClearCinematicController extends ChangeNotifier {
  static const String assetPath = 'assets/rive/trainscene.riv';
  static const String artboardName = 'Artboard_trainScene';
  /// Rive エディタ上の State Machine 名（Timeline ではなく SM を再生する）
  static const String stateMachineName = 'State Machine 1';
  static const Duration fadeDuration = Duration(seconds: 1);
  /// Timeline1（一方通行10秒）が終わるまで待てる長さ。タップで早送り可。
  static const Duration maxWait = Duration(seconds: 10);

  bool _visible = false;
  bool _playing = false;
  double _blackOpacity = 1.0;
  Timer? _skipTimer;
  Completer<void>? _waitCompleter;
  Completer<void>? _riveReadyCompleter;

  /// Flame の黒フェードと同期する（MyGame が bind 時に設定）
  Future<void> Function()? fadeFromBlack;
  Future<void> Function()? fadeToBlack;

  /// 演出終了時に Rive の再生・オーディオを止める（オーバーレイが登録）
  VoidCallback? stopRivePlayback;

  /// 演出開始時に Rive を再開する（オーバーレイが登録）
  VoidCallback? prepareRivePlayback;

  bool get visible => _visible;
  bool get playing => _playing;
  double get blackOpacity => _blackOpacity;

  void markRiveReady() {
    if (_riveReadyCompleter != null && !_riveReadyCompleter!.isCompleted) {
      _riveReadyCompleter!.complete();
    }
  }

  void markRiveFailed() {
    if (_riveReadyCompleter != null && !_riveReadyCompleter!.isCompleted) {
      _riveReadyCompleter!.complete();
    }
  }

  void skip() {
    final completer = _waitCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  /// 1. 表示 → フェードイン（Rive 露出）→ 8 秒 or タップ → フェードアウト → 非表示
  Future<void> playTrainScene() async {
    if (_playing) return;
    _playing = true;
    _visible = true;
    _blackOpacity = 1.0;
    _riveReadyCompleter = Completer<void>();
    notifyListeners();
    prepareRivePlayback?.call();

    try {
      await _riveReadyCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('StageClearCinematic: Rive load timeout, skipping cinematic');
        },
      );

      await Future.wait([
        _animateBlackOpacity(1.0, 0.0),
        if (fadeFromBlack != null) fadeFromBlack!(),
      ]);

      _waitCompleter = Completer<void>();
      _skipTimer = Timer(maxWait, skip);
      await _waitCompleter!.future;
      _skipTimer?.cancel();
      _skipTimer = null;

      await Future.wait([
        _animateBlackOpacity(0.0, 1.0),
        if (fadeToBlack != null) fadeToBlack!(),
      ]);
    } finally {
      stopRivePlayback?.call();
      _skipTimer?.cancel();
      _skipTimer = null;
      _waitCompleter = null;
      _riveReadyCompleter = null;
      _visible = false;
      _playing = false;
      _blackOpacity = 1.0;
      notifyListeners();
    }
  }

  Future<void> _animateBlackOpacity(double from, double to) async {
    const steps = 30;
    final stepDuration = Duration(
      microseconds: fadeDuration.inMicroseconds ~/ steps,
    );
    for (var i = 0; i <= steps; i++) {
      _blackOpacity = from + (to - from) * (i / steps);
      notifyListeners();
      if (i < steps) {
        await Future.delayed(stepDuration);
      }
    }
    _blackOpacity = to;
    notifyListeners();
  }
}
