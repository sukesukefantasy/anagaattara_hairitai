import 'package:flutter/material.dart';
import 'package:flame/components.dart';

import '../../main.dart';
import '../window_manager.dart';

/// 父のログから導出した 6 桁（[GameRuntimeState.sixDigitTrueDialCodePadded]）。
class TrueVaultDialWindow extends StatefulWidget {
  final MyGame game;
  final WindowManager windowManager;

  const TrueVaultDialWindow({
    super.key,
    required this.game,
    required this.windowManager,
  });

  @override
  State<TrueVaultDialWindow> createState() => _TrueVaultDialWindowState();
}

class _TrueVaultDialWindowState extends State<TrueVaultDialWindow> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _tryUnlock() async {
    final state = widget.game.gameRuntimeState;
    final entered = _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (entered.length != 6) {
      widget.windowManager.showDialog(['6 桁の数字で入力してください。']);
      return;
    }
    if (entered == state.sixDigitTrueDialCodePadded) {
      widget.windowManager.hideWindow();
      state.trueSequencePhase = 3;
      await state.saveGame();
      final p = Vector2(
        -100,
        widget.game.initialGameCanvasSize.y - widget.game.player.size.y / 2,
      );
      await widget.game.sceneManager.loadScene(
        'outdoor_true_finale',
        initialPlayerPosition: p,
      );
    } else {
      widget.windowManager.showDialog([
        '錠が食い違う。',
        '父のメモと、送還ログをもう一度辿ってみよう。',
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = widget.windowManager.fontSize;
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1520).withOpacity(0.97),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade700.withOpacity(0.6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '6桁ダイヤル',
                style: TextStyle(
                  color: Colors.amber.shade100,
                  fontSize: fs + 2,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                ),
              ),
              SizedBox(height: fs * 0.5),
              Text(
                '父のメモと日記のキーから導かれる合言葉（数字）。',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: fs - 2,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                ),
              ),
              SizedBox(height: fs * 0.75),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fs + 4,
                  letterSpacing: 8,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.black38,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: fs),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => widget.windowManager.hideWindow(),
                    child: Text('やめる', style: TextStyle(color: Colors.white54, fontSize: fs)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _tryUnlock,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade900,
                    ),
                    child: Text('開錠', style: TextStyle(fontSize: fs)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
