import 'dart:math';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../system/storage/game_runtime_state.dart';
import '../puzzle_base.dart';

class ManifoldPiece {
  final String id;
  final String name;
  final IconData? icon;
  final String? spritePath;
  final Color color;
  double rotation; // 0, 90, 180, 270
  final double targetRotation;
  
  // 0.0 〜 1.0 の相対座標
  Offset relativePos;
  final Offset targetRelativePos;
  bool isSnapped;

  ManifoldPiece({
    required this.id,
    required this.name,
    this.icon,
    this.spritePath,
    required this.color,
    required this.targetRelativePos,
    required this.targetRotation,
    this.rotation = 0,
    this.relativePos = Offset.zero,
    this.isSnapped = false,
  });

  Offset getAbsolutePos(Size size) => Offset(relativePos.dx * size.width, relativePos.dy * size.height);
  Offset getTargetAbsolutePos(Size size) => Offset(targetRelativePos.dx * size.width, targetRelativePos.dy * size.height);
}

class ManifoldPuzzle extends PuzzleBase {
  late List<ManifoldPiece> pieces;
  final String? activeAttribute;

  ManifoldPuzzle({this.activeAttribute})
      : super(
          id: 'manifold_puzzle',
          title: 'エンジン・マニホールドの構築',
          description: '各パーツをタップして回転させ、正しい向きで動力部のソケットに差し込んでください。',
        ) {
    initialize();
  }

  @override
  void initialize() {
    final random = Random();
    pieces = [
      ManifoldPiece(
        id: 'valve',
        name: '圧力バルブ',
        icon: Icons.settings_input_component,
        color: Colors.blueAccent,
        targetRelativePos: const Offset(0.2, 0.25),
        targetRotation: 0,
      ),
      ManifoldPiece(
        id: 'igniter',
        name: '点火装置',
        icon: Icons.battery_charging_full_rounded,
        color: Colors.orangeAccent,
        targetRelativePos: const Offset(0.2, 0.5),
        targetRotation: 0,
      ),
      ManifoldPiece(
        id: 'nozzle',
        name: '噴射ノズル',
        icon: Icons.balcony_rounded,
        color: Colors.redAccent,
        targetRelativePos: const Offset(0.2, 0.75),
        targetRotation: 0,
      ),
    ];

    // 現在のシーンのコレクションアイテムを追加
    final state = GameRuntimeState();
    final stageId = state.currentOutdoorSceneId ?? 'outdoor_1';
    
    // アイテム名とスプライトの対応 (ItemFactoryの定義に合わせる)
    final Map<String, Map<String, String>> routeItems = {
      'outdoor_1': {'name': '希少な鉱石', 'sprite': 'stone.png'},
      'outdoor_2': {'name': '生体サンプル', 'sprite': 'heart.png'},
      'outdoor_3': {'name': '高出力電源', 'sprite': 'energy_cube.png'},
      'outdoor_4': {'name': '記録アーカイブ', 'sprite': 'warm_memory.png'},
      'outdoor_philosophy': {'name': '中枢演算コア', 'sprite': 'player_icon.png'},
      'outdoor_despair': {'name': '最終調査報告書', 'sprite': 'doodle_book.png'},
      'outdoor_true': {'name': '中枢演算コア', 'sprite': 'ai_icon.png'},
    };

    // Stage 6 の特殊アイテム取得
    if (stageId == 'outdoor_despair') {
      final attr = activeAttribute ?? GameRuntimeState.routeNormal;
      switch (attr) {
        case GameRuntimeState.routeViolence: routeItems['outdoor_despair'] = {'name': '殲滅完了コード', 'sprite': 'forbidden_data.png'}; break;
        case GameRuntimeState.routeEmpathy: routeItems['outdoor_despair'] = {'name': '心のバックアップ', 'sprite': 'warm_memory.png'}; break;
        case GameRuntimeState.routePhilosophy: routeItems['outdoor_despair'] = {'name': '真実へのアクセスキー', 'sprite': 'ai_icon.png'}; break;
        case GameRuntimeState.routeEfficiency: routeItems['outdoor_despair'] = {'name': '最適化完了ログ', 'sprite': 'energy_cube.png'}; break;
      }
    }

    var targetItem = routeItems[stageId];

    if (targetItem != null) {
      pieces.add(ManifoldPiece(
        id: 'collection_item',
        name: targetItem['name']!,
        spritePath: targetItem['sprite']!,
        icon: Icons.shopping_bag, // スプライトがない場合のフォールバック
        color: Colors.purpleAccent,
        targetRelativePos: const Offset(0.4, 0.5), // バッグの位置
        targetRotation: 0,
      ));
    }

    for (var piece in pieces) {
      piece.relativePos = Offset(0.7 + random.nextDouble() * 0.2, 0.2 + random.nextDouble() * 0.6);
      piece.rotation = (random.nextInt(4) * 90).toDouble();
      piece.isSnapped = false;
    }
  }

  @override
  Widget buildWidget(BuildContext context, MyGame game, VoidCallback onComplete) {
    return _ManifoldPuzzleWidget(puzzle: this, game: game, onComplete: onComplete);
  }
}

