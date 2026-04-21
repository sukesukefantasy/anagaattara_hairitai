import 'dart:math';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../puzzle_base.dart';

enum PipeType { straight, lShape, battery, engine }

class BypassPuzzleTile {
  PipeType type;
  int rotation; // 0: 0, 1: 90, 2: 180, 3: 270
  final bool isFixed;

  BypassPuzzleTile({
    required this.type,
    this.rotation = 0,
    this.isFixed = false,
  });

  void rotate() {
    if (isFixed) return;
    rotation = (rotation + 1) % 4;
  }

  /// このタイルが持つ接続端子の方向を返す (0:上, 1:右, 2:下, 3:左)
  List<int> getConnections() {
    switch (type) {
      case PipeType.straight:
        return rotation % 2 == 0 ? [0, 2] : [1, 3];
      case PipeType.lShape:
        return [rotation, (rotation + 1) % 4];
      case PipeType.battery:
        return [1, 2]; // 右と下に接続口
      case PipeType.engine:
        return [0, 3]; // 上と左に接続口
    }
  }
}

class BypassPuzzle extends PuzzleBase {
  late List<List<BypassPuzzleTile>> grid;
  final int rows = 4;
  final int cols = 4;
  Set<Point<int>> poweredTiles = {};

  BypassPuzzle()
      : super(
          id: 'bypass_puzzle',
          title: '回路のバイパスパズル',
          description: 'パネルをタップして回転させ、左上のバッテリーから右下のエンジンまで回路を繋いでください。',
        ) {
    initialize();
  }

  @override
  void initialize() {
    grid = List.generate(
      rows,
      (r) => List.generate(
        cols,
        (c) => BypassPuzzleTile(type: PipeType.straight, rotation: 0),
      ),
    );

    List<Point<int>> path = _generateValidPath();
    _placeTilesAlongPath(path);

    final random = Random();
    Set<Point<int>> pathSet = path.toSet();
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!pathSet.contains(Point(c, r))) {
          grid[r][c] = BypassPuzzleTile(
            type: random.nextBool() ? PipeType.straight : PipeType.lShape,
            rotation: random.nextInt(4),
          );
        }
      }
    }

    grid[0][0] = BypassPuzzleTile(type: PipeType.battery, isFixed: true);
    grid[rows - 1][cols - 1] = BypassPuzzleTile(type: PipeType.engine, isFixed: true);

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!grid[r][c].isFixed) {
          grid[r][c].rotation = random.nextInt(4);
        }
      }
    }
    
    updatePoweredTiles();
  }

  List<Point<int>> _generateValidPath() {
    final random = Random();
    List<Point<int>> path = [const Point(0, 0)];
    Point<int> current = const Point(0, 0);
    Set<Point<int>> visited = {current};

    while (current != Point(cols - 1, rows - 1)) {
      List<Point<int>> neighbors = [];
      if (current.x + 1 < cols) neighbors.add(Point(current.x + 1, current.y));
      if (current.y + 1 < rows) neighbors.add(Point(current.x, current.y + 1));
      if (current.y - 1 >= 0) neighbors.add(Point(current.x, current.y - 1));
      if (current.x - 1 >= 0) neighbors.add(Point(current.x - 1, current.y));

      neighbors.removeWhere((p) => visited.contains(p));

      if (neighbors.isEmpty) {
        return _generateValidPath();
      }

      neighbors.sort((a, b) {
        int distA = (cols - 1 - a.x).abs() + (rows - 1 - a.y).abs();
        int distB = (cols - 1 - b.x).abs() + (rows - 1 - b.y).abs();
        return distA.compareTo(distB);
      });

      int poolSize = min(2, neighbors.length);
      current = neighbors[random.nextInt(poolSize)];
      path.add(current);
      visited.add(current);
    }
    return path;
  }

  void _placeTilesAlongPath(List<Point<int>> path) {
    for (int i = 1; i < path.length - 1; i++) {
      Point<int> prev = path[i - 1];
      Point<int> curr = path[i];
      Point<int> next = path[i + 1];

      int inDir = _getDirection(curr, prev);
      int outDir = _getDirection(curr, next);

      if ((inDir % 2) == (outDir % 2)) {
        grid[curr.y][curr.x] = BypassPuzzleTile(
          type: PipeType.straight,
          rotation: inDir % 2 == 0 ? 0 : 1,
        );
      } else {
        int rot = 0;
        List<int> dirs = [inDir, outDir]..sort();
        if (dirs[0] == 0 && dirs[1] == 1) rot = 0;
        else if (dirs[0] == 1 && dirs[1] == 2) rot = 1;
        else if (dirs[0] == 2 && dirs[1] == 3) rot = 2;
        else if (dirs[0] == 0 && dirs[1] == 3) rot = 3;

        grid[curr.y][curr.x] = BypassPuzzleTile(
          type: PipeType.lShape,
          rotation: rot,
        );
      }
    }
  }

  int _getDirection(Point<int> from, Point<int> to) {
    if (to.y < from.y) return 0;
    if (to.x > from.x) return 1;
    if (to.y > from.y) return 2;
    if (to.x < from.x) return 3;
    return 0;
  }

  void updatePoweredTiles() {
    poweredTiles.clear();
    _tracePower(0, 0);
  }

  void _tracePower(int r, int c) {
    poweredTiles.add(Point(c, r));
    final currentConnections = grid[r][c].getConnections();
    final dr = [-1, 0, 1, 0];
    final dc = [0, 1, 0, -1];
    final opposite = [2, 3, 0, 1];

    for (int dir in currentConnections) {
      int nr = r + dr[dir];
      int nc = c + dc[dir];

      if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !poweredTiles.contains(Point(nc, nr))) {
        final neighborConnections = grid[nr][nc].getConnections();
        if (neighborConnections.contains(opposite[dir])) {
          _tracePower(nr, nc);
        }
      }
    }
  }

  bool checkSolved() {
    updatePoweredTiles();
    return poweredTiles.contains(Point(cols - 1, rows - 1));
  }

  @override
  Widget buildWidget(BuildContext context, MyGame game, VoidCallback onComplete) {
    return _BypassPuzzleWidget(
      puzzle: this,
      game: game,
      onComplete: onComplete,
    );
  }
}

