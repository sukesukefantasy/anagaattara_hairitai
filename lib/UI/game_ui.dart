import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flame/components.dart';

import '../main.dart';
import '../game_manager/time_service.dart';
import '../system/crafting_system.dart';
import '../system/storage/game_runtime_state.dart';
import 'window_manager.dart';
import 'windows/pause_window.dart';
import 'windows/message_window.dart';
import 'windows/item_bag_window.dart';
import 'windows/automation_shop_window.dart';
import 'windows/codex_window.dart';
import 'windows/crafting_window.dart';
import '../component/item/item.dart';
import '../component/player.dart';

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

class _ScanningLineEffectState extends State<_ScanningLineEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
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
    final paint =
        Paint()
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
        canvas.drawLine(
          Offset(0, noiseY),
          Offset(size.width, noiseY),
          paint..color = Colors.white.withOpacity(0.02),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ScanningLinePainter oldDelegate) => true;
}

/// [CargoHudFlyEvent] 用の一発オーブ演出（親 Stack の Positioned 子になる）。
class _CargoHudFlyingOrb extends StatefulWidget {
  final Offset start;
  final Offset end;
  final Color color;
  final VoidCallback onComplete;

  const _CargoHudFlyingOrb({
    super.key,
    required this.start,
    required this.end,
    required this.color,
    required this.onComplete,
  });

  @override
  State<_CargoHudFlyingOrb> createState() => _CargoHudFlyingOrbState();
}

class _CargoHudFlyingOrbState extends State<_CargoHudFlyingOrb>
    with SingleTickerProviderStateMixin {
  static const double _size = 14;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );

  late final AnimationStatusListener _statusListener;

  @override
  void initState() {
    super.initState();
    _statusListener = (AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onComplete();
      }
    };
    _controller.addStatusListener(_statusListener);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_statusListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final p = Offset.lerp(widget.start, widget.end, _t.value)!;
        return Positioned(
          left: p.dx - _size / 2,
          top: p.dy - _size / 2,
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withOpacity(0.92),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.55),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CargoFlySpec {
  _CargoFlySpec({
    required this.key,
    required this.start,
    required this.end,
    required this.color,
  });

  final Key key;
  final Offset start;
  final Offset end;
  final Color color;
}

class _GameUIState extends State<GameUI> with SingleTickerProviderStateMixin {
  bool _isPlayerInitialized = false;

  final GlobalKey _cargoRatioBarKey = GlobalKey();
  final GlobalKey _statusHudKey = GlobalKey();

  StreamSubscription<CargoHudFlyEvent>? _cargoHudFlySub;

  final List<_CargoFlySpec> _cargoFlySpecs = [];