class _ManifoldPuzzleWidget extends StatefulWidget {
  final ManifoldPuzzle puzzle;
  final MyGame game;
  final VoidCallback onComplete;

  const _ManifoldPuzzleWidget({
    required this.puzzle,
    required this.game,
    required this.onComplete,
  });

  @override
  State<_ManifoldPuzzleWidget> createState() => _ManifoldPuzzleWidgetState();
}

class _ManifoldPuzzleWidgetState extends State<_ManifoldPuzzleWidget> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      // パーツサイズを従来の約2倍に (0.2 -> 0.4)
      final pieceSize = (size.shortestSide * 0.4).clamp(80.0, 160.0);

      return Stack(
        children: [
          // 設計図エリアの背景
          Positioned(
            left: size.width * 0.02,
            top: size.height * 0.05,
            bottom: size.height * 0.05,
            width: size.width * 0.45,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
              ),
            ),
          ),
          // ソケットをメインのStackに直置きすることで座標系を統一
          ...widget.puzzle.pieces.map((p) => _buildSocket(p, size, pieceSize)).toList(),
          // ドラッグパーツ
          ...widget.puzzle.pieces.map((p) => _buildDraggablePiece(p, size, pieceSize)).toList(),
        ],
      );
    });
  }

  Widget _buildSocket(ManifoldPiece piece, Size canvasSize, double pieceSize) {
    final absPos = piece.getTargetAbsolutePos(canvasSize);
    return Positioned(
      left: absPos.dx - pieceSize / 2,
      top: absPos.dy - pieceSize / 2,
      child: Container(
        width: pieceSize,
        height: pieceSize,
        decoration: BoxDecoration(
          color: piece.isSnapped ? piece.color.withOpacity(0.3) : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: piece.isSnapped ? piece.color : Colors.white10,
            width: 2,
          ),
        ),
        child: Transform.rotate(
          angle: piece.targetRotation * pi / 180,
          child: piece.id == 'collection_item' 
            ? Center(
                child: Opacity(
                  opacity: 0.3,
                  child: Icon(
                    Icons.shopping_bag,
                    color: piece.isSnapped ? piece.color : Colors.white10,
                    size: pieceSize * 0.5,
                  ),
                ),
              )
            : Icon(
                piece.icon,
                color: piece.isSnapped ? piece.color : Colors.white10,
                size: pieceSize * 0.5,
              ),
        ),
      ),
    );
  }

  Widget _buildDraggablePiece(ManifoldPiece piece, Size canvasSize, double pieceSize) {
    if (piece.isSnapped) return Container();

    final absPos = piece.getAbsolutePos(canvasSize);

    return Positioned(
      left: absPos.dx - pieceSize / 2,
      top: absPos.dy - pieceSize / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            piece.rotation = (piece.rotation + 90) % 360;
            widget.game.audioManager.playEffectSound('hits/Hit3.wav', volume: 0.3);
          });
        },
        onPanUpdate: (details) {
          setState(() {
            piece.relativePos += Offset(
              details.delta.dx / canvasSize.width,
              details.delta.dy / canvasSize.height,
            );
          });
        },
        onPanEnd: (details) {
          _checkSnap(piece, canvasSize);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          child: Transform.rotate(
            angle: piece.rotation * pi / 180,
            child: Container(
              width: pieceSize,
              height: pieceSize,
              decoration: BoxDecoration(
                color: piece.color.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: piece.color.withOpacity(0.4), blurRadius: pieceSize * 0.2),
                ],
              ),
              child: piece.spritePath != null
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset('assets/images/${piece.spritePath}', fit: BoxFit.contain),
                  )
                : Icon(piece.icon, color: Colors.white, size: pieceSize * 0.5),
            ),
          ),
        ),
      ),
    );
  }

  void _checkSnap(ManifoldPiece piece, Size canvasSize) {
    double dist = (piece.getAbsolutePos(canvasSize) - piece.getTargetAbsolutePos(canvasSize)).distance;
    
    // コレクションアイテムは向き不問、それ以外は targetRotation と一致する必要がある
    bool rotationCorrect = piece.id == 'collection_item' || piece.rotation == piece.targetRotation;

    // パーツが大きくなったので、スナップ判定も少し広めに
    if (dist < canvasSize.shortestSide * 0.15) {
      if (rotationCorrect) {
        setState(() {
          piece.isSnapped = true;
          // コレクションアイテムの場合は、スナップ時に正しい向きに補正せず現在の向きを維持しても良いが、
          // 見栄えのために 90度単位の直近の向きに吸着させる
          piece.relativePos = piece.targetRelativePos;
          widget.game.audioManager.playEffectSound('hits/Hit1.wav', volume: 0.6);
        });
        
        if (widget.puzzle.pieces.every((p) => p.isSnapped)) {
          _handleComplete();
        }
      } else {
        setState(() {
          // 向きが違う場合は少し押し戻す
          piece.relativePos += const Offset(0.08, 0);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('パーツの向きが合いません！'), duration: Duration(milliseconds: 500)),
        );
      }
    }
  }

  void _handleComplete() {
    widget.game.audioManager.playEffectSound('puzzles/setup_rocket.ogg');
    Future.delayed(const Duration(milliseconds: 500), () {
      widget.onComplete();
    });
  }
}