class _BypassPuzzleWidget extends StatefulWidget {
  final BypassPuzzle puzzle;
  final MyGame game;
  final VoidCallback onComplete;

  const _BypassPuzzleWidget({
    required this.puzzle,
    required this.game,
    required this.onComplete,
  });

  @override
  State<_BypassPuzzleWidget> createState() => _BypassPuzzleWidgetState();
}

class _BypassPuzzleWidgetState extends State<_BypassPuzzleWidget> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // 画面の短い方に合わせつつ、親の制約を尊重
      final availableWidth = constraints.maxWidth;
      final availableHeight = constraints.maxHeight;
      final size = min(availableWidth, availableHeight) * 0.95;

      return Center(
        child: SizedBox(
          width: size,
          height: size,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.puzzle.cols,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: widget.puzzle.rows * widget.puzzle.cols,
            itemBuilder: (context, index) {
              final r = index ~/ widget.puzzle.cols;
              final c = index % widget.puzzle.cols;
              final tile = widget.puzzle.grid[r][c];
              final isPowered = widget.puzzle.poweredTiles.contains(Point(c, r));

              return MouseRegion(
                cursor: tile.isFixed ? SystemMouseCursors.basic : SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      tile.rotate();
                      if (widget.puzzle.checkSolved()) {
                        _handleComplete();
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isPowered ? Colors.yellow.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                      border: Border.all(
                        color: isPowered ? Colors.yellowAccent : (tile.isFixed ? Colors.blueAccent : Colors.white24),
                        width: (isPowered || tile.isFixed) ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: LayoutBuilder(builder: (context, tileConstraints) {
                            final tileSize = tileConstraints.maxWidth;
                            return Transform.rotate(
                              angle: tile.rotation * pi / 2,
                              child: _buildPipeIcon(tile.type, isPowered, tileSize),
                            );
                          }),
                        ),
                        if (tile.isFixed)
                          Positioned(
                            top: 2,
                            left: 2,
                            child: Icon(Icons.lock, size: size * 0.03, color: isPowered ? Colors.yellowAccent : Colors.blueAccent),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }

  void _handleComplete() {
    widget.game.audioManager.playEffectSound('puzzles/charge.wav');
    Future.delayed(const Duration(milliseconds: 300), () {
      widget.onComplete();
    });
  }

  Widget _buildPipeIcon(PipeType type, bool isPowered, double tileSize) {
    final color = isPowered ? Colors.yellowAccent : Colors.grey;
    final pipeWidth = tileSize * 0.15;

    switch (type) {
      case PipeType.straight:
        return Container(
          width: pipeWidth,
          height: tileSize * 0.8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(pipeWidth / 2),
            boxShadow: isPowered ? [BoxShadow(color: Colors.yellowAccent.withOpacity(0.5), blurRadius: 8)] : null,
          ),
        );
      case PipeType.lShape:
        return SizedBox(
          width: tileSize * 0.8,
          height: tileSize * 0.8,
          child: CustomPaint(
            painter: _LPipePainter(color: color, shadow: isPowered, strokeWidth: pipeWidth),
          ),
        );
      case PipeType.battery:
        return Icon(Icons.bolt, color: isPowered ? Colors.yellowAccent : Colors.greenAccent, size: tileSize * 0.6);
      case PipeType.engine:
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.settings, color: isPowered ? Colors.yellowAccent : Colors.orangeAccent, size: tileSize * 0.6),
            Positioned(
              left: 0,
              child: Container(width: 4, height: pipeWidth, color: (isPowered ? Colors.yellowAccent : Colors.orangeAccent).withOpacity(0.5)),
            ),
            Positioned(
              top: 0,
              child: Container(width: pipeWidth, height: 4, color: (isPowered ? Colors.yellowAccent : Colors.orangeAccent).withOpacity(0.5)),
            ),
          ],
        );
    }
  }
}

class _LPipePainter extends CustomPainter {
  final Color color;
  final bool shadow;
  final double strokeWidth;
  _LPipePainter({required this.color, required this.shadow, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.quadraticBezierTo(size.width / 2, size.height / 2, size.width, size.height / 2);

    if (shadow) {
      final shadowPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..strokeWidth = strokeWidth * 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path, shadowPaint);
    }
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
