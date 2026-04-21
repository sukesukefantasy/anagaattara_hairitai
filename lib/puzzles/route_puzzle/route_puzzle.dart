import 'dart:math';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../puzzle_base.dart';

class RoutePoint {
  // 0.0 〜 1.0 の相対座標
  final Offset relativePosition;
  int value;
  bool isVisited;
  final bool isStart;
  final bool isGoal;
  bool isGolden;

  RoutePoint({
    required this.relativePosition,
    required this.value,
    this.isVisited = false,
    this.isStart = false,
    this.isGoal = false,
    this.isGolden = false,
  });

  // 実際の描画サイズに基づいた絶対座標を取得
  Offset getAbsolutePosition(Size size) {
    return Offset(
      relativePosition.dx * size.width,
      relativePosition.dy * size.height,
    );
  }
}

class RoutePuzzle extends PuzzleBase {
  late List<RoutePoint> points;
  final int targetFuel = 100;
  int currentFuel = 0;
  List<RoutePoint> path = [];
  Offset? currentRelativeDragPosition;

  RoutePuzzle()
      : super(
          id: 'route_puzzle',
          title: '航路シミュレーション',
          description: 'STARTからGOALまで線を繋ぎ、燃料の合計をピッタリ100に調整してください。',
        ) {
    initialize();
  }

  @override
  void initialize() {
    final random = Random();
    points = [];
    
    // 1. START / GOAL の配置 (相対座標)
    final start = RoutePoint(relativePosition: const Offset(0.08, 0.5), value: 0, isStart: true, isVisited: true);
    final goal = RoutePoint(relativePosition: const Offset(0.92, 0.5), value: 0, isGoal: true);
    
    // 2. 正解ルート（黄金航路）の作成
    int goldenCount = 4 + random.nextInt(3);
    List<int> goldenValues = _generateSumPartition(targetFuel, goldenCount);
    
    List<RoutePoint> goldenPoints = [];
    for (int i = 0; i < goldenCount; i++) {
      goldenPoints.add(RoutePoint(
        relativePosition: _getRandomRelativePosition(random, goldenPoints + [start, goal]),
        value: goldenValues[i],
        isGolden: true,
      ));
    }

    // 3. ダミーポイント（ノイズ）の作成
    int dummyCount = 6;
    for (int i = 0; i < dummyCount; i++) {
      points.add(RoutePoint(
        relativePosition: _getRandomRelativePosition(random, goldenPoints + points + [start, goal]),
        value: (random.nextInt(8) + 1) * 5,
        isGolden: false,
      ));
    }

    points.addAll(goldenPoints);
    points.add(start);
    points.add(goal);

    currentFuel = 0;
    path = [start];
    currentRelativeDragPosition = null;
  }

  Offset _getRandomRelativePosition(Random random, List<RoutePoint> existing) {
    Offset pos;
    bool tooClose;
    do {
      tooClose = false;
      // 操作エリアを広げるために Y 方向の範囲を広げる (0.05 〜 0.95)
      pos = Offset(0.15 + random.nextDouble() * 0.7, 0.05 + random.nextDouble() * 0.9);
      for (var p in existing) {
        if ((p.relativePosition - pos).distance < 0.12) { // 相対距離で判定
          tooClose = true;
          break;
        }
      }
    } while (tooClose);
    return pos;
  }

  List<int> _generateSumPartition(int target, int count) {
    final random = Random();
    List<int> result = List.filled(count, 5);
    int currentSum = 5 * count;
    while (currentSum < target) {
      result[random.nextInt(count)] += 5;
      currentSum += 5;
    }
    return result;
  }

  @override
  Widget buildWidget(BuildContext context, MyGame game, VoidCallback onComplete) {
    return _RoutePuzzleWidget(puzzle: this, game: game, onComplete: onComplete);
  }
}

class _RoutePuzzleWidget extends StatefulWidget {
  final RoutePuzzle puzzle;
  final MyGame game;
  final VoidCallback onComplete;

  const _RoutePuzzleWidget({
    required this.puzzle,
    required this.game,
    required this.onComplete,
  });

  @override
  State<_RoutePuzzleWidget> createState() => _RoutePuzzleWidgetState();
}

