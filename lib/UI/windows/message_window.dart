import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';

class MessageWindow extends StatefulWidget {
  final List<String> messages;
  final VoidCallback? onFinish;
  final List<String>? options;
  final Function(int)? onSelect;

  const MessageWindow({super.key, required this.messages, this.onFinish, this.options, this.onSelect});

  @override
  State<MessageWindow> createState() => _MessageWindowState();
}

class _MessageWindowState extends State<MessageWindow> {
  int _currentMessageIndex = 0;
  late TextScrollGame _currentGame;
  bool _showOptions = false;

  @override
  void initState() {
    super.initState();
    _currentGame = TextScrollGame(widget.messages[_currentMessageIndex]);
  }

  void nextMessage() {
    if (_showOptions) return; // 選択肢表示中はクリックで次に進ませない

    setState(() {
      if (_currentMessageIndex < widget.messages.length - 1) {
        _currentMessageIndex++;
        // メッセージを更新した新しいゲームインスタンスを作成
        _currentGame = TextScrollGame(widget.messages[_currentMessageIndex]);
      } else {
        if (widget.options != null && widget.options!.isNotEmpty) {
          _showOptions = true;
        } else {
          widget.onFinish?.call();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // レイアウト用の計算
    final isMobile = screenWidth < 600;
    final double horizontalMargin = screenWidth * 0.05; // 左右5%
    final double boxHeight = screenHeight * (isMobile ? 0.25 : 0.15); // スマホなら25%、PCなら15%
    final double bottomPadding = screenHeight * 0.05; // 下から5%

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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_showOptions)
                      _buildOptions(horizontalMargin, isMobile),
                    Container(
                      width: double.infinity,
                      height: boxHeight,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        border: Border.all(color: Colors.grey, width: 2.0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: GameWidget(game: _currentGame),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptions(double horizontalMargin, bool isMobile) {
    if (widget.options == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: widget.options!.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ElevatedButton(
              onPressed: () {
                widget.onSelect?.call(index);
                widget.onFinish?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent.withOpacity(0.8),
                side: const BorderSide(color: Colors.white, width: 1),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 40,
                  vertical: 10,
                ),
              ),
              child: Text(
                option,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class TextScrollGame extends FlameGame {
  final String text;
  TextScrollGame(this.text);

  @override
  Future<void> onLoad() async {
    // 日本語の改行を助けるために、すべての文字の間にゼロ幅スペース(Zero Width Space)を挿入するハック
    // これにより、単語の区切りがない日本語でも枠内で適切に改行されるようになります。
    final processedText = text.split('').join('\u{200B}');
    
    final textStyle = TextStyle(
      fontSize: (size.y * 0.15).clamp(12.0, 20.0), // フォントサイズを少し抑える (4〜5行入るように)
      color: Colors.white,
      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
      decoration: TextDecoration.none,
      height: 1.5, // 行間を広げる
    );

    add(
      ScrollTextBoxComponent(
        text: processedText,
        // position と size はコンテナの大きさに合わせる
        size: size,
        textRenderer: TextPaint(
          style: textStyle,
        ),
        boxConfig: TextBoxConfig(
          timePerChar: 0.03, // 1文字ずつの表示速度
          margins: const EdgeInsets.all(12),
          maxWidth: size.x - 24, // 左右のマージン分を引く
        ),
      ),
    );
  }
}
