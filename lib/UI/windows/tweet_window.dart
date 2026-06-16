import 'dart:async';
import 'package:flutter/material.dart';

class TweetWindow extends StatefulWidget {
  final String message;
  final double fontSize;
  final Color? textColor;
  final Color? backgroundColor;

  const TweetWindow({
    super.key,
    required this.message,
    required this.fontSize,
    this.textColor,
    this.backgroundColor,
  });

  @override
  State<TweetWindow> createState() => _TweetWindowState();
}

class _TweetWindowState extends State<TweetWindow> {
  String _displayingText = "";
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
    
    // 日本語の改行を助けるために、各文字の間にゼロ幅スペースを挿入
    final fullText = widget.message.split('').join('\u{200B}');
    int charIndex = 0;

    _typingTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (charIndex < fullText.length) {
        if (mounted) {
          setState(() {
            _displayingText += fullText[charIndex];
            charIndex++;
            // 次の文字がゼロ幅スペースなら、それも同時に追加して表示リズムを一定にする
            if (charIndex < fullText.length && fullText[charIndex] == '\u{200B}') {
              _displayingText += fullText[charIndex];
              charIndex++;
            }
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (widget.textColor ?? Colors.white).withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: const BoxConstraints(maxWidth: 200),
        child: Text(
          _displayingText,
          softWrap: true,
          style: TextStyle(
            color: widget.textColor ?? Colors.white,
            fontSize: widget.fontSize,
            fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
            height: 1.4,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
