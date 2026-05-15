import 'package:flutter/material.dart';
import '../../system/storage/game_runtime_state.dart';
import '../window_manager.dart';
import 'window_base.dart';

class CalibrationWindow extends StatefulWidget {
  final WindowManager windowManager;
  final GameRuntimeState state;

  const CalibrationWindow({
    super.key,
    required this.windowManager,
    required this.state,
  });

  @override
  State<CalibrationWindow> createState() => _CalibrationWindowState();
}

class _CalibrationWindowState extends State<CalibrationWindow> with GameWindowResponsiveMixin {
  @override
  Widget build(BuildContext context) {
    final isMobile = getIsMobile(widget.windowManager);
    final fontSize = widget.windowManager.fontSize;

    return GameWindow(
      windowManager: widget.windowManager,
      backgroundColor: Colors.black.withOpacity(0.9),
      widthFactor: 0.7,
      heightFactor: 0.8,
      mobileWidthFactor: 0.9,
      mobileHeightFactor: 0.9,
      child: Column(
        children: [
          _buildHeader(fontSize, isMobile),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              children: [
                _buildCalibrationSlider(
                  'HP_CALIBRATION',
                  '最大HPボーナスの適用率',
                  widget.state.hpCalibrationScale,
                  (v) => setState(() => widget.state.hpCalibrationScale = v),
                  Colors.redAccent,
                  isMobile,
                ),
                _buildCalibrationSlider(
                  'SPEED_CALIBRATION',
                  '移動速度ボーナスの適用率',
                  widget.state.speedCalibrationScale,
                  (v) => setState(() => widget.state.speedCalibrationScale = v),
                  Colors.blueAccent,
                  isMobile,
                ),
                _buildCalibrationSlider(
                  'POWER_CALIBRATION',
                  '投擲・干渉パワーの適用率',
                  widget.state.powerCalibrationScale,
                  (v) => setState(() => widget.state.powerCalibrationScale = v),
                  Colors.greenAccent,
                  isMobile,
                ),
                _buildCalibrationSlider(
                  'STRESS_CALIBRATION',
                  'ストレス耐性ボーナスの適用率',
                  widget.state.stressCalibrationScale,
                  (v) => setState(() => widget.state.stressCalibrationScale = v),
                  Colors.orangeAccent,
                  isMobile,
                ),
              ],
            ),
          ),
          _buildFooter(fontSize, isMobile),
        ],
      ),
    );
  }

  Widget _buildHeader(double fontSize, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.blueGrey, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings_input_component, color: Colors.blueAccent, size: isMobile ? 20 : 24),
          const SizedBox(width: 10),
          Text(
            'CORE_CALIBRATION_TERMINAL',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 14 : fontSize * 1.2,
              fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationSlider(
    String label,
    String desc,
    double value,
    ValueChanged<double> onChanged,
    Color color,
    bool isMobile,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 15 : 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 14),
              ),
              Text(
                '${(value * 100).toInt()}%',
                style: TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: isMobile ? 12 : 14),
              ),
            ],
          ),
          Text(
            desc,
            style: TextStyle(color: Colors.white54, fontSize: isMobile ? 9 : 10),
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.2),
              thumbColor: color,
              overlayColor: color.withOpacity(0.1),
              trackHeight: isMobile ? 2 : 4,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: isMobile ? 6 : 10),
            ),
            child: Slider(
              value: value,
              onChanged: onChanged,
              min: 0.0,
              max: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(double fontSize, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 10 : 15),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent.withOpacity(0.3),
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.blueAccent),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: isMobile ? 10 : 15),
        ),
        onPressed: () {
          widget.state.saveGame();
          widget.windowManager.hideWindow();
        },
        child: Text(
          'CALIBRATION_COMPLETE',
          style: TextStyle(fontSize: isMobile ? 12 : 14),
        ),
      ),
    );
  }
}
