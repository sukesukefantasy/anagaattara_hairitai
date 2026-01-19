import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';

class MessageWindow extends StatefulWidget {
  final List<String> messages;
  final VoidCallback? onFinish;

  const MessageWindow({super.key, required this.messages, this.onFinish});

  @override
  State<MessageWindow> createState() => _MessageWindowState();
}

class _MessageWindowState extends State<MessageWindow> {
  int _currentMessageIndex = 0;
  late TextScrollGame _currentGame;

  @override
  void initState() {
    super.initState();
    _currentGame = TextScrollGame(widget.messages[_currentMessageIndex]);
  }

  void nextMessage() {
    setState(() {
      if (_currentMessageIndex < widget.messages.length - 1) {
        _currentMessageIndex++;
        // メッセージを更新した新しいゲームインスタンスを作成
        _currentGame = TextScrollGame(widget.messages[_currentMessageIndex]);
      } else {
        widget.onFinish?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // レイアウト用の計算
    final double horizontalMargin = screenWidth * 0.05; // 左右5%
    final double lineHeight = 20.0;
    final double boxHeight = lineHeight * 3 + 20; // 3行分
    final double bottomPadding = screenHeight * 0.02; // 下から2%

    // PositionedではなくAlignを使うことで、親がStackでなくても動作するようにします
    return GestureDetector(
      onTap: nextMessage,
      behavior: HitTestBehavior.translucent, // 透明な部分もタップを検知する
      child: SizedBox.expand(
        // GestureDetectorを画面全体に広げる
        child: Stack(
          children: [
            // メッセージボックス自体はAlignで配置
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  left: horizontalMargin,
                  right: horizontalMargin,
                  bottom: bottomPadding,
                ),
                child: Container(
                  width: double.infinity,
                  height: boxHeight,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    border: Border.all(color: Colors.grey, width: 2.0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: GameWidget(game: _currentGame),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TextScrollGame extends FlameGame {
  final String text;
  TextScrollGame(this.text);

  @override
  Future<void> onLoad() async {
    final textStyle = const TextStyle(
      fontSize: 16.0,
      color: Colors.white,
      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
      decoration: TextDecoration.none,
    );

    add(
      ScrollTextBoxComponent(
        text: text,
        // position と size はコンテナの大きさに合わせる
        size: size,
        textRenderer: TextPaint(
          style: textStyle,
        ),
        boxConfig: TextBoxConfig(
          timePerChar: 0.03, // 1文字ずつの表示速度
          margins: const EdgeInsets.all(10),
        ),
      ),
    );
  }
}