class _RoutePuzzleWidgetState extends State<_RoutePuzzleWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: 4), // ヘッダーとの間隔を詰める
        Expanded(
          flex: 15, // 操作エリアの重みを増やす
          child: LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
              return MouseRegion(
                cursor: SystemMouseCursors.precise,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) => _handleDrag(details.localPosition, canvasSize),
                  onPanUpdate: (details) => _handleDrag(details.localPosition, canvasSize),
                  onPanEnd: (details) {
                    setState(() {
                      widget.puzzle.currentRelativeDragPosition = null;
                      _checkWin();
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                    ),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _RoutePainter(puzzle: widget.puzzle, canvasSize: canvasSize),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        _buildFooter(),
      ],
    );
  }

  Widget _buildHeader() {
    final diff = widget.puzzle.targetFuel - widget.puzzle.currentFuel;
    Color statusColor = diff == 0 ? Colors.greenAccent : (diff < 0 ? Colors.redAccent : Colors.orangeAccent);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildInfoChip('目標: ${widget.puzzle.targetFuel}', Colors.white),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_right, color: Colors.white24, size: 16),
          ),
          _buildInfoChip('現在: ${widget.puzzle.currentFuel}', statusColor),
          const SizedBox(width: 8),
          if (diff > 0) Text('不足: $diff', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          if (diff < 0) Text('超過: ${diff.abs()}', style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('ドラッグで航路を描く', style: TextStyle(color: Colors.white38, fontSize: 9)),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => setState(() => widget.puzzle.initialize()),
          icon: const Icon(Icons.refresh, size: 12),
          label: const Text('再計算', style: TextStyle(fontSize: 10)),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
        ),
      ],
    );
  }

  void _handleDrag(Offset localPos, Size canvasSize) {
    setState(() {
      widget.puzzle.currentRelativeDragPosition = Offset(
        localPos.dx / canvasSize.width,
        localPos.dy / canvasSize.height,
      );
      
      for (var point in widget.puzzle.points) {
        if (!point.isVisited) {
          Offset absPos = point.getAbsolutePosition(canvasSize);
          double dist = (localPos - absPos).distance;
          
          double hitDist = (canvasSize.shortestSide * 0.1).clamp(25.0, 50.0);
          
          if (dist < hitDist) {
            Offset lastAbsPos = widget.puzzle.path.last.getAbsolutePosition(canvasSize);
            double distFromLast = (lastAbsPos - absPos).distance;
            
            if (distFromLast < canvasSize.width * 0.7) {
              point.isVisited = true;
              widget.puzzle.path.add(point);
              widget.puzzle.currentFuel += point.value;
              widget.game.audioManager.playEffectSound('hits/Hit1.wav', volume: 0.3);
            }
          }
        }
      }
    });
  }

  void _checkWin() {
    if (widget.puzzle.path.last.isGoal) {
      if (widget.puzzle.currentFuel == widget.puzzle.targetFuel) {
        widget.game.audioManager.playEffectSound('puzzles/typing.wav');
        widget.onComplete();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('燃料が合いません！ (現在: ${widget.puzzle.currentFuel})'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 1),
          ),
        );
        setState(() {
          widget.puzzle.initialize();
        });
      }
    }
  }
}

class _RoutePainter extends CustomPainter {
  final RoutePuzzle puzzle;
  final Size canvasSize;
  _RoutePainter({required this.puzzle, required this.canvasSize});

  @override
  void paint(Canvas canvas, Size size) {
    final activeLinePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final dragLinePaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // 1. 軌跡の描画
    for (int i = 0; i < puzzle.path.length - 1; i++) {
      canvas.drawLine(
        puzzle.path[i].getAbsolutePosition(size), 
        puzzle.path[i+1].getAbsolutePosition(size), 
        activeLinePaint
      );
    }

    // 2. ドラッグ中の線
    if (puzzle.currentRelativeDragPosition != null && puzzle.path.isNotEmpty) {
      Offset currentAbsDrag = Offset(
        puzzle.currentRelativeDragPosition!.dx * size.width,
        puzzle.currentRelativeDragPosition!.dy * size.height,
      );
      canvas.drawLine(puzzle.path.last.getAbsolutePosition(size), currentAbsDrag, dragLinePaint);
    }

    // 3. ポイントの描画
    for (var point in puzzle.points) {
      _drawPoint(canvas, point, size);
    }
  }

  void _drawPoint(Canvas canvas, RoutePoint point, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final absPos = point.getAbsolutePosition(size);
    
    if (point.isStart) {
      paint.color = Colors.greenAccent;
    } else if (point.isGoal) {
      paint.color = Colors.redAccent;
    } else {
      paint.color = point.isVisited ? Colors.cyanAccent : Colors.white.withOpacity(0.4);
    }

    // 外枠
    if (point.isVisited) {
      canvas.drawCircle(absPos, 15, Paint()..color = paint.color.withOpacity(0.2)..style = PaintingStyle.fill);
    }
    
    canvas.drawCircle(absPos, point.isVisited ? 8 : 6, paint);

    // 数値ラベル
    if (!point.isStart && !point.isGoal) {
      _drawText(canvas, '${point.value}', absPos + const Offset(-12, -32), 18, FontWeight.bold, Colors.white);
    } else {
      _drawText(canvas, point.isStart ? 'START' : 'GOAL', absPos + const Offset(-18, 15), 9, FontWeight.normal, Colors.white70);
    }
  }

  void _drawText(Canvas canvas, String text, Offset pos, double size, FontWeight weight, Color color) {
    final tp = TextPainter(
      text: TextSpan(style: TextStyle(color: color, fontSize: size, fontWeight: weight), text: text),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
