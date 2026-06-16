import 'package:flutter/material.dart';
import '../../main.dart';
import '../window_manager.dart';
import '../../component/player_cargo_terminal.dart';
import '../../system/storage/game_runtime_state.dart';

class CargoTransferWindow extends StatefulWidget {
  final MyGame game;
  final WindowManager windowManager;
  final PlayerCargoTerminal terminal;

  const CargoTransferWindow({
    super.key,
    required this.game,
    required this.windowManager,
    required this.terminal,
  });

  @override
  State<CargoTransferWindow> createState() => _CargoTransferWindowState();
}

class _CargoTransferWindowState extends State<CargoTransferWindow> {
  late int _transferLife;
  late int _transferHistory;
  late int _transferInorganic;

  @override
  void initState() {
    super.initState();
    _transferLife = 0;
    _transferHistory = 0;
    _transferInorganic = 0;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.game.gameRuntimeState;
    final fontSize = widget.windowManager.fontSize;

    return Center(
      child: Container(
        width: widget.windowManager.screenWidth * 0.8,
        height: widget.windowManager.screenHeight * 0.8,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          border: Border.all(color: Colors.cyanAccent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '【カーゴ端末 ─ 資源蓄積】',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: fontSize * 1.2,
                fontWeight: FontWeight.bold,
                fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
              ),
            ),
            const Divider(color: Colors.cyanAccent),
            Expanded(
              child: ListView(
                children: [
                  _buildTransferSlider(
                    label: '生命残滓',
                    current: state.playerLifeCount,
                    value: _transferLife,
                    color: Colors.redAccent,
                    onChanged: (val) => setState(() => _transferLife = val.toInt()),
                  ),
                  _buildTransferSlider(
                    label: '歴史残滓',
                    current: state.playerHistoryCount,
                    value: _transferHistory,
                    color: Colors.blueAccent,
                    onChanged: (val) => setState(() => _transferHistory = val.toInt()),
                  ),
                  _buildTransferSlider(
                    label: '無機残滓',
                    current: state.playerInorganicCount,
                    value: _transferInorganic,
                    color: Colors.grey,
                    onChanged: (val) => setState(() => _transferInorganic = val.toInt()),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.cyanAccent),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  label: '蓄積する',
                  onPressed: (_transferLife + _transferHistory + _transferInorganic > 0)
                      ? _handleTransfer
                      : null,
                ),
                /* _buildActionButton(
                  label: '撃って回復',
                  onPressed: state.totalCargoResidueCount >= 5 ? _handleDischarge : null,
                ), */
                _buildActionButton(
                  label: '母星へ送還',
                  onPressed: !state.isCargoLaunched && state.totalCargoResidueCount > 0
                      ? _handleLaunch
                      : null,
                  color: Colors.orangeAccent,
                ),
                _buildActionButton(
                  label: '閉じる',
                  onPressed: () => widget.windowManager.hideWindow(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferSlider({
    required String label,
    required int current,
    required int value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    final fontSize = widget.windowManager.fontSize;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(color: color, fontSize: fontSize, fontFamily: 'Nosutaru-dotMPlusH-10-Regular'),
              ),
              Text(
                '所持: $current -> 蓄積: $value',
                style: TextStyle(color: Colors.white, fontSize: fontSize * 0.8, fontFamily: 'Nosutaru-dotMPlusH-10-Regular'),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: 0,
            max: current.toDouble(),
            divisions: current > 0 ? current : 1,
            activeColor: color,
            inactiveColor: color.withValues(alpha: 0.3),
            onChanged: current > 0 ? onChanged : null,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback? onPressed,
    Color color = Colors.cyanAccent,
  }) {
    final fontSize = widget.windowManager.fontSize;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: onPressed == null ? 0.3 : 1.0)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize * 0.9,
          fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
          color: onPressed == null ? color.withValues(alpha: 0.3) : color,
        ),
      ),
    );
  }

  void _handleTransfer() {
    final state = widget.game.gameRuntimeState;
    
    // 資源を移動
    if (_transferLife > 0) state.triggerTransferFly(CargoHudFlyKind.life, _transferLife);
    if (_transferHistory > 0) state.triggerTransferFly(CargoHudFlyKind.history, _transferHistory);
    if (_transferInorganic > 0) state.triggerTransferFly(CargoHudFlyKind.inorganic, _transferInorganic);

    state.playerLifeCount -= _transferLife;
    state.playerHistoryCount -= _transferHistory;
    state.playerInorganicCount -= _transferInorganic;
    
    state.cargoLifeCount += _transferLife;
    state.cargoHistoryCount += _transferHistory;
    state.cargoInorganicCount += _transferInorganic;
    
    setState(() {
      _transferLife = 0;
      _transferHistory = 0;
      _transferInorganic = 0;
    });
    
    state.notifyRuntimeChanged();
    state.saveGame();
    
    widget.windowManager.hideWindow();
    widget.game.windowManager.showTweet('資源をカーゴへ蓄積しました');
  }

  void _handleDischarge() {
    final state = widget.game.gameRuntimeState;
    if (state.tryCargoDischarge()) {
      widget.windowManager.hideWindow();
      widget.game.windowManager.showDialog([
        '【カーゴ discharge】',
        'カーゴの一部を意志へ還した。重い熱が胸の奥で脈打つ。',
        '……星は、まだ奪い合いを続けている。',
      ]);
    }
  }

  void _handleLaunch() {
    widget.windowManager.hideWindow();
    widget.terminal.invokeLaunchFromUI();
  }
}
