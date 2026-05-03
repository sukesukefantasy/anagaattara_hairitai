import 'package:flutter/material.dart';
import '../main.dart';
import '../game_manager/time_service.dart';
import '../game_manager/mission_manager.dart';
import '../system/storage/game_runtime_state.dart';
import 'window_manager.dart';
import 'windows/pause_window.dart';
import 'windows/message_window.dart';
import 'windows/item_bag_window.dart';
import 'windows/calibration_window.dart';
import '../component/item/item.dart';

class GameUI extends StatefulWidget {
  final Size screenSize;
  final Function(bool) onPressedJumpButton;
  final MyGame game;
  final TimeService timeService;
  final bool isShowJumpButton;
  final WindowManager windowManager;

  static final ValueNotifier<bool> _showJumpButtonNotifier =
      ValueNotifier<bool>(true);
  static bool get showJumpButton => _showJumpButtonNotifier.value;

  static final ValueNotifier<(VoidCallback, IconData)?> interactActionNotifier =
      ValueNotifier(null);

  // Direction button state notifiers
  static final ValueNotifier<DirectionButtonState> _upButtonStateNotifier =
      ValueNotifier<DirectionButtonState>(DirectionButtonState.disabled);
  static final ValueNotifier<bool> _upButtonPressedNotifier =
      ValueNotifier<bool>(false); // upボタンの押下状態を通知するNotifier
  static final ValueNotifier<DirectionButtonState> _downButtonStateNotifier =
      ValueNotifier<DirectionButtonState>(DirectionButtonState.normal);
  static final ValueNotifier<bool> _downButtonPressedNotifier =
      ValueNotifier<bool>(false); // downボタンの押下状態を通知するNotifier
  static final ValueNotifier<DirectionButtonState> _leftButtonStateNotifier =
      ValueNotifier<DirectionButtonState>(DirectionButtonState.normal);
  static final ValueNotifier<bool> _leftButtonPressedNotifier =
      ValueNotifier<bool>(false); // leftボタンの押下状態を通知するNotifier
  static final ValueNotifier<DirectionButtonState> _rightButtonStateNotifier =
      ValueNotifier<DirectionButtonState>(DirectionButtonState.normal);
  static final ValueNotifier<bool> _rightButtonPressedNotifier =
      ValueNotifier<bool>(false); // rightボタンの押下状態を通知するNotifier

  // Mission Glitch Notifier
  static final ValueNotifier<int> missionGlitchNotifier = ValueNotifier<int>(0);

  // Attribute PIPs Pulse Notifier (通知したい属性IDを渡す)
  static final ValueNotifier<String?> attributePulseNotifier = ValueNotifier<String?>(null);

  // Action button state notifiers
  static final ValueNotifier<ActionButtonState> _jumpButtonStateNotifier =
      ValueNotifier<ActionButtonState>(ActionButtonState.normal);
  static final ValueNotifier<ActionButtonState> _digButtonStateNotifier =
      ValueNotifier<ActionButtonState>(ActionButtonState.disabled);
  static final ValueNotifier<ActionButtonState> _interactButtonStateNotifier =
      ValueNotifier<ActionButtonState>(ActionButtonState.disabled);
  static final ValueNotifier<IconData?> _interactButtonIconNotifier =
      ValueNotifier<IconData?>(null);

  // for carrying mode
  static final ValueNotifier<ActionButtonState> _placeButtonStateNotifier =
      ValueNotifier<ActionButtonState>(ActionButtonState.disabled);
  static final ValueNotifier<ActionButtonState> _storeButtonStateNotifier =
      ValueNotifier<ActionButtonState>(ActionButtonState.disabled);

  // for equipped item
  static final ValueNotifier<ActionButtonState>
  _equippedItemUseButtonStateNotifier = ValueNotifier<ActionButtonState>(
    ActionButtonState.disabled,
  );
  static final ValueNotifier<String?> _equippedItemNameNotifier =
      ValueNotifier<String?>(null);

  // Direction button setters
  static void setUpButtonState(DirectionButtonState state) =>
      _upButtonStateNotifier.value = state;
  static void setDownButtonState(DirectionButtonState state) =>
      _downButtonStateNotifier.value = state;
  static void setLeftButtonState(DirectionButtonState state) =>
      _leftButtonStateNotifier.value = state;
  static void setRightButtonState(DirectionButtonState state) =>
      _rightButtonStateNotifier.value = state;

  // Direction button getters
  static ValueNotifier<bool> get upButtonPressedNotifier =>
      _upButtonPressedNotifier;
  static ValueNotifier<bool> get downButtonPressedNotifier =>
      _downButtonPressedNotifier;
  static ValueNotifier<bool> get leftButtonPressedNotifier =>
      _leftButtonPressedNotifier;
  static ValueNotifier<bool> get rightButtonPressedNotifier =>
      _rightButtonPressedNotifier;

  // Action button setters
  static void setJumpButtonState(ActionButtonState state) =>
      _jumpButtonStateNotifier.value = state;
  static void setDigButtonState(ActionButtonState state) =>
      _digButtonStateNotifier.value = state;
  static void setInteractButtonState(ActionButtonState state) =>
      _interactButtonStateNotifier.value = state;
  static void setInteractButtonIcon(IconData? icon) =>
      _interactButtonIconNotifier.value = icon;

  // for carrying mode
  static void setPlaceButtonState(ActionButtonState state) =>
      _placeButtonStateNotifier.value = state;
  static void setStoreButtonState(ActionButtonState state) =>
      _storeButtonStateNotifier.value = state;