  void _onRuntimeStateForV83() {
    if (!mounted) return;
    final s = widget.game.gameRuntimeState;
    if (!s.pendingAutomationShopUnlockNotice) return;
    s.consumeAutomationShopUnlockNoticeUi();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.windowManager.showDialog([
        '〔星の通知〕',
        '自動化ショップの端末が、画面右上に現れた。',
      ], bodyTextColor: Colors.lightBlueAccent);
    });
  }

  double _startZoomDrag = 1.0;

  late final AnimationController _hudShakeController;

  @override
  void initState() {
    super.initState();
    _hudShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 45),
    );
    widget.game.player.stressNotifier.addListener(_syncHudShakeFromStress);

    widget.game.gameRuntimeState.addListener(_onRuntimeStateForV83);
    widget.game.gameRuntimeState.addListener(_syncHudShakeFromStress);
    _cargoHudFlySub = widget.game.gameRuntimeState.cargoHudFlyStream.listen((
      e,
    ) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _spawnCargoHudFlyFromEvent(e),
      );
    });
    _initializePlayer();
  }

  @override
  void dispose() {
    widget.game.player.stressNotifier.removeListener(_syncHudShakeFromStress);
    _hudShakeController.dispose();
    _cargoHudFlySub?.cancel();
    widget.game.gameRuntimeState.removeListener(_syncHudShakeFromStress);
    widget.game.gameRuntimeState.removeListener(_onRuntimeStateForV83);
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

  Color _cargoFlyColor(CargoHudFlyKind k) => switch (k) {
    CargoHudFlyKind.life => Colors.redAccent.shade200,
    CargoHudFlyKind.history => Colors.lightBlue.shade300,
    CargoHudFlyKind.inorganic => Colors.blueGrey.shade500,
  };

  /// Flame の [CameraComponent.visibleWorldRect] とズームでビューポート座標へ（ライティングシェーダと同じ前提）。
  Offset _worldPointToScreenOverlay(double wx, double wy) {
    final cam = widget.game.camera;
    final rect = cam.visibleWorldRect;
    final z = cam.viewfinder.zoom;
    final vx = (wx - rect.left) * z;
    final vy = (wy - rect.top) * z;
    return Offset(vx, vy);
  }

  /// 比率バー Row と同じ順序・比率で、種別セグメントの画面上の狙い位置。
  Offset _cargoSegmentTargetGlobal(CargoHudFlyKind kind) {
    final state = widget.game.gameRuntimeState;
    final life = state.cargoLifeCount;
    final hist = state.cargoHistoryCount;
    final ino = state.cargoInorganicCount;
    final t = life + hist + ino;

    double segmentCenterX(double width) {
      if (t <= 0) return width * 0.5;
      final tt = t.toDouble();
      double x0 = 0;
      if (life > 0) {
        final sw = width * life / tt;
        if (kind == CargoHudFlyKind.life) return x0 + sw / 2;
        x0 += sw;
      }
      if (hist > 0) {
        final sw = width * hist / tt;
        if (kind == CargoHudFlyKind.history) return x0 + sw / 2;
        x0 += sw;
      }
      if (ino > 0) {
        final sw = width * ino / tt;
        if (kind == CargoHudFlyKind.inorganic) return x0 + sw / 2;
      }
      return width * 0.5;
    }

    final barCtx = _cargoRatioBarKey.currentContext;
    final barBox = barCtx?.findRenderObject() as RenderBox?;
    if (barBox != null && barBox.hasSize && t > 0) {
      final lx = segmentCenterX(barBox.size.width);
      return barBox.localToGlobal(Offset(lx, barBox.size.height / 2));
    }

    final statusCtx = _statusHudKey.currentContext;
    final statusBox = statusCtx?.findRenderObject() as RenderBox?;
    if (statusBox != null && statusBox.hasSize) {
      return statusBox.localToGlobal(
        Offset(statusBox.size.width * 0.35, statusBox.size.height * 0.52),
      );
    }

    return Offset(
      widget.screenSize.width * 0.12,
      widget.screenSize.height * 0.12,
    );
  }

  void _spawnCargoHudFlyFromEvent(CargoHudFlyEvent event) {
    if (!mounted || !_isPlayerInitialized) return;

    final world = event.worldPosition;
    final start = _worldPointToScreenOverlay(world.x, world.y);
    final end = _cargoSegmentTargetGlobal(event.kind);

    final spec = _CargoFlySpec(
      key: UniqueKey(),
      start: start,
      end: end,
      color: _cargoFlyColor(event.kind),
    );
    setState(() => _cargoFlySpecs.add(spec));
  }

  void _removeCargoFlySpec(_CargoFlySpec spec) {
    if (!mounted) return;
    setState(() => _cargoFlySpecs.remove(spec));
  }

  void _syncHudShakeFromStress() {
    if (!mounted || !_isPlayerInitialized) return;
    final p = widget.game.player;
    final cap = p.effectiveMaxStress;
    final high = cap > 1e-9 && p.currentStress >= cap * 0.8;
    if (high) {
      if (!_hudShakeController.isAnimating) {
        _hudShakeController.repeat();
      }
    } else {
      if (_hudShakeController.isAnimating) {
        _hudShakeController.stop();
      }
      _hudShakeController.value = 0;
    }
  }

  Offset _computeHudShakeOffset() {
    final p = widget.game.player;
    final cap = p.effectiveMaxStress;
    if (cap < 1e-9 || p.currentStress < cap * 0.8) {
      return Offset.zero;
    }
    final t = _hudShakeController.value;
    const amp = 3.2;
    return Offset(
      amp * math.sin(t * math.pi * 2 * 7),
      amp * math.cos(t * math.pi * 2 * 11),
    );
  }

  Future<void> _initializePlayer() async {
    // playerの初期化を待つ (MyGameのplayerはlate finalなので、初期化完了を待つロジックが必要な場合は別のフラグやFutureを検討)
    if (mounted) {
      setState(() => _isPlayerInitialized = true);
      // ItemBagの変更を監視
      widget.game.itemBag.addListener(_onItemBagChanged);
      _onItemBagChanged(); // 初期化時にも実行
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncHudShakeFromStress();
      });
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
    // ピンチ時のみズーム（わずかな数値ゆれでパンと両立しないよう閾値を挟む）
    const zoomNoise = 0.02;
    if ((details.scale - 1.0).abs() > zoomNoise) {
      final newZoom = _startZoomDrag * details.scale;
      widget.game.camera.viewfinder.zoom = newZoom.clamp(
        widget.game.minZoomToFit,
        widget.game.maxZoomToFit,
      );
      return;
    }
    // 右半分の一本指ドラッグ → カメラ手動パン（[CameraController.addManualPanFromScreenDelta]）
    if (details.localFocalPoint.dx >= widget.screenSize.width * 0.5) {
      final z = widget.game.camera.viewfinder.zoom;
      widget.game.cameraController.addManualPanFromScreenDelta(
        Vector2(-details.focalPointDelta.dx, -details.focalPointDelta.dy),
        z,
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
          AnimatedBuilder(
            animation: Listenable.merge([
              widget.game.player.stressNotifier,
              _hudShakeController,
            ]),
            builder: (context, _) {
              return Transform.translate(
                offset: _computeHudShakeOffset(),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [_buildStatusDisplay(fontSize)],
                ),
              );
            },
          ),
          _buildDirectionalButtons(),
          _buildActionButtons(fontSize), // アクションボタン
          _buildTopRightButtons(fontSize), // ポーズボタンとアイテムバッグボタンをグループ化
          _buildAchievementNotification(fontSize), // アチーブメント通知
          if (_cargoFlySpecs.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final spec in _cargoFlySpecs)
                      _CargoHudFlyingOrb(
                        key: spec.key,
                        start: spec.start,
                        end: spec.end,
                        color: spec.color,
                        onComplete: () => _removeCargoFlySpec(spec),
                      ),
                  ],
                ),
              ),
            ),
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
                  BoxShadow(
                    color: Colors.amberAccent.withOpacity(0.5),
                    blurRadius: 10,
                  ),
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
                      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
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

  /// ステータスHUD左列の各ブロック外周パディング（[_buildWillCoreHud] と同一規則）。
  EdgeInsets _statusHudBlockPadding(double fontSize) {
    final bool isMobile =
        widget.screenSize.width < 600 || widget.screenSize.height < 500;
    final padX = (fontSize * 0.35).clamp(4.0, 10.0);
    return EdgeInsets.fromLTRB(padX, isMobile ? 4 : 6, padX, isMobile ? 4 : 6);
  }

  Widget _buildStatusDisplay(double fontSize) {
    final bool isMobile =
        widget.screenSize.width < 600 || widget.screenSize.height < 500;
    final double effectiveFontSize = isMobile ? 12.0 : 16.0;
    final double sectionGap = isMobile ? 2.0 : 4.0;
    final double sw = widget.screenSize.width;
    final double baseW = sw * (isMobile ? 0.45 : 0.3);
    final double leftW = baseW * 0.7;
    final double cargoW = baseW * 0.5;
    final double hColGap = isMobile ? 4.0 : 6.0;

    return Positioned(
      top: widget.screenSize.height * 0.02,
      left: sw * 0.02,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: leftW,
            child: ConstrainedBox(
              key: _statusHudKey,
              constraints: BoxConstraints(
                maxHeight: widget.screenSize.height * 0.45,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildWillCoreHud(effectiveFontSize),
                    SizedBox(height: sectionGap),
                    _buildHpBarContent(effectiveFontSize),
                    SizedBox(height: sectionGap),
                    _buildDigitalClockContent(effectiveFontSize),
                    SizedBox(height: sectionGap),
                    _buildCommunicationWindow(effectiveFontSize),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: hColGap),
          SizedBox(
            width: cargoW,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCargoHudBlock(effectiveFontSize),
                SizedBox(height: sectionGap),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildPointsContent(effectiveFontSize),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _willCorePip(Color shellColor, double w, double h, double fill) {
    return SizedBox(
      width: w,
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: shellColor, width: 1.1),
          color: const Color(0xFF120c08).withValues(alpha: 0.9),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fill,
                heightFactor: 1,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFe65100), Color(0xFFffc947)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 意志の核（カウント可能な単位ピップ）。HP ブロックの直上。
  Widget _buildWillCoreHud(double fontSize) {
    final shellColor = const Color(0xFFb8860b).withValues(alpha: 0.75);
    const unit = GameRuntimeState.willCoreUnit;
    final bool isMobile =
        widget.screenSize.width < 600 || widget.screenSize.height < 500;

    return AnimatedBuilder(
      animation: widget.game.gameRuntimeState,
      builder: (context, child) {
        final state = widget.game.gameRuntimeState;
        final maxSlots = math.max(1, (state.maxWillCoreValue / unit).ceil());
        final blockPad = _statusHudBlockPadding(fontSize);
        final padX = blockPad.left;
        final pipW = math.max(14.0, fontSize * 0.62);
        final pipH = math.max(10.0, fontSize * 0.46);
        final gap = (fontSize * 0.22).clamp(3.0, 7.0);

        final pips = <Widget>[];
        for (var i = 0; i < maxSlots; i++) {
          final slotFill = ((state.currentWillpower - i * unit) / unit).clamp(
            0.0,
            1.0,
          );
          pips.add(_willCorePip(shellColor, pipW, pipH, slotFill));
          if (i < maxSlots - 1) {
            pips.add(SizedBox(width: gap));
          }
        }

        final curCores = state.currentWillpower / unit;
        final maxCores = state.maxWillCoreValue / unit;

        return Container(
          padding: blockPad,
          decoration: BoxDecoration(
            color: const Color(0xFF0f0b06).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF5d4037).withValues(alpha: 0.65),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFffb300).withValues(alpha: 0.12),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.brightness_5_outlined,
                    size: fontSize * 0.85,
                    color: const Color(0xFFffcc80),
                  ),
                  SizedBox(width: padX * 0.6),
                  Expanded(
                    child: Text(
                      '意志力（${curCores.toStringAsFixed(1)} / ${maxCores.toStringAsFixed(1)} 核）',
                      style: TextStyle(
                        color: const Color(0xFFffe0b2),
                        fontSize: fontSize * 0.68,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                        letterSpacing: 0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? fontSize * 0.18 : fontSize * 0.24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(mainAxisSize: MainAxisSize.min, children: pips),
              ),
            ],
          ),
        );
      },
    );
  }

  /// カーゴ残滓ゲージと射出操作を一塊にしたブロック。
  Widget _buildCargoHudBlock(double fontSize) {
    const edge = Color(0xFF006064);
    final bool isMobile =
        widget.screenSize.width < 600 || widget.screenSize.height < 500;
    final pad = _statusHudBlockPadding(fontSize);
    final headerGap = pad.left * 0.75;
    const double btnHeightScale = 1.5;
    final btnIconSize =
        (isMobile ? fontSize * 0.72 : fontSize * 0.85) * btnHeightScale;
    final btnLabelSize = isMobile ? fontSize * 0.56 : fontSize * 0.65;
    final btnPadH = isMobile ? fontSize * 0.38 : fontSize * 0.5;
    final btnPadV =
        (isMobile ? fontSize * 0.16 : fontSize * 0.22) * btnHeightScale;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF061416).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: edge.withValues(alpha: 0.55), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withValues(alpha: 0.06),
            blurRadius: 6,
          ),
        ],
      ),
      child: Padding(
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.pie_chart_outline,
                  size: fontSize * 0.8,
                  color: Colors.cyanAccent.shade100,
                ),
                SizedBox(width: headerGap),
                Expanded(
                  child: Text(
                    'カーゴ残滓',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: fontSize * 0.68,
                      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 3 : 4),
            _buildCargoRatioBar(fontSize),
            SizedBox(height: isMobile ? 4 : 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedBuilder(
                  animation: widget.game.gameRuntimeState,
                  builder: (context, _) {
                    final rs = widget.game.gameRuntimeState;
                    final canLaunch =
                        !rs.isCargoLaunched && rs.totalCargoCount > 0;
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canLaunch
                              ? Colors.cyanAccent
                              : edge.withValues(alpha: 0.65),
                          foregroundColor:
                              canLaunch ? edge : Colors.cyanAccent,
                          elevation: 2,
                          shadowColor: Colors.cyanAccent.withValues(alpha: 0.22),
                          padding: EdgeInsets.symmetric(
                            horizontal: btnPadH,
                            vertical: btnPadV,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          side: BorderSide(
                            color: canLaunch
                                ? edge.withValues(alpha: 0.85)
                                : Colors.cyanAccent.withValues(alpha: 0.45),
                            width: 1,
                          ),
                        ),
                        onPressed: () {
                          widget.game.player.cargoTerminal?.showCargoDialog();
                        },
                        icon: Icon(Icons.rocket_launch_outlined, size: btnIconSize),
                        label: Text(
                          'この星から射出',
                          style: TextStyle(
                            fontSize: btnLabelSize,
                            fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunicationWindow(double fontSize) {
    final isMobile =
        widget.screenSize.width < 600 || widget.screenSize.height < 500;
    final double responsiveFontSize = isMobile ? fontSize * 0.8 : fontSize;
    final double windowWidthScale = isMobile ? 0.7 : 0.4;

    return AnimatedBuilder(
      animation: widget.game.gameRuntimeState,
      builder: (context, child) {
        final state = widget.game.gameRuntimeState;
        final mission = state.currentMission;
        if (mission == null || mission.isEmpty) return const SizedBox.shrink();

        final _MissionHudStyle style = _MissionHudStyle.fromMissionText(
          mission,
        );

        // 日本語の改行を助けるためにゼロ幅スペースを挿入
        final String missionText = mission.split('').join('\u{200B}');
        final blockPad = _statusHudBlockPadding(fontSize);
        final iconTrailGap = blockPad.left * 0.75;

        return Container(
          constraints: BoxConstraints(
            maxWidth: widget.screenSize.width * windowWidthScale,
          ),
          padding: blockPad,
          decoration: BoxDecoration(
            color: style.bgColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(style.isOperator ? 12 : 2),
            border: Border.all(
              color: style.isOperator ? Colors.white70 : Colors.white,
              width: style.isOperator ? 1.5 : 1,
            ),
            boxShadow:
                style.hasTerminalShadow
                    ? [
                      BoxShadow(
                        color: style.bgColor.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                    : (style.isOperator
                        ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(2, 2),
                          ),
                        ]
                        : null),
          ),
          child: Stack(
            children: [
              // 走査線エフェクト (地上かつ非オペレーター時のみ)
              if (!style.isOperator && !widget.game.player.inUnderGround)
                Positioned.fill(
                  child: _ScanningLineEffect(
                    erosionLevel: _missionHudErosionRate(widget.game.player),
                  ),
                ),

              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // アイコンの表示
                  Container(
                    width: responsiveFontSize * 2.2,
                    height: responsiveFontSize * 2.2,
                    margin: EdgeInsets.only(right: iconTrailGap),
                    decoration: BoxDecoration(
                      color:
                          style.isOperator
                              ? Colors.white.withOpacity(0.8)
                              : Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/${style.iconPath}',
                        errorBuilder:
                            (context, error, stackTrace) => Icon(
                              style.isOperator ? Icons.face : Icons.terminal,
                              size: responsiveFontSize * 1.5,
                              color: Colors.white70,
                            ),
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
                        fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
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
      // GestureDetector の Tap と Pan が同一 Arena で競合すると onTap/onTapDown が
      // ~300ms 付近まで遅延することがあるため、確実に接触と同時に反応させるために Listener を使う。
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown:
            (e) =>
                _handleDpadTouch(e.localPosition, dpadSize),
        onPointerMove:
            (e) =>
                _handleDpadTouch(e.localPosition, dpadSize),
        onPointerUp: (_) => _resetDpadStates(),
        onPointerCancel: (_) => _resetDpadStates(),
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
              // Up（描画のみ。入力は親の Listener が即時に処理する）
              Positioned(
                top: 0,
                child: IgnorePointer(
                  child: DirectionButton(
                    icon: Icons.arrow_circle_up_outlined,
                    onPressed: (_) {}, // 親で処理
                    stateNotifier: GameUI._upButtonStateNotifier,
                    buttonSize: buttonSize,
                    iconSize: iconSize,
                  ),
                ),
              ),
              // Down
              Positioned(
                bottom: 0,
                child: IgnorePointer(
                  child: DirectionButton(
                    icon: Icons.arrow_circle_down_outlined,
                    onPressed: (_) {},
                    stateNotifier: GameUI._downButtonStateNotifier,
                    buttonSize: buttonSize,
                    iconSize: iconSize,
                  ),
                ),
              ),
              // Left
              Positioned(
                left: 0,
                child: IgnorePointer(
                  child: DirectionButton(
                    icon: Icons.arrow_circle_left_outlined,
                    onPressed: (_) {},
                    stateNotifier: GameUI._leftButtonStateNotifier,
                    buttonSize: buttonSize,
                    iconSize: iconSize,
                  ),
                ),
              ),
              // Right
              Positioned(
                right: 0,
                child: IgnorePointer(
                  child: DirectionButton(
                    icon: Icons.arrow_circle_right_outlined,
                    onPressed: (_) {},
                    stateNotifier: GameUI._rightButtonStateNotifier,
                    buttonSize: buttonSize,
                    iconSize: iconSize,
                  ),
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
    if (GameUI._rightButtonStateNotifier.value ==
        DirectionButtonState.pressed) {
      GameUI._rightButtonStateNotifier.value = DirectionButtonState.normal;
    }
    // _updateUpButtonStateなどはPlayer側で定期的に呼ばれるか、listenerで同期される
  }

  Widget _buildActionButtons(double fontSize) {
    final buttonSize = widget.screenSize.width * 0.07;
    final iconSize = widget.screenSize.width * 0.05;
    final actionHGapW = widget.screenSize.width * 0.03;
    final actionRowGapH = widget.screenSize.width * 0.02;

    return Positioned(
      right: widget.screenSize.width * 0.05,
      bottom: widget.screenSize.height * 0.1,
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.game.player.isCarryingItemNotifier,
        builder: (context, isCarrying, child) {
          if (isCarrying) {
            return _buildCarryingActionButtons(
              buttonSize,
              iconSize,
              actionHGapW,
              actionRowGapH,
            );
          } else {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    SizedBox(width: actionHGapW),
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
                ),
                SizedBox(height: actionRowGapH),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<String?>(
                      valueListenable: GameUI._equippedItemNameNotifier,
                      builder: (context, itemName, child) {
                        if (itemName == null) {
                          return const SizedBox.shrink();
                        }
                        final item = widget.game.itemBag.items[itemName];
                        if (item == null) return const SizedBox.shrink();
                        return AnimatedBuilder(
                          animation: widget.game.itemBag,
                          builder: (context, child) {
                            final count = widget.game.itemBag.getItemCount(
                              itemName,
                            );
                            return Row(
                              mainAxisSize: MainAxisSize.min,
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
                                      GameUI
                                          ._equippedItemUseButtonStateNotifier,
                                  buttonSize: buttonSize,
                                  iconSize: iconSize,
                                ),
                                SizedBox(width: actionHGapW),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    ActionButton(
                      icon: Icons.keyboard_double_arrow_down_sharp,
                      onTogglePressed: (isPressed) {
                        widget.game.player.toggleDigging(isPressed);
                      },
                      stateNotifier: GameUI._digButtonStateNotifier,
                      buttonSize: buttonSize,
                      iconSize: iconSize,
                    ),
                  ],
                ),
              ],
            );
          }
        },
      ),
    );
  }

  // 運搬モード時のアクションボタン
  Widget _buildCarryingActionButtons(
    double buttonSize,
    double iconSize,
    double actionHGapW,
    double actionRowGapH,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
        ),
        SizedBox(height: actionRowGapH),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            SizedBox(width: actionHGapW),
            ActionButton(
              icon:
                  widget.game.player.iscrouching
                      ? Icons.place_outlined
                      : Icons.arrow_forward_outlined,
              onPressed: () {
                if (widget.game.player.carriedItem != null) {
                  final carriedItem = widget.game.player.carriedItem!;
                  final player = widget.game.player;
                  player.velocity.x.abs() > 10.0
                      ? player.throwWorldObject(carriedItem)
                      : player.placeWorldObject(carriedItem);
                }
              },
              stateNotifier: GameUI._placeButtonStateNotifier,
              buttonSize: buttonSize,
              iconSize: iconSize,
            ),
            SizedBox(width: buttonSize),
          ],
        ),
      ],
    );
  }

  /// §7 — 三種残滓の比率バー（赤＝生命・青＝歴史・灰＝無機）。残滓ゼロ時は空トラック。
  /// ラベルは [_buildCargoHudBlock] 側。
  Widget _buildCargoRatioBar(double fontSize) {
    return AnimatedBuilder(
      animation: widget.game.gameRuntimeState,
      builder: (context, child) {
        final state = widget.game.gameRuntimeState;
        final t = state.totalCargoCount;
        final life = state.cargoLifeCount;
        final hist = state.cargoHistoryCount;
        final ino = state.cargoInorganicCount;

        final Widget track;
        if (t <= 0) {
          track = Row(
            children: [
              Expanded(
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ],
          );
        } else {
          track = Row(
            children: [
              if (life > 0)
                Expanded(
                  flex: life,
                  child: Container(color: Colors.redAccent.shade200),
                ),
              if (hist > 0)
                Expanded(
                  flex: hist,
                  child: Container(color: Colors.lightBlue.shade300),
                ),
              if (ino > 0)
                Expanded(
                  flex: ino,
                  child: Container(color: Colors.blueGrey.shade500),
                ),
            ],
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            key: _cargoRatioBarKey,
            height: math.max(8.0, fontSize * 0.45),
            width: double.infinity,
            child: track,
          ),
        );
      },
    );
  }

  Widget _buildHpBarContent(double fontSize) {
    final barHeight = math.max(6.0, fontSize * 0.42);

    return AnimatedBuilder(
      animation: widget.game.gameRuntimeState,
      builder: (context, _) {
        final state = widget.game.gameRuntimeState;
        final bonus = state.hpBonus * state.hpCalibrationScale;
        final effectiveMaxIntegrity = (widget.game.player.maxIntegrity + bonus)
            .clamp(1.0, 1e9);

        final inset = _statusHudBlockPadding(fontSize);
        final headerGap = inset.left * 0.6;
        final chipPad = headerGap.clamp(4.0, 10.0);

        Widget hudBar({
          required Widget trackBackground,
          required ValueListenableBuilder<double> fillBuilder,
        }) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: barHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [trackBackground, fillBuilder],
              ),
            ),
          );
        }

        return Container(
          padding: inset,
          decoration: BoxDecoration(
            color: const Color(0xFF0c1210),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF2e7d32).withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1b5e20).withValues(alpha: 0.22),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: chipPad,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF143822),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF43a047).withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      'Integrity',
                      style: TextStyle(
                        fontSize: fontSize * 0.72,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                        letterSpacing: 1.2,
                        color: const Color(0xFFc8e6c9),
                      ),
                    ),
                  ),
                  SizedBox(width: headerGap),
                  Expanded(
                    child: ValueListenableBuilder<double>(
                      valueListenable: widget.game.player.integrityNotifier,
                      builder: (context, current, child) {
                        final shown = GameRuntimeState.quantizeIntegrityHalf(
                          current,
                        );
                        final maxShown = GameRuntimeState.quantizeIntegrityHalf(
                          effectiveMaxIntegrity,
                        );
                        return Text(
                          '${shown.toInt()} / ${maxShown.toInt()}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: fontSize * 0.85,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                            letterSpacing: 0.5,
                            color: const Color(0xFF81c784),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: fontSize * 0.35),
              hudBar(
                trackBackground: const ColoredBox(color: Color(0xFF152620)),
                fillBuilder: ValueListenableBuilder<double>(
                  valueListenable: widget.game.player.integrityNotifier,
                  builder: (context, current, _) {
                    final ratio = (current / effectiveMaxIntegrity).clamp(
                      0.0,
                      1.0,
                    );
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: ratio,
                        heightFactor: 1,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF1b5e20), Color(0xFF66bb6a)],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: fontSize * 0.35),
              hudBar(
                trackBackground: const ColoredBox(color: Color(0xFF151022)),
                fillBuilder: ValueListenableBuilder<double>(
                  valueListenable: widget.game.player.stressNotifier,
                  builder: (context, currentStress, _) {
                    final cap = widget.game.player.effectiveMaxStress;
                    final ratio =
                        cap > 1e-9
                            ? (currentStress / cap).clamp(0.0, 1.0)
                            : 0.0;
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: ratio,
                        heightFactor: 1,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color.fromARGB(255, 40, 25, 95),
                                Color.fromARGB(255, 110, 80, 210),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: fontSize * 0.28),
              ValueListenableBuilder<double>(
                valueListenable: widget.game.player.stressNotifier,
                builder: (context, stress, _) {
                  final cap = widget.game.player.effectiveMaxStress;
                  final pct =
                      cap > 1e-9
                          ? ((stress / cap) * 100).clamp(0, 100).round()
                          : 0;
                  final high = cap > 1e-9 && stress >= cap * 0.8;
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Stress: $pct %',
                      style: TextStyle(
                        fontSize: fontSize * 0.78,
                        fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                        letterSpacing: 0.5,
                        shadows:
                            high
                                ? [
                                  Shadow(
                                    color: Colors.red.withValues(alpha: 0.65),
                                    blurRadius: 6,
                                  ),
                                ]
                                : null,
                        color:
                            high
                                ? Colors.redAccent.shade100
                                : const Color.fromARGB(230, 149, 117, 222),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDigitalClockContent(double fontSize) {
    final blockPad = _statusHudBlockPadding(fontSize);
    final dateTimeGap = blockPad.left * 1.2;
    final clockFontSize = fontSize * 1.2;

    return Container(
      padding: blockPad,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(10),
      ),
      child: AnimatedBuilder(
        animation: widget.timeService,
        builder: (context, child) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.timeService.getFormattedDay(),
                  style: TextStyle(
                    fontSize: clockFontSize,
                    fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                    letterSpacing: 5,
                    color: Colors.greenAccent.shade700,
                  ),
                ),
              ),
              SizedBox(width: dateTimeGap),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.timeService.getFormattedTime(),
                  style: TextStyle(
                    fontSize: clockFontSize,
                    fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                    letterSpacing: 5,
                    color: Colors.greenAccent.shade700,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPointsContent(double fontSize) {
    final blockPad = _statusHudBlockPadding(fontSize);
    final iconTextGap = blockPad.left * 0.6;
    final groupGap = blockPad.left * 1.5;
    final iconSize = fontSize * 1.5;
    final pointFontSize = fontSize;

    return Container(
      padding: blockPad,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: widget.game.player.currencyNotifier,
            builder: (context, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/money.png',
                    width: iconSize,
                    height: iconSize,
                  ),
                  SizedBox(width: iconTextGap),
                  Text(
                    '${widget.game.player.currencyNotifier.value}',
                    style: TextStyle(
                      fontSize: pointFontSize,
                      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
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
          SizedBox(width: groupGap),
          AnimatedBuilder(
            animation: widget.game.player.miningPointsNotifier,
            builder: (context, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/shovel.png',
                    width: iconSize,
                    height: iconSize,
                  ),
                  SizedBox(width: iconTextGap),
                  Text(
                    '${widget.game.player.currentMiningPoints}',
                    style: TextStyle(
                      fontSize: pointFontSize,
                      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
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
  }

  Widget _buildAutomationShopEntryButton(
    double fontSize, {
    double uiScale = 1.0,
  }) {
    return AnimatedBuilder(
      animation: widget.game.gameRuntimeState,
      builder: (context, _) {
        final s = widget.game.gameRuntimeState;
        if (!s.showAutomationShopEntryInHud) {
          return const SizedBox.shrink();
        }
        final highlight = s.automationContractC2;
        return ElevatedButton(
          onPressed: () {
            widget.windowManager.showWindow(
              GameWindowType.automationShop,
              AutomationShopWindow(
                game: widget.game,
                windowManager: widget.windowManager,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor:
                highlight ? Colors.deepPurple.shade800 : Colors.teal.shade900,
            padding: EdgeInsets.all(widget.screenSize.width * 0.01 * uiScale),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25 * uiScale),
            ),
            side: BorderSide(
              color: highlight ? Colors.purpleAccent : Colors.tealAccent,
            ),
          ),
          child: Icon(
            Icons.smart_toy_outlined,
            color: Colors.white,
            size: widget.screenSize.width * 0.06 * uiScale,
          ),
        );
      },
    );
  }

  bool _anyRecipeCraftable() {
    final bag = widget.game.itemBag;
    final state = widget.game.gameRuntimeState;
    for (final recipe in CraftingSystem.recipes) {
      if (CraftingSystem.canCraft(recipe, bag, state)) return true;
    }
    return false;
  }

  Widget _buildCraftingButton(double fontSize, {double uiScale = 1.0}) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.game.itemBag,
        widget.game.gameRuntimeState,
      ]),
      builder: (context, _) {
        final canCraftAny = _anyRecipeCraftable();
        return ElevatedButton(
          onPressed: () {
            widget.windowManager.showWindow(
              GameWindowType.crafting,
              CraftingWindow(
                windowManager: widget.windowManager,
                itemBag: widget.game.itemBag,
                state: widget.game.gameRuntimeState,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: canCraftAny
                ? Colors.indigo.shade900
                : Colors.blueGrey.shade800,
            padding: EdgeInsets.all(widget.screenSize.width * 0.01 * uiScale),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25 * uiScale),
            ),
            side: BorderSide(
              color: canCraftAny
                  ? Colors.indigoAccent
                  : Colors.blueGrey.shade600,
            ),
          ),
          child: Icon(
            Icons.handyman_outlined,
            color: canCraftAny ? Colors.white : Colors.white54,
            size: widget.screenSize.width * 0.06 * uiScale,
          ),
        );
      },
    );
  }

  Widget _buildCodexButton(double fontSize, {double uiScale = 1.0}) {
    return ElevatedButton(
      onPressed: () {
        widget.windowManager.showWindow(
          GameWindowType.codex,
          CodexWindow(game: widget.game, windowManager: widget.windowManager),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.indigo.shade900,
        padding: EdgeInsets.all(widget.screenSize.width * 0.01 * uiScale),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25 * uiScale),
        ),
      ),
      child: Icon(
        Icons.menu_book_outlined,
        color: Colors.white,
        size: widget.screenSize.width * 0.06 * uiScale,
      ),
    );
  }

  Widget _buildPauseButton(double fontSize, {double uiScale = 1.0}) {
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
        padding: EdgeInsets.all(widget.screenSize.width * 0.01 * uiScale),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25 * uiScale),
        ),
      ),
      child: Icon(
        Icons.pause,
        color: Colors.white,
        size: widget.screenSize.width * 0.06 * uiScale,
      ),
    );
  }

  Widget _buildItemBagButton(double fontSize, {double uiScale = 1.0}) {
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
        padding: EdgeInsets.all(widget.screenSize.width * 0.01 * uiScale),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25 * uiScale),
        ),
      ),
      child: Icon(
        Icons.backpack,
        color: Colors.white,
        size: widget.screenSize.width * 0.06 * uiScale,
      ),
    );
  }

  Widget _buildTopRightButtons(double fontSize) {
    const double uiScale = 2.0 / 3.0 * 0.75;
    final double gap = widget.screenSize.height * 0.01 * uiScale;
    return Positioned(
      top: widget.screenSize.height * 0.02,
      right: widget.screenSize.width * 0.02,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTestTextBoxButton(fontSize, uiScale: uiScale),
          SizedBox(width: gap),
          _buildItemBagButton(fontSize, uiScale: uiScale),
          SizedBox(width: gap),
          _buildCraftingButton(fontSize, uiScale: uiScale),
          SizedBox(width: gap),
          _buildCodexButton(fontSize, uiScale: uiScale),
          SizedBox(width: gap),
          _buildAutomationShopEntryButton(fontSize, uiScale: uiScale),
          SizedBox(width: gap),
          _buildPauseButton(fontSize, uiScale: uiScale),
        ],
      ),
    );
  }

  Widget _buildTestTextBoxButton(double fontSize, {double uiScale = 1.0}) {
    return ElevatedButton(
      onPressed: () {
        widget.windowManager.showWindow(
          GameWindowType.message,
          MessageWindow(
            messages: ['開発者の特権を使用します。(アイテムをランダムに生成する)'],
            fontSize: fontSize * uiScale,
            onClosed: () async {
              widget.windowManager.hideWindow();
              ItemFactory.spawnTestItems(widget.game, widget.game.player);
            },
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple,
        padding: EdgeInsets.all(widget.screenSize.width * 0.01 * uiScale),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25 * uiScale),
        ),
      ),
      child: Icon(
        Icons.text_fields,
        color: Colors.white,
        size: widget.screenSize.width * 0.06 * uiScale,
      ),
    );
  }
}

/// [GameRuntimeState.currentMission] 用の簡易スタイル（`mission_manager` 廃止後の代替）。
double _missionHudErosionRate(Player player) {
  final m = player.maxIntegrity;
  if (m <= 0) return 0;
  return (1.0 - (player.currentIntegrity / m)).clamp(0.0, 1.0);
}

class _MissionHudStyle {
  final Color bgColor;
  final Color color;
  final String iconPath;
  final bool isOperator;
  final bool hasTerminalShadow;
  final double fontSizeScale;

  const _MissionHudStyle({
    required this.bgColor,
    required this.color,
    required this.iconPath,
    required this.isOperator,
    required this.hasTerminalShadow,
    required this.fontSizeScale,
  });

  static _MissionHudStyle fromMissionText(String? mission) {
    final text = mission ?? '';
    final operatorStyle =
        text.contains('運用') || text.contains('父') || text.contains('オペレーター');
    if (operatorStyle) {
      return const _MissionHudStyle(
        bgColor: Color(0xFF1a237e),
        color: Colors.white,
        iconPath: 'operator_face.png',
        isOperator: true,
        hasTerminalShadow: false,
        fontSizeScale: 1.05,
      );
    }
    return const _MissionHudStyle(
      bgColor: Colors.black87,
      color: Color(0xFF64FFDA),
      iconPath: 'terminal_hint.png',
      isOperator: false,
      hasTerminalShadow: true,
      fontSizeScale: 0.95,
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

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {
            if (widget.stateNotifier.value == DirectionButtonState.disabled) {
              return;
            }
            widget.onPressed(true);
            widget.stateNotifier.value = DirectionButtonState.pressed;
          },
          onPointerUp: (_) {
            if (widget.stateNotifier.value == DirectionButtonState.disabled) {
              return;
            }
            widget.onPressed(false);
            widget.stateNotifier.value = DirectionButtonState.normal;
          },
          onPointerCancel: (_) {
            if (widget.stateNotifier.value == DirectionButtonState.disabled) {
              return;
            }
            widget.onPressed(false);
            widget.stateNotifier.value = DirectionButtonState.normal;
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

        final tactile = Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {
            if (widget.stateNotifier.value == ActionButtonState.disabled) {
              return;
            }
            if (widget.onTogglePressed != null) {
              widget.onTogglePressed!(true);
              widget.stateNotifier.value = ActionButtonState.pressed;
            } else if (widget.onPressed != null) {
              widget.onPressed!();
            }
          },
          onPointerUp: (_) {
            if (widget.onTogglePressed == null) return;
            if (widget.stateNotifier.value == ActionButtonState.disabled) {
              return;
            }
            widget.onTogglePressed!(false);
            widget.stateNotifier.value = ActionButtonState.normal;
          },
          onPointerCancel: (_) {
            if (widget.onTogglePressed == null) return;
            if (widget.stateNotifier.value == ActionButtonState.disabled) {
              return;
            }
            widget.onTogglePressed!(false);
            widget.stateNotifier.value = ActionButtonState.normal;
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
                          fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

        if (widget.onLongPress != null) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: () {
              if (widget.stateNotifier.value == ActionButtonState.disabled) {
                return;
              }
              widget.onLongPress!();
            },
            child: tactile,
          );
        }
        return tactile;
      },
    );
  }
}
