import 'dart:async';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../puzzle_base.dart';

class FuelPuzzle extends PuzzleBase {
  double currentFuel = 0.0;
  final double targetFuel = 80.0;
  final double fuelCapacity = 100.0;
  bool isFilling = false;

  FuelPuzzle()
      : super(
          id: 'fuel_puzzle',
          title: '燃料補給',
          description: 'バルブを開いて、燃料を目標ライン（80%）までピッタリ補給してください。',
        ) {
    initialize();
  }

  @override
  void initialize() {
    currentFuel = 0.0;
    isFilling = false;
  }

  @override
  Widget buildWidget(BuildContext context, MyGame game, VoidCallback onComplete) {
    return _FuelPuzzleWidget(puzzle: this, game: game, onComplete: onComplete);
  }
}

class _FuelPuzzleWidget extends StatefulWidget {
  final FuelPuzzle puzzle;
  final MyGame game;
  final VoidCallback onComplete;

  const _FuelPuzzleWidget({
    required this.puzzle,
    required this.game,
    required this.onComplete,
  });

  @override
  State<_FuelPuzzleWidget> createState() => _FuelPuzzleWidgetState();
}

class _FuelPuzzleWidgetState extends State<_FuelPuzzleWidget> {
  Timer? _timer;

  void _startFilling() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        widget.puzzle.currentFuel += 1.5;
        if (widget.puzzle.currentFuel > widget.puzzle.fuelCapacity) {
          widget.puzzle.currentFuel = widget.puzzle.fuelCapacity;
          _stopFilling();
        }
      });
      widget.game.audioManager.playEffectSound('actions/swish-7.wav', volume: 0.1);
    });
  }

  void _stopFilling() {
    _timer?.cancel();
    _timer = null;
    _checkWin();
  }

  void _checkWin() {
    final diff = (widget.puzzle.currentFuel - widget.puzzle.targetFuel).abs();
    if (diff < 2.0) {
      widget.game.audioManager.playEffectSound('puzzles/typing.wav');
      widget.onComplete();
    } else if (widget.puzzle.currentFuel >= widget.puzzle.fuelCapacity || widget.puzzle.currentFuel > widget.puzzle.targetFuel + 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('燃料が溢れました！やり直してください。'), backgroundColor: Colors.redAccent),
      );
      setState(() {
        widget.puzzle.initialize();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final availableHeight = constraints.maxHeight;
        
        // 利用可能な高さに基づいて要素のサイズを決定
        final double gaugeHeight = (availableHeight * 0.4).clamp(80, 200);
        final double buttonPadding = isMobile ? 8 : 20;
        final double spacing = (availableHeight * 0.05).clamp(5, 30);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '目標: ${widget.puzzle.targetFuel.toInt()}%',
              style: TextStyle(
                color: Colors.white, 
                fontSize: isMobile ? 12 : 18, 
                fontWeight: FontWeight.bold
              ),
            ),
            SizedBox(height: spacing / 2),
            // 燃料ゲージ
            Container(
              width: 60,
              height: gaugeHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(10),
                color: Colors.black45,
              ),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // 目標ライン
                  Positioned(
                    bottom: gaugeHeight * (widget.puzzle.targetFuel / 100),
                    child: Container(
                      width: 60,
                      height: 2,
                      color: Colors.redAccent,
                    ),
                  ),
                  // 現在の燃料
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
                    width: 60,
                    height: gaugeHeight * (widget.puzzle.currentFuel / 100),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withOpacity(0.8),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing),
            GestureDetector(
              onTapDown: (_) => _startFilling(),
              onTapUp: (_) => _stopFilling(),
              onTapCancel: () => _stopFilling(),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: buttonPadding),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 10, spreadRadius: 2),
                  ],
                ),
                child: Text(
                  'バルブを開く',
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: isMobile ? 12 : 16, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing / 2),
            Text(
              '長押しで注入',
              style: TextStyle(color: Colors.white54, fontSize: isMobile ? 9 : 12),
            ),
          ],
        );
      },
    );
  }
}