  // 運搬モードボタンの状態をリセットするメソッド
  static void resetCarryingModeButtons() {
    _placeButtonStateNotifier.value = ActionButtonState.disabled;
    _storeButtonStateNotifier.value = ActionButtonState.disabled;
  }

  static void setInteractAction(VoidCallback? action, IconData? icon) {
    if (action != null && icon != null) {
      interactActionNotifier.value = (action, icon);
      // interactButtonStateNotifierも更新
      setInteractButtonState(ActionButtonState.notice);
      setInteractButtonIcon(icon);
    } else {
      interactActionNotifier.value = null;
      // interactButtonStateNotifierもリセット
      setInteractButtonState(ActionButtonState.disabled);
      setInteractButtonIcon(null);
    }
  }

  // 一旦実装をやめる
  static void toggleJumpButton(bool? value) {
    _showJumpButtonNotifier.value = value ?? !_showJumpButtonNotifier.value;
  }

  const GameUI({
    super.key,
    required this.screenSize,
    required this.onPressedJumpButton,
    required this.game,
    required this.timeService,
    this.isShowJumpButton = false,
    required this.windowManager,
  });

  @override
  State<GameUI> createState() => _GameUIState();
}

/// 侵食走査線エフェクト
class _ScanningLineEffect extends StatefulWidget {
  final double erosionLevel;
  const _ScanningLineEffect({required this.erosionLevel});

  @override
  State<_ScanningLineEffect> createState() => _ScanningLineEffectState();
}

class _ScanningLineEffectState extends State<_ScanningLineEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ScanningLinePainter(
            progress: _controller.value,
            erosionLevel: widget.erosionLevel,
          ),
        );
      },
    );
  }
}

class _ScanningLinePainter extends CustomPainter {
  final double progress;
  final double erosionLevel;
  _ScanningLinePainter({required this.progress, required this.erosionLevel});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05 + (erosionLevel * 0.1))
      ..strokeWidth = 1.0;

    // メインの走査線
    final double y = size.height * progress;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);

    // 侵食度に応じた不規則なノイズ線
    if (erosionLevel > 0.3) {
      final random = (progress * 100).toInt();
      if (random % 10 < (erosionLevel * 5)) {
        final double noiseY = size.height * ((progress + 0.2) % 1.0);
        canvas.drawLine(Offset(0, noiseY), Offset(size.width, noiseY), paint..color = Colors.white.withOpacity(0.02));
      }
    }
  }

  @override
  bool shouldRepaint(_ScanningLinePainter oldDelegate) => true;
}

