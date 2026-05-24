import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../window_manager.dart';

class LoadingWindow extends StatelessWidget {
  final WindowManager windowManager;
  final String message;
  final ValueListenable<String>? statusMessage;

  const LoadingWindow({
    super.key,
    required this.windowManager,
    this.message = 'LOADING...',
    this.statusMessage,
  });

  @override
  Widget build(BuildContext context) {
    final status = statusMessage;
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
              if (status != null) ...[
                const SizedBox(height: 12),
                ValueListenableBuilder<String>(
                  valueListenable: status,
                  builder: (context, value, _) {
                    return Text(
                      value,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                      ),
                    );
                  },
                ),
              ] else ...[
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
            ],
          ),
        ),
      ),
    );
  }
}
