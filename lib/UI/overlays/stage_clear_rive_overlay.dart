import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

import '../../system/rive_audio_helper.dart';
import '../../system/stage_clear_cinematic_controller.dart';

/// stageClear 時に全画面で trainscene.riv を再生するオーバーレイ。
class StageClearRiveOverlay extends StatefulWidget {
  const StageClearRiveOverlay({
    super.key,
    required this.controller,
  });

  final StageClearCinematicController controller;

  @override
  State<StageClearRiveOverlay> createState() => _StageClearRiveOverlayState();
}

class _StageClearRiveOverlayState extends State<StageClearRiveOverlay> {
  File? _file;
  RiveWidgetController? _riveController;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    final cinematic = widget.controller;
    cinematic.stopRivePlayback = _stopRivePlayback;
    cinematic.prepareRivePlayback = _prepareRivePlayback;
    _loadRiveFile();
  }

  /// .riv は一度だけ読み込み。SM は演出ごとに作り直す（2 回目も先頭から）。
  Future<void> _loadRiveFile() async {
    try {
      final file = await File.asset(
        StageClearCinematicController.assetPath,
        riveFactory: Factory.rive,
      );
      if (!mounted) {
        file?.dispose();
        return;
      }
      if (file == null) {
        throw StateError(
          'Rive file not found: ${StageClearCinematicController.assetPath}',
        );
      }
      setState(() => _file = file);
    } catch (e, stack) {
      debugPrint('StageClearRiveOverlay: failed to load Rive file: $e\n$stack');
      _loadFailed = true;
      if (mounted) setState(() {});
    }
  }

  RiveWidgetController _createRiveController() {
    return RiveWidgetController(
      _file!,
      artboardSelector: ArtboardSelector.byName(
        StageClearCinematicController.artboardName,
      ),
      stateMachineSelector: StateMachineSelector.byName(
        StageClearCinematicController.stateMachineName,
      ),
    )..active = true;
  }

  void _disposeRiveController() {
    _riveController?.dispose();
    _riveController = null;
  }

  /// 毎回 SM を初期状態から開始（一方通行アニメ＋ループ音のレイヤーをリセット）。
  void _prepareRivePlayback() {
    if (_loadFailed || _file == null) {
      widget.controller.markRiveFailed();
      return;
    }
    try {
      _disposeRiveController();
      stopAllRivePlaybackAudio();
      _riveController = _createRiveController();
      if (mounted) setState(() {});
      widget.controller.markRiveReady();
    } catch (e, stack) {
      debugPrint('StageClearRiveOverlay: failed to start Rive SM: $e\n$stack');
      widget.controller.markRiveFailed();
    }
  }

  void _stopRivePlayback() {
    _disposeRiveController();
    stopAllRivePlaybackAudio();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.stopRivePlayback = null;
    widget.controller.prepareRivePlayback = null;
    _stopRivePlayback();
    _file?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (!controller.visible) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: controller.skip,
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_riveController != null)
                RiveWidget(
                  controller: _riveController!,
                  fit: Fit.fitHeight,
                )
              else if (_loadFailed)
                const SizedBox.shrink()
              else
                const Center(child: CircularProgressIndicator()),
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(
                    alpha: controller.blackOpacity,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
