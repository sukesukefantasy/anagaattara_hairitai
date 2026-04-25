import 'dart:async';
import 'package:flutter/material.dart';

class MessageWindow extends StatefulWidget {
  final List<String> messages;
  final double fontSize;
  final VoidCallback? onFinish;
  final List<String>? options;
  final Function(int)? onSelect;

  const MessageWindow({
    super.key,
    required this.messages,
    required this.fontSize,
    this.onFinish,
    this.options,
    this.onSelect,
  });

  @override
  State<MessageWindow> createState() => _MessageWindowState();
}

class _MessageWindowState extends State<MessageWindow> {
  int _currentMessageIndex = 0;
  String _displayingText = "";
  bool _showOptions = false;
  bool _isTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }

  void _startTyping() {
    _typingTimer?.cancel();
    _displayingText = "";
    _isTyping = true;
    _showOptions = false;

    // 日本語の改行を助けるために、各文字の間にゼロ幅スペースを挿入
    final fullText = widget.messages[_currentMessageIndex].split('').join('\u{200B}');
    int charIndex = 0;

    _typingTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (charIndex < fullText.length) {
        setState(() {
          _displayingText += fullText[charIndex];
          charIndex++;
          // 次の文字がゼロ幅スペースなら、それも同時に追加して表示リズムを一定にする
          if (charIndex < fullText.length && fullText[charIndex] == '\u{200B}') {
            _displayingText += fullText[charIndex];
            charIndex++;
          }
        });
      } else {
        setState(() {
          _isTyping = false;
          if (_currentMessageIndex == widget.messages.length - 1 && 
              widget.options != null && widget.options!.isNotEmpty) {
            _showOptions = true;
          }
        });
        timer.cancel();
      }
    });
  }

  void _skipTyping() {
    _typingTimer?.cancel();
    setState(() {
      _displayingText = widget.messages[_currentMessageIndex].split('').join('\u{200B}');
      _isTyping = false;
      if (_currentMessageIndex == widget.messages.length - 1 && 
          widget.options != null && widget.options!.isNotEmpty) {
        _showOptions = true;
      }
    });
  }

  void nextMessage() {
    if (_isTyping) {
      _skipTyping();
      return;
    }
    if (_showOptions) return;

    if (_currentMessageIndex < widget.messages.length - 1) {
      setState(() {
        _currentMessageIndex++;
        _startTyping();
      });
    } else {
      widget.onFinish?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600 || screenHeight < 500;

    final double horizontalMargin = screenWidth * 0.05;
    final double boxHeight = screenHeight * (isMobile ? 0.45 : 0.22);
    final double bottomPadding = screenHeight * 0.03;

    return GestureDetector(
      onTap: nextMessage,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: Stack(
          children: [
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
                      _buildOptions(isMobile),
                    Container(
                      width: double.infinity,
                      height: boxHeight,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.85),
                        border: Border.all(color: Colors.white70, width: 2.0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _displayingText,
                          softWrap: true,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.fontSize,
                            fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                            height: 1.5,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
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

  Widget _buildOptions(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap( // 選択肢が多い場合も改行されるように
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: widget.options!.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          return ElevatedButton(
            onPressed: () {
              widget.onSelect?.call(index);
              widget.onFinish?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent.withOpacity(0.9),
              side: const BorderSide(color: Colors.white, width: 1.5),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : 40,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(
              option,
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.fontSize,
                fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                decoration: TextDecoration.none,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