class _GameUIState extends State<GameUI> {
  bool _isPlayerInitialized = false;
  double _startZoomDrag = 1.0;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    if (_isPlayerInitialized) {
      widget.game.itemBag.removeListener(_onItemBagChanged);
    }
    GameUI.interactActionNotifier.dispose();
    GameUI._showJumpButtonNotifier.dispose();
    GameUI._upButtonStateNotifier.dispose();
    GameUI._upButtonPressedNotifier.dispose();
    GameUI._downButtonStateNotifier.dispose();
    GameUI._downButtonPressedNotifier.dispose();
    GameUI._leftButtonStateNotifier.dispose();
    GameUI._leftButtonPressedNotifier.dispose();
    GameUI._rightButtonStateNotifier.dispose();
    GameUI._rightButtonPressedNotifier.dispose();
    GameUI._jumpButtonStateNotifier.dispose();
    GameUI._digButtonStateNotifier.dispose();
    GameUI._interactButtonStateNotifier.dispose();
    GameUI._interactButtonIconNotifier.dispose();
    GameUI._placeButtonStateNotifier.dispose();
    GameUI._storeButtonStateNotifier.dispose();
    GameUI._equippedItemUseButtonStateNotifier.dispose();
    GameUI._equippedItemNameNotifier.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    // playerの初期化を待つ (MyGameのplayerはlate finalなので、初期化完了を待つロジックが必要な場合は別のフラグやFutureを検討)
    if (mounted) {
      setState(() => _isPlayerInitialized = true);
      // ItemBagの変更を監視
      widget.game.itemBag.addListener(_onItemBagChanged);
      _onItemBagChanged(); // 初期化時にも実行
    }
  }

  void _onItemBagChanged() {
    if (!mounted) return;
    final equippedItemName = widget.game.itemBag.equippedItemName;
    GameUI._equippedItemNameNotifier.value = equippedItemName;
    if (equippedItemName != null) {
      GameUI._equippedItemUseButtonStateNotifier.value =
          ActionButtonState.normal;
    } else {
      GameUI._equippedItemUseButtonStateNotifier.value =
          ActionButtonState.disabled;
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (!_isPlayerInitialized) return;
    _startZoomDrag = widget.game.camera.viewfinder.zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_isPlayerInitialized) return;
    if (details.scale != 1.0) {
      final newZoom = _startZoomDrag * details.scale;
      widget.game.camera.viewfinder.zoom = newZoom.clamp(
        widget.game.minZoomToFit,
        widget.game.maxZoomToFit,
      );
    }
  }

  double _getFontSize(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // 横画面のスマホ（高さが小さく幅がそれなりにある）も考慮
    final bool isMobile = size.width < 600 || size.height < 500;
    return isMobile ? 12.0 : 16.0;
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = _getFontSize(context);
    return Stack(
      children: [
        // 透明な背景を追加
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            child: Container(color: Colors.transparent),
          ),
        ),
        if (_isPlayerInitialized) ...[
          _buildStatusDisplay(fontSize),
          _buildDirectionalButtons(),
          _buildActionButtons(fontSize), // アクションボタン
          _buildTopRightButtons(fontSize), // ポーズボタンとアイテムバッグボタンをグループ化
          _buildAchievementNotification(fontSize), // アチーブメント通知
        ],
      ],
    );
  }

  Widget _buildAchievementNotification(double fontSize) {
    return Positioned(
      top: widget.screenSize.height * 0.1,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: widget.game.gameRuntimeState,
          builder: (context, child) {
            final title = widget.game.gameRuntimeState.lastUnlockedAchievement;
            if (title == null) return const SizedBox.shrink();
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.amberAccent.withOpacity(0.5), blurRadius: 10)
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber),
                  const SizedBox(width: 10),
                  Text(
                    'Achievement Unlocked: $title',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'TRS-Million-Rg',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusDisplay(double fontSize) {
    final bool isMobile = widget.screenSize.width < 600 || widget.screenSize.height < 500;
    final double effectiveFontSize = isMobile ? 12.0 : 16.0;

    return Positioned(
      top: widget.screenSize.height * 0.02,
      left: widget.screenSize.width * 0.02,
      width: widget.screenSize.width * (isMobile ? 0.45 : 0.3), // 幅をコンパクトに
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: widget.screenSize.height * 0.45,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHpBarContent(effectiveFontSize),
            const SizedBox(height: 4),
            _buildDigitalClockContent(effectiveFontSize),
            const SizedBox(height: 4),
            _buildPointsContent(effectiveFontSize),
            const SizedBox(height: 4),
            _buildAttributePips(effectiveFontSize),
            const SizedBox(height: 4),
            _buildCalibrationDisplay(effectiveFontSize),
            const SizedBox(height: 4),
            _buildUndergroundHint(effectiveFontSize),
            const SizedBox(height: 4),
            _buildCommunicationWindow(effectiveFontSize),
          ],
        ),
      ),
    );
  }

  Widget _buildUndergroundHint(double fontSize) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.game.player.inUnderGroundNotifier,
      builder: (context, inUnderground, child) {
        if (!inUnderground) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.security, size: fontSize * 0.8, color: Colors.greenAccent),
              const SizedBox(width: 4),
              Text(
                'STATUS: RAW_DATA_ACCESS (SANCTUARY)',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: fontSize * 0.6,
                  fontFamily: 'TRS-Million-Rg',
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalibrationDisplay(double fontSize) {
    return AnimatedBuilder(
      animation: widget.game.gameRuntimeState,
      builder: (context, child) {
        final state = widget.game.gameRuntimeState;
        if (state.scenarioCount <= 1) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune, size: fontSize * 0.8, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                'CALIBRATED: ${(state.speedCalibrationScale * 100).toInt()}%',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: fontSize * 0.7,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttributePips(double fontSize) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.game.gameRuntimeState, GameUI.attributePulseNotifier]),
      builder: (context, child) {
        final scores = widget.game.gameRuntimeState.attributeScores;
        final currentAttr = widget.game.missionManager.getCurrentAttribute();
        final pulseAttr = GameUI.attributePulseNotifier.value;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPip(GameRuntimeState.routeViolence, Colors.redAccent, scores[GameRuntimeState.routeViolence] ?? 0, currentAttr == GameRuntimeState.routeViolence, pulseAttr == GameRuntimeState.routeViolence),
            const SizedBox(width: 4),
            _buildPip(GameRuntimeState.routeEfficiency, Colors.blueAccent, scores[GameRuntimeState.routeEfficiency] ?? 0, currentAttr == GameRuntimeState.routeEfficiency, pulseAttr == GameRuntimeState.routeEfficiency),
            const SizedBox(width: 4),
            _buildPip(GameRuntimeState.routeEmpathy, Colors.orange, scores[GameRuntimeState.routeEmpathy] ?? 0, currentAttr == GameRuntimeState.routeEmpathy, pulseAttr == GameRuntimeState.routeEmpathy),
            const SizedBox(width: 4),
            _buildPip(GameRuntimeState.routePhilosophy, Colors.greenAccent, scores[GameRuntimeState.routePhilosophy] ?? 0, currentAttr == GameRuntimeState.routePhilosophy, pulseAttr == GameRuntimeState.routePhilosophy),
          ],
        );
      },
    );
  }

  Widget _buildPip(String attr, Color color, double score, bool isActive, bool isPulsing) {
    final double size = isPulsing ? 14.0 : (isActive ? 10.0 : 6.0);
    final double opacity = isPulsing ? 1.0 : (score > 0 ? (isActive ? 1.0 : 0.5) : 0.1);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(opacity),
        shape: BoxShape.circle,
        boxShadow: (isActive || isPulsing) ? [
          BoxShadow(color: color.withOpacity(0.5), blurRadius: isPulsing ? 8 : 4, spreadRadius: isPulsing ? 2 : 1)
        ] : null,
      ),
    );
  }

  Widget _buildCommunicationWindow(double fontSize) {
    final isMobile = widget.screenSize.width < 600 || widget.screenSize.height < 500;
    final double responsiveFontSize = isMobile ? fontSize * 0.8 : fontSize;
    final double windowWidthScale = isMobile ? 0.7 : 0.4;
    
    return AnimatedBuilder(
      animation: Listenable.merge([widget.game.gameRuntimeState, GameUI.missionGlitchNotifier]),
      builder: (context, child) {
        final state = widget.game.gameRuntimeState;
        final mission = state.currentMission;
        if (mission == null || mission.isEmpty) return const SizedBox.shrink();

        final MissionStyle style = widget.game.missionManager.getMissionStyle();
        
        // グリッチ演出用のオフセット
        final glitchValue = GameUI.missionGlitchNotifier.value;
        final double noise = glitchValue > 0 ? (glitchValue.toDouble() * style.noiseIntensity) : 0;
        final double offsetX = noise > 0 ? (glitchValue % 2 == 0 ? noise : -noise) : 0;
        final double offsetY = noise > 0 ? (glitchValue % 3 == 0 ? noise / 2 : -noise / 2) : 0;

        // 日本語の改行を助けるためにゼロ幅スペースを挿入
        final String rawText = glitchValue > 15 ? "SYSTEM_ERROR" : mission;
        final String missionText = rawText.split('').join('\u{200B}');
        
        return Transform.translate(
          offset: Offset(offsetX, offsetY),
          child: Container(
            constraints: BoxConstraints(maxWidth: widget.screenSize.width * windowWidthScale),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: style.bgColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(style.isOperator ? 12 : 2),
              border: Border.all(
                color: (glitchValue > 0 && style.hasGlitch) ? Colors.red : (style.isOperator ? Colors.white70 : Colors.white), 
                width: (glitchValue > 0 && style.hasGlitch) ? 2 : (style.isOperator ? 1.5 : 1)
              ),
              boxShadow: style.hasGlitch ? [
                BoxShadow(color: style.bgColor.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)
              ] : (style.isOperator ? [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(2, 2))
              ] : null),
            ),
            child: Stack(
              children: [
                // 走査線エフェクト (地上かつ非オペレーター時のみ)
                if (!style.isOperator && !widget.game.player.inUnderGround)
                  Positioned.fill(child: _ScanningLineEffect(erosionLevel: widget.game.missionManager.getErosionRate())),
                
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // アイコンの表示
                    Container(
                      width: responsiveFontSize * 2.2,
                      height: responsiveFontSize * 2.2,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: style.isOperator ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/${style.iconPath}',
                          errorBuilder: (context, error, stackTrace) => 
                            Icon(style.isOperator ? Icons.face : Icons.terminal, size: responsiveFontSize * 1.5, color: Colors.white70),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        missionText,
                        style: TextStyle(
                          fontSize: responsiveFontSize * style.fontSizeScale,
                          fontWeight: FontWeight.bold,
                          color: style.color,
                          fontFamily: 'TRS-Million-Rg',
                          height: 1.1,
                          decoration: TextDecoration.none,
                        ),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDirectionalButtons() {
    final dpadSize = widget.screenSize.width * 0.25;
    final buttonSize = widget.screenSize.width * 0.07;
    final iconSize = widget.screenSize.width * 0.05;

    return Positioned(
      left: widget.screenSize.width * 0.05,
      bottom: widget.screenSize.height * 0.05,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _handleDpadTouch(details.localPosition, dpadSize),
        onTapUp: (_) => _resetDpadStates(), // タップを離した時にリセット
        onTapCancel: () => _resetDpadStates(), // タップがキャンセルされた時にリセット
        onPanStart: (details) => _handleDpadTouch(details.localPosition, dpadSize),
        onPanUpdate: (details) => _handleDpadTouch(details.localPosition, dpadSize),
        onPanEnd: (_) => _resetDpadStates(),
        child: Container(
          width: dpadSize,
          height: dpadSize,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Up
              Positioned(
                top: 0,
                child: DirectionButton(
                  icon: Icons.arrow_circle_up_outlined,
                  onPressed: (_) {}, // GestureDetectorで処理するため空
                  stateNotifier: GameUI._upButtonStateNotifier,
                  buttonSize: buttonSize,
                  iconSize: iconSize,
                ),
              ),
              // Down
              Positioned(
                bottom: 0,
                child: DirectionButton(
                  icon: Icons.arrow_circle_down_outlined,
                  onPressed: (_) {},
                  stateNotifier: GameUI._downButtonStateNotifier,
                  buttonSize: buttonSize,
                  iconSize: iconSize,
                ),
              ),
              // Left
              Positioned(
                left: 0,
                child: DirectionButton(
                  icon: Icons.arrow_circle_left_outlined,
                  onPressed: (_) {},
                  stateNotifier: GameUI._leftButtonStateNotifier,
                  buttonSize: buttonSize,
                  iconSize: iconSize,
                ),
              ),
              // Right
              Positioned(
                right: 0,
                child: DirectionButton(
                  icon: Icons.arrow_circle_right_outlined,
                  onPressed: (_) {},
                  stateNotifier: GameUI._rightButtonStateNotifier,
                  buttonSize: buttonSize,
                  iconSize: iconSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDpadTouch(Offset localPosition, double dpadSize) {
    final center = Offset(dpadSize / 2, dpadSize / 2);
    final delta = localPosition - center;
    final distance = delta.distance;

    // デッドゾーンと最大半径のチェック
    if (distance < 10) {
      _resetDpadStates();
      return;
    }

    _resetDpadStates();

    // 角度に基づいてボタンを判定 (4方向)
    final angle = delta.direction; // -pi to pi

    const double pi = 3.1415926535897932;
    const double pi4 = pi / 4;

    if (angle >= -pi4 * 3 && angle < -pi4) {
      // Up
      GameUI._upButtonPressedNotifier.value = true;
      GameUI._upButtonStateNotifier.value = DirectionButtonState.pressed;
    } else if (angle >= pi4 && angle < pi4 * 3) {
      // Down
      GameUI._downButtonPressedNotifier.value = true;
      GameUI._downButtonStateNotifier.value = DirectionButtonState.pressed;
    } else if (angle >= pi4 * 3 || angle < -pi4 * 3) {
      // Left
      GameUI._leftButtonPressedNotifier.value = true;
      GameUI._leftButtonStateNotifier.value = DirectionButtonState.pressed;
    } else if (angle >= -pi4 && angle < pi4) {
      // Right
      GameUI._rightButtonPressedNotifier.value = true;
      GameUI._rightButtonStateNotifier.value = DirectionButtonState.pressed;
    }
  }

  void _resetDpadStates() {
    GameUI._upButtonPressedNotifier.value = false;
    GameUI._downButtonPressedNotifier.value = false;
    GameUI._leftButtonPressedNotifier.value = false;
    GameUI._rightButtonPressedNotifier.value = false;

    if (GameUI._upButtonStateNotifier.value == DirectionButtonState.pressed) {
      GameUI._upButtonStateNotifier.value = DirectionButtonState.normal;
    }
    if (GameUI._downButtonStateNotifier.value == DirectionButtonState.pressed) {
      GameUI._downButtonStateNotifier.value = DirectionButtonState.normal;
    }
    if (GameUI._leftButtonStateNotifier.value == DirectionButtonState.pressed) {
      GameUI._leftButtonStateNotifier.value = DirectionButtonState.normal;
    }
    if (GameUI._rightButtonStateNotifier.value == DirectionButtonState.pressed) {
      GameUI._rightButtonStateNotifier.value = DirectionButtonState.normal;
    }
    // _updateUpButtonStateなどはPlayer側で定期的に呼ばれるか、listenerで同期される
  }

  Widget _buildActionButtons(double fontSize) {
    final buttonSize = widget.screenSize.width * 0.07;
    final iconSize = widget.screenSize.width * 0.05;

    return Positioned(
      right: widget.screenSize.width * 0.05,
      bottom: widget.screenSize.height * 0.1,
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.game.player.isCarryingItemNotifier,
        builder: (context, isCarrying, child) {
          if (isCarrying) {
            return _buildCarryingActionButtons(buttonSize, iconSize);
          } else {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Equipped Item Use Button
                ValueListenableBuilder<String?>(
                  valueListenable: GameUI._equippedItemNameNotifier,
                  builder: (context, itemName, child) {
                    if (itemName == null) return const SizedBox.shrink();
                    final item = widget.game.itemBag.items[itemName];
                    if (item == null) return const SizedBox.shrink();
                    return AnimatedBuilder(
                      animation: widget.game.itemBag,
                      builder: (context, child) {
                        final count = widget.game.itemBag.getItemCount(itemName);
                        return Row(
                          children: [
                            ActionButton(
                              imagePath: item.spritePath,
                              badgeCount: count,
                              onPressed: () {
                                item.onUse(widget.game.player);
                                if (item.type != ItemType.tool) {
                                  widget.game.itemBag.removeItem(itemName);
                                }
                              },
                              stateNotifier:
                                  GameUI._equippedItemUseButtonStateNotifier,
                              buttonSize: buttonSize,
                              iconSize: iconSize,
                            ),
                            SizedBox(width: widget.screenSize.width * 0.03),
                          ],
                        );
                      },
                    );
                  },
                ),
                // Dig Button
                ActionButton(
                  icon: Icons.keyboard_double_arrow_down_sharp,
                  onTogglePressed: (isPressed) {
                    widget.game.player.toggleDigging(isPressed);
                  },
                  stateNotifier: GameUI._digButtonStateNotifier,
                  buttonSize: buttonSize,
                  iconSize: iconSize,
                ),
                SizedBox(width: widget.screenSize.width * 0.03),
                // Interact Button
                ValueListenableBuilder<(VoidCallback, IconData)?>(
                  valueListenable: GameUI.interactActionNotifier,
                  builder: (context, interaction, child) {
                    return ActionButton(
                      icon: interaction?.$2,
                      onPressed: interaction?.$1,
                      stateNotifier: GameUI._interactButtonStateNotifier,
                      iconNotifier: GameUI._interactButtonIconNotifier,
                      buttonSize: buttonSize,
                      iconSize: iconSize,
                    );
                  },
                ),
                SizedBox(width: widget.screenSize.width * 0.03),
                // Jump Button
                ActionButton(
                  icon: Icons.keyboard_double_arrow_up,
                  onTogglePressed: (isPressed) {
                    widget.onPressedJumpButton(isPressed);
                  },
                  stateNotifier: GameUI._jumpButtonStateNotifier,
                  buttonSize: buttonSize,
                  iconSize: iconSize,
                ),
              ],
            );
          }
        },
      ),
    );
  }

  // 運搬モード時のアクションボタン
  Widget _buildCarryingActionButtons(double buttonSize, double iconSize) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 収納ボタン
        ActionButton(
          icon: Icons.backpack_outlined,
          onPressed: () {
            if (widget.game.player.carriedItem != null) {
              final carriedItem = widget.game.player.carriedItem!;
              widget.game.player.itemBag.addItem(carriedItem);
              widget.game.player.stopCarrying();
            }
          },
          stateNotifier: GameUI._storeButtonStateNotifier,
          buttonSize: buttonSize,
          iconSize: iconSize,
        ),
        SizedBox(width: widget.screenSize.width * 0.06),
        // 配置ボタン
        ActionButton(
          icon: widget.game.player.iscrouching
                  ? Icons.place_outlined
                  : Icons.arrow_forward_outlined,
          onPressed: () {
            if (widget.game.player.carriedItem != null) {
              final carriedItem = widget.game.player.carriedItem!;
              final player = widget.game.player;
              // プレイヤーの移動速度（velocity.x）が一定以上なら投げる、そうでなければ置く
              player.velocity.x.abs() > 10.0
                  ? player.throwWorldObject(carriedItem)
                  : player.placeWorldObject(carriedItem);
            }
          },
          stateNotifier: GameUI._placeButtonStateNotifier,
          buttonSize: buttonSize,
          iconSize: iconSize,
        ),
        SizedBox(width: widget.screenSize.width * 0.03),
        // Jump Button
        ActionButton(
          icon: Icons.keyboard_double_arrow_up,
          onTogglePressed: (isPressed) {
            widget.onPressedJumpButton(isPressed);
          },
          stateNotifier: GameUI._jumpButtonStateNotifier,
          buttonSize: buttonSize,
          iconSize: iconSize,
        ),
      ],
    );
  }

  Widget _buildHpBarContent(double fontSize) {
    return Container(
      height: 60, // 高さを固定してレイアウトを安定させる
      padding: EdgeInsets.fromLTRB(
        widget.screenSize.width * 0.01,
        widget.screenSize.height * 0.01,
        widget.screenSize.width * 0.01,
        widget.screenSize.height * 0.005,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // HPゲージ
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: widget.screenSize.height * 0.01,
                  child: ValueListenableBuilder<double>(
                    valueListenable: widget.game.player.hpNotifier,
                    builder: (context, currentHp, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: currentHp / widget.game.player.maxHp,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // ストレスゲージ
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: widget.screenSize.height * 0.01,
                  child: ValueListenableBuilder<double>(
                    valueListenable: widget.game.player.stressNotifier,
                    builder: (context, currentStress, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor:
                            currentStress / widget.game.player.maxStress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(122, 61, 32, 230),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // HPとStressのテキスト
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: constraints.maxWidth * 0.03),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Health',
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'TRS-Million-Rg',
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: constraints.maxWidth * 0.03),
                      child: ValueListenableBuilder<double>(
                        valueListenable: widget.game.player.hpNotifier,
                        builder: (context, currentHp, child) {
                          return Text(
                            '${currentHp.toInt()}',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'TRS-Million-Rg',
                              letterSpacing: 2,
                              color: Colors.red,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: constraints.maxWidth * 0.03),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(122, 61, 32, 230),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Stress',
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'TRS-Million-Rg',
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: constraints.maxWidth * 0.03),
                      child: ValueListenableBuilder<double>(
                        valueListenable: widget.game.player.stressNotifier,
                        builder: (context, currentStress, child) {
                          return Text(
                            '${currentStress.toInt()} / ${widget.game.player.maxStress.toInt()}',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'TRS-Million-Rg',
                              letterSpacing: 2,
                              color: const Color.fromARGB(122, 61, 32, 230),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDigitalClockContent(double fontSize) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final clockFontSize = fontSize * 1.2; // fontSizeを基準にする
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(10),
          ),
          child: AnimatedBuilder(
            animation: widget.timeService,
            builder: (context, child) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: constraints.maxWidth * 0.03),
                    child: FittedBox(
                      child: Text(
                        widget.timeService.getFormattedDay(),
                        style: TextStyle(
                          fontSize: clockFontSize,
                          fontFamily: 'TRS-Million-Rg',
                          letterSpacing: 5,
                          color: Colors.greenAccent.shade700,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: constraints.maxWidth * 0.03),
                    child: FittedBox(
                      child: Text(
                        widget.timeService.getFormattedTime(),
                        style: TextStyle(
                          fontSize: clockFontSize,
                          fontFamily: 'TRS-Million-Rg',
                          letterSpacing: 5,
                          color: Colors.greenAccent.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPointsContent(double fontSize) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = fontSize * 1.5;
        final pointFontSize = fontSize;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: widget.game.player.currencyNotifier,
                builder: (context, child) {
                  return Row(
                    children: [
                      Image.asset(
                        'assets/images/money.png',
                        width: iconSize,
                        height: iconSize,
                      ),
                      SizedBox(width: constraints.maxWidth * 0.02),
                      Text(
                        '${widget.game.player.currencyNotifier.value}',
                        style: TextStyle(
                          fontSize: pointFontSize,
                          fontFamily: 'TRS-Million-Rg',
                          letterSpacing: 5,
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(1, 1),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              AnimatedBuilder(
                animation: widget.game.player.miningPointsNotifier,
                builder: (context, child) {
                  return Row(
                    children: [
                      Image.asset(
                        'assets/images/shovel.png',
                        width: iconSize,
                        height: iconSize,
                      ),
                      SizedBox(width: constraints.maxWidth * 0.02),
                      Text(
                        '${widget.game.player.currentMiningPoints}',
                        style: TextStyle(
                          fontSize: pointFontSize,
                          fontFamily: 'TRS-Million-Rg',
                          letterSpacing: 5,
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(1, 1),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPauseButton(double fontSize) {
    return ElevatedButton(
      onPressed: () {
        widget.windowManager.showWindow(
          GameWindowType.pause,
          PauseWindow(
            windowManager: widget.windowManager,
            itemBag: widget.game.itemBag,
            game: widget.game,
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        padding: EdgeInsets.all(widget.screenSize.width * 0.02),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Icon(
        Icons.pause,
        color: Colors.white,
        size: widget.screenSize.width * 0.03,
      ),
    );
  }

  Widget _buildItemBagButton(double fontSize) {
    return ElevatedButton(
      onPressed: () {
        widget.windowManager.showWindow(
          GameWindowType.itemBag,
          ItemBagWindow(
            windowManager: widget.windowManager,
            itemBag: widget.game.itemBag,
            game: widget.game,
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 141, 75, 0),
        padding: EdgeInsets.all(widget.screenSize.width * 0.02),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Icon(
        Icons.backpack,
        color: Colors.white,
        size: widget.screenSize.width * 0.03,
      ),
    );
  }

  Widget _buildCalibrationButton(double fontSize) {
    return ElevatedButton(
      onPressed: () {
        widget.windowManager.showWindow(
          GameWindowType.calibration,
          CalibrationWindow(
            windowManager: widget.windowManager,
            state: widget.game.gameRuntimeState,
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueGrey[800],
        padding: EdgeInsets.all(widget.screenSize.width * 0.02),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: Colors.blueAccent, width: 1),
      ),
      child: Icon(
        Icons.tune,
        color: Colors.white,
        size: widget.screenSize.width * 0.03,
      ),
    );
  }

  Widget _buildTopRightButtons(double fontSize) {
    return Positioned(
      top: widget.screenSize.height * 0.02,
      right: widget.screenSize.width * 0.02,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPauseButton(fontSize),
          SizedBox(height: widget.screenSize.height * 0.01),
          _buildItemBagButton(fontSize),
          SizedBox(height: widget.screenSize.height * 0.01),
          _buildCalibrationButton(fontSize),
          SizedBox(height: widget.screenSize.height * 0.01),
          _buildTestTextBoxButton(fontSize),
        ],
      ),
    );
  }

  Widget _buildTestTextBoxButton(double fontSize) {
    return ElevatedButton(
      onPressed: () {
        widget.windowManager.showWindow(
          GameWindowType.message,
          MessageWindow(
            messages: ['開発者の特権を使用します。(アイテムをランダムに生成する)'],
            fontSize: fontSize,
            onFinish: () {
              widget.windowManager.hideWindow();
              ItemFactory.spawnTestItems(widget.game, widget.game.player);
            },
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple,
        padding: EdgeInsets.all(widget.screenSize.width * 0.02),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Icon(
        Icons.text_fields,
        color: Colors.white,
        size: widget.screenSize.width * 0.03,
      ),
    );
  }
}

enum DirectionButtonState { normal, pressed, disabled, notice }

class DirectionButton extends StatefulWidget {
  final IconData icon;
  final Function(bool) onPressed;
  final ValueNotifier<DirectionButtonState> stateNotifier;
  final double buttonSize; // 新しいプロパティ
  final double iconSize; // 新しいプロパティ

  const DirectionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.stateNotifier,
    required this.buttonSize,
    required this.iconSize,
  });

  @override
  State<DirectionButton> createState() => _DirectionButtonState();
}

class _DirectionButtonState extends State<DirectionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _borderAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _borderAnimation = Tween<double>(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    widget.stateNotifier.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    widget.stateNotifier.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (widget.stateNotifier.value == DirectionButtonState.notice) {
      _animationController.value = 0.0; // 開始値をリセット
      _animationController.repeat(reverse: true); // ループするように変更
    } else {
      _animationController.stop();
      _animationController.value = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DirectionButtonState>(
      valueListenable: widget.stateNotifier,
      builder: (context, state, child) {
        double opacity = 0.2;
        Color buttonColor = Colors.blue;
        Widget? noticeBorder;

        switch (state) {
          case DirectionButtonState.normal:
            opacity = 0.6;
            buttonColor = Colors.blue;
            break;
          case DirectionButtonState.pressed:
            opacity = 0.9;
            buttonColor = Colors.blue;
            break;
          case DirectionButtonState.disabled:
            opacity = 0.1;
            buttonColor = Colors.grey;
            break;
          case DirectionButtonState.notice:
            opacity = 0.6;
            buttonColor = Colors.orange;
            noticeBorder = AnimatedBuilder(
              animation: _borderAnimation,
              builder: (context, child) {
                return Container(
                  width: widget.buttonSize, // 可変サイズ
                  height: widget.buttonSize, // 可変サイズ
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red.withOpacity(
                        1 - _animationController.value,
                      ),
                      width: widget.buttonSize * 0.1, // ボタンサイズの10%を輪郭の太さとして設定
                    ),
                  ),
                );
              },
            );
            break;
        }

        return GestureDetector(
          onTapDown: (_) {
            if (state != DirectionButtonState.disabled) {
              widget.onPressed(true);
              widget.stateNotifier.value = DirectionButtonState.pressed;
            }
          },
          onTapUp: (_) {
            if (state != DirectionButtonState.disabled) {
              widget.onPressed(false);
              widget.stateNotifier.value = DirectionButtonState.normal;
            }
          },
          onTapCancel: () {
            if (state != DirectionButtonState.disabled) {
              widget.onPressed(false);
              widget.stateNotifier.value = DirectionButtonState.normal;
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.buttonSize, // 可変サイズ
                height: widget.buttonSize, // 可変サイズ
                decoration: BoxDecoration(
                  color: buttonColor.withOpacity(opacity),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: widget.iconSize, // 可変サイズ
                  color: Colors.white.withOpacity(opacity), // アイコンの透明度を背景に合わせる
                ),
              ),
              if (noticeBorder != null) noticeBorder,
            ],
          ),
        );
      },
    );
  }
}

enum ActionButtonState { normal, pressed, disabled, notice }

class ActionButton extends StatefulWidget {
  final IconData? icon;
  final String? imagePath; // 画像パスを追加
  final int? badgeCount; // バッジのカウントを追加
  final VoidCallback? onPressed;
  final Function(bool)? onTogglePressed; // タップダウン/アップで状態を切り替えるボタン用
  final ValueNotifier<ActionButtonState> stateNotifier;
  final ValueNotifier<IconData?>? iconNotifier;
  final double buttonSize;
  final double iconSize;
  final VoidCallback? onLongPress;

  const ActionButton({
    super.key,
    this.icon,
    this.imagePath,
    this.badgeCount,
    this.onPressed,
    this.onTogglePressed,
    required this.stateNotifier,
    this.iconNotifier,
    required this.buttonSize, // コンストラクタに追加
    required this.iconSize, // コンストラクタに追加
    this.onLongPress, // コンストラクタに追加
  });

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _borderAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _borderAnimation = Tween<double>(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    widget.stateNotifier.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    widget.stateNotifier.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (widget.stateNotifier.value == ActionButtonState.notice) {
      _animationController.value = 0.0; // 開始値をリセット
      _animationController.repeat(reverse: true); // ループするように変更
    } else {
      _animationController.stop();
      _animationController.value = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActionButtonState>(
      valueListenable: widget.stateNotifier,
      builder: (context, state, child) {
        double opacity = 0.6;
        Color buttonColor = Colors.blue;
        Widget? noticeBorder;

        switch (state) {
          case ActionButtonState.normal:
            opacity = 0.6;
            buttonColor = Colors.blue;
            break;
          case ActionButtonState.pressed:
            opacity = 0.9;
            buttonColor = Colors.blue;
            break;
          case ActionButtonState.disabled:
            opacity = 0.5;
            buttonColor = Colors.grey;
            break;
          case ActionButtonState.notice:
            opacity = 0.6;
            buttonColor = Colors.orange;
            noticeBorder = AnimatedBuilder(
              animation: _borderAnimation,
              builder: (context, child) {
                return Container(
                  width: widget.buttonSize, // 可変サイズ
                  height: widget.buttonSize, // 可変サイズ
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red.withOpacity(
                        1 - _animationController.value,
                      ),
                      width: widget.buttonSize * 0.1, // ボタンサイズの10%を輪郭の太さとして設定
                    ),
                  ),
                );
              },
            );
            break;
        }

        return GestureDetector(
          onTap:
              state != ActionButtonState.disabled && widget.onPressed != null
                  ? () {
                    widget.onPressed!();
                  }
                  : null,
          onTapDown:
              widget.onTogglePressed != null &&
                      state != ActionButtonState.disabled
                  ? (_) {
                    widget.onTogglePressed!(true);
                    widget.stateNotifier.value = ActionButtonState.pressed;
                  }
                  : null,
          onTapUp:
              widget.onTogglePressed != null &&
                      state != ActionButtonState.disabled
                  ? (_) {
                    widget.onTogglePressed!(false);
                    widget.stateNotifier.value = ActionButtonState.normal;
                  }
                  : null,
          onTapCancel:
              widget.onTogglePressed != null &&
                      state != ActionButtonState.disabled
                  ? () {
                    widget.onTogglePressed!(false);
                    widget.stateNotifier.value = ActionButtonState.normal;
                  }
                  : null,
          onLongPress:
              state != ActionButtonState.disabled && widget.onLongPress != null
                  ? () {
                    widget.onLongPress!();
                  }
                  : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.buttonSize, // 可変サイズ
                height: widget.buttonSize, // 可変サイズ
                decoration: BoxDecoration(
                  color: buttonColor.withOpacity(opacity),
                  shape: BoxShape.circle,
                ),
                child: ValueListenableBuilder<IconData?>(
                  valueListenable:
                      widget.iconNotifier ??
                      ValueNotifier(
                        widget.icon,
                      ), // iconNotifierがnullの場合はデフォルトのiconを使用
                  builder: (context, iconData, child) {
                    if (widget.imagePath != null) {
                      return Image.asset(
                        'assets/images/${widget.imagePath}',
                        width: widget.iconSize,
                        height: widget.iconSize,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.broken_image,
                            size: widget.iconSize,
                            color: Colors.white.withOpacity(opacity),
                          );
                        },
                      );
                    }
                    return Icon(
                      iconData,
                      size: widget.iconSize, // 可変サイズ
                      color: Colors.white.withOpacity(opacity),
                    );
                  },
                ),
              ),
              if (noticeBorder != null) noticeBorder,
              if (widget.badgeCount != null && widget.badgeCount! > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: BoxConstraints(
                      minWidth: widget.buttonSize * 0.3,
                      minHeight: widget.buttonSize * 0.3,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.badgeCount}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.buttonSize * 0.2,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'TRS-Million-Rg',
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
