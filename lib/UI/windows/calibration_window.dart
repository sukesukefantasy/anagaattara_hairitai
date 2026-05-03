import 'package:flutter/material.dart';
import '../../system/storage/game_runtime_state.dart';
import '../window_manager.dart';

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

class _CalibrationWindowState extends State<CalibrationWindow> {
  @override
  Widget build(BuildContext context) {
    final fontSize = widget.windowManager.fontSize;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: widget.windowManager.screenWidth * 0.7,
          height: widget.windowManager.screenHeight * 0.8,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.blueGrey, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 20),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(fontSize),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildCalibrationSlider(
                      'HP_CALIBRATION',
                      '最大HPボーナスの適用率',
                      widget.state.hpCalibrationScale,
                      (v) => setState(() => widget.state.hpCalibrationScale = v),
                      Colors.redAccent,
                    ),
                    _buildCalibrationSlider(
                      'SPEED_CALIBRATION',
                      '移動速度ボーナスの適用率',
                      widget.state.speedCalibrationScale,
                      (v) => setState(() => widget.state.speedCalibrationScale = v),
                      Colors.blueAccent,
                    ),
                    _buildCalibrationSlider(
                      'POWER_CALIBRATION',
                      '投擲・干渉パワーの適用率',
                      widget.state.powerCalibrationScale,
                      (v) => setState(() => widget.state.powerCalibrationScale = v),
                      Colors.greenAccent,
                    ),
                    _buildCalibrationSlider(
                      'STRESS_CALIBRATION',
                      'ストレス耐性ボーナスの適用率',
                      widget.state.stressCalibrationScale,
                      (v) => setState(() => widget.state.stressCalibrationScale = v),
                      Colors.orangeAccent,
                    ),
                  ],
                ),
              ),
              _buildFooter(fontSize),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double fontSize) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.blueGrey, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.settings_input_component, color: Colors.blueAccent),
          const SizedBox(width: 10),
          Text(
            'CORE_CALIBRATION_TERMINAL',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize * 1.2,
              fontFamily: 'TRS-Million-Rg',
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
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                '${(value * 100).toInt()}%',
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              ),
            ],
          ),
          Text(
            desc,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.2),
              thumbColor: color,
              overlayColor: color.withOpacity(0.1),
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

  Widget _buildFooter(double fontSize) {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent.withOpacity(0.3),
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.blueAccent),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        ),
        onPressed: () {
          widget.state.saveGame();
          widget.windowManager.hideWindow();
        },
        child: const Text('CALIBRATION_COMPLETE'),
      ),
    );
  }
}
