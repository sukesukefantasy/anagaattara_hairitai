import 'package:flutter/material.dart';
import '../window_manager.dart';

class LoadingWindow extends StatelessWidget {
  final WindowManager windowManager;
  final String message;

  const LoadingWindow({
    super.key,
    required this.windowManager,
    this.message = 'LOADING...',
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SizedBox.expand(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'INITIALIZING SYSTEM',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
