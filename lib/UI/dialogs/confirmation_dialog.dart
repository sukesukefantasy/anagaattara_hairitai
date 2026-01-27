import 'package:flutter/material.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'はい',
    this.cancelLabel = 'いいえ',
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.brown[800],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Colors.white, width: 2),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
          fontSize: 20,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white70,
          fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
          fontSize: 16,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            cancelLabel,
            style: const TextStyle(
              color: Colors.white60,
              fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            onConfirm();
            Navigator.of(context).pop();
          },
          child: Text(
            confirmLabel,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
            ),
          ),
        ),
      ],
    );
  }
}
