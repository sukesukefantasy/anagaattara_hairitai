import 'package:flutter/material.dart';
import '../main.dart';
import '../game_manager/time_service.dart';
import 'window_manager.dart';
import 'windows/pause_window.dart';
import 'windows/message_window.dart';
import 'windows/item_bag_window.dart';
import 'package:flame/components.dart';
import '../component/item/item.dart';

class GameUI extends StatefulWidget {
  final Size screenSize;
  final VoidCallback onPressedJumpButton;
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
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    // playerの初期化を待つ
    while (!mounted || widget.game.player == null) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (mounted) {
      setState(() => _isPlayerInitialized = true);
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

  @override
  Widget build(BuildContext context) {
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
          _buildStatusDisplay(),
          _buildDirectionalButtons(),
          _buildActionButtons(), // アクションボタン
          _buildTopRightButtons(), // ポーズボタンとアイテムバッグボタンをグループ化
        ],
      ],
    );
  }

  Widget _buildStatusDisplay() {
    return Positioned(
      top: widget.screenSize.height * 0.02, // 画面高さの2%
      left: widget.screenSize.width * 0.02, // 画面幅の2%
      width: widget.screenSize.width * 0.3, // 画面幅の35%
      height: widget.screenSize.height * 0.3, // 画面高さの30%に増加
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: _buildHpBarContent()), // flexを5から6に増やす
          Expanded(
            flex: 2,
            child: _buildDigitalClockContent(),
          ), // flexを2から1に減らす
          Expanded(flex: 2, child: _buildPointsContent()),
        ],
      ),
    );
  }

  Widget _buildDirectionalButtons() {
    return Positioned(
      left: widget.screenSize.width * 0.05, // 画面幅の5%
      bottom: widget.screenSize.height * 0.05, // 画面高さの5%
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DirectionButton(
            icon: Icons.arrow_circle_up_outlined,
            onPressed: (isPressed) {
              if (widget.game.player != null) {
                GameUI._upButtonPressedNotifier.value = isPressed;
              }
            },
            stateNotifier: GameUI._upButtonStateNotifier,
            buttonSize: widget.screenSize.width * 0.07, // 画面幅の7%
            iconSize: widget.screenSize.width * 0.05, // 画面幅の5%
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DirectionButton(
                icon: Icons.arrow_circle_left_outlined,
                onPressed: (isPressed) {
                  if (widget.game.player != null) {
                    GameUI._leftButtonPressedNotifier.value = isPressed;
                  }
                },
                stateNotifier: GameUI._leftButtonStateNotifier,
                buttonSize: widget.screenSize.width * 0.07, // 画面幅の7%
                iconSize: widget.screenSize.width * 0.05, // 画面幅の5%
              ),
              SizedBox(width: widget.screenSize.width * 0.07), // 画面幅の7%
              DirectionButton(
                icon: Icons.arrow_circle_right_outlined,
                onPressed: (isPressed) {
                  if (widget.game.player != null) {
                    GameUI._rightButtonPressedNotifier.value = isPressed;
                  }
                },
                stateNotifier: GameUI._rightButtonStateNotifier,
                buttonSize: widget.screenSize.width * 0.07, // 画面幅の7%
                iconSize: widget.screenSize.width * 0.05, // 画面幅の5%
              ),
            ],
          ),
          DirectionButton(
            icon: Icons.arrow_circle_down_outlined,
            onPressed: (isPressed) {
              if (widget.game.player != null) {
                GameUI._downButtonPressedNotifier.value = isPressed;
              }
            },
            stateNotifier: GameUI._downButtonStateNotifier,
            buttonSize: widget.screenSize.width * 0.07, // 画面幅の7%
            iconSize: widget.screenSize.width * 0.05, // 画面幅の5%
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      right: widget.screenSize.width * 0.05, // 画面幅の5%
      bottom: widget.screenSize.height * 0.1, // 画面高さの10%
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.game.player!.isCarryingItemNotifier,
        builder: (context, isCarrying, child) {
          if (isCarrying) {
            return _buildCarryingActionButtons(); // 運搬モードのボタンを表示
          } else {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dig Button
                ActionButton(
                  icon: Icons.keyboard_double_arrow_down_sharp,
                  onTogglePressed: (isPressed) {
                    if (widget.game.player != null) {
                      widget.game.player.toggleDigging(isPressed);
                    }
                  },
                  stateNotifier: GameUI._digButtonStateNotifier,
                  buttonSize: widget.screenSize.width * 0.07, // 画面幅の7%
                  iconSize: widget.screenSize.width * 0.05, // 画面幅の5%
                ),
                SizedBox(width: widget.screenSize.width * 0.03), // 画面幅の3%
                // Interact Button
                ValueListenableBuilder<(VoidCallback, IconData)?>(
                  valueListenable: GameUI.interactActionNotifier,
                  builder: (context, interaction, child) {
                    return ActionButton(
                      icon: interaction?.$2, // interactActionNotifierからアイコンを取得
                      onPressed: interaction?.$1,
                      stateNotifier: GameUI._interactButtonStateNotifier,
                      iconNotifier: GameUI._interactButtonIconNotifier,
                      buttonSize: widget.screenSize.width * 0.07, // 画面幅の7%
                      iconSize: widget.screenSize.width * 0.05, // 画面幅の5%
                    );
                  },
                ),
                SizedBox(width: widget.screenSize.width * 0.03), // 画面幅の3%
                // Jump Button
                ActionButton(
                  icon: Icons.keyboard_double_arrow_up,
                  onPressed: widget.onPressedJumpButton,
                  stateNotifier: GameUI._jumpButtonStateNotifier,
                  buttonSize: widget.screenSize.width * 0.07, // 画面幅の7%
                  iconSize: widget.screenSize.width * 0.05, // 画面幅の5%
                ),
              ],
            );
          }
        },
      ),
    );
  }

  // 運搬モード時のアクションボタン
  Widget _buildCarryingActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 収納ボタン
        ActionButton(
          icon: Icons.backpack_outlined,
          onPressed: () {
            debugPrint('GameUI: 収納ボタンが押されました。');
            if (widget.game.player!.carriedItem != null) {
              final carriedItem = widget.game.player!.carriedItem!;
              debugPrint('GameUI: 収納するアイテム: ${carriedItem.name}');
              widget.game.player!.itemBag.addItem(
                carriedItem,
              ); // アイテムをインベントリに戻す
              widget.game.player!.stopCarrying(); // 運搬を終了
            } else {
              debugPrint('GameUI: 運搬中のアイテムがありません。');
            }
            debugPrint('GameUI: 収納ボタン処理終了。');
          },
          stateNotifier: GameUI._storeButtonStateNotifier,
          buttonSize: widget.screenSize.width * 0.07, // 画面幅の7%
          iconSize: widget.screenSize.width * 0.05, // 画面幅の5%
        ),
        SizedBox(width: widget.screenSize.width * 0.06), // 画面幅の6%
        // 配置ボタン
        ActionButton(
          icon:
              widget.game.player!.iscrouching
                  ? Icons.place_outlined
                  : Icons.arrow_forward_outlined,
          onPressed: () {
            if (widget.game.player!.carriedItem != null) {
              final carriedItem = widget.game.player!.carriedItem!;
              final player = widget.game.player!;
              player.velocity != Vector2.zero()
                  ? player.throwWorldObject(carriedItem)
                  : player.placeWorldObject(carriedItem);
            }
            debugPrint('配置ボタンが押されました');
          },
          stateNotifier: GameUI._placeButtonStateNotifier,
          buttonSize: widget.screenSize.width * 0.07, // 画面幅の7%
          iconSize: widget.screenSize.width * 0.05, // 画面幅の5%
        ),
        SizedBox(width: widget.screenSize.width * 0.03), // 画面幅の3%
        // Jump Button
        ActionButton(
          icon: Icons.keyboard_double_arrow_up,
          onPressed: widget.onPressedJumpButton,
          stateNotifier: GameUI._jumpButtonStateNotifier,
          buttonSize: widget.screenSize.width * 0.07, // 画面幅の7%
          iconSize: widget.screenSize.width * 0.05, // 画面幅の5%
        ),
      ],
    );
  }

  Widget _buildHpBarContent() {
    if (widget.game.player == null) {
      return Container(); // playerがnullの場合は空のコンテナを返す
    }
    return Container(
      padding: EdgeInsets.fromLTRB(
        widget.screenSize.width * 0.01,
        widget.screenSize.height * 0.01,
        widget.screenSize.width * 0.01,
        widget.screenSize.height * 0.005,
      ), // 画面幅の1%
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
                // Expandedを追加
                flex: 1,
                child: SizedBox(
                  height: widget.screenSize.height * 0.01, // HPゲージの高さを調整
                  child: ValueListenableBuilder<double>(
                    valueListenable: widget.game.player!.hpNotifier,
                    builder: (context, currentHp, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: currentHp / widget.game.player!.maxHp,
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
                // Expandedを追加
                flex: 1,
                child: SizedBox(
                  height: widget.screenSize.height * 0.01, // ストレスゲージの高さを調整
                  child: ValueListenableBuilder<double>(
                    valueListenable: widget.game.player!.stressNotifier,
                    builder: (context, currentStress, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor:
                            currentStress / widget.game.player!.maxStress,
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
                // Expandedを追加
                flex: 5, // テキスト部分により多くのスペースを与える
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        constraints.maxWidth * 0.03, // 親の幅の3%
                        0,
                        constraints.maxWidth * 0.03, // 親の幅の3%
                        0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Health',
                        style: TextStyle(
                          fontSize: widget.screenSize.width * 0.012,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'TRS-Million-Rg',
                          letterSpacing: 5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        constraints.maxWidth * 0.03, // 親の幅の3%
                        0,
                        constraints.maxWidth * 0.03, // 親の幅の3%
                        0,
                      ),
                      child: ValueListenableBuilder<double>(
                        valueListenable: widget.game.player!.hpNotifier,
                        builder: (context, currentHp, child) {
                          return Text(
                            '${currentHp.toInt()}',
                            style: TextStyle(
                              fontSize: widget.screenSize.width * 0.012,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'TRS-Million-Rg',
                              letterSpacing: 5,
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
                // Expandedを追加
                flex: 5, // テキスト部分により多くのスペースを与える
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        constraints.maxWidth * 0.03, // 親の幅の3%
                        0,
                        constraints.maxWidth * 0.03, // 親の幅の3%
                        0,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(122, 61, 32, 230),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Stress',
                        style: TextStyle(
                          fontSize: widget.screenSize.width * 0.012,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'TRS-Million-Rg',
                          letterSpacing: 5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        constraints.maxWidth * 0.03, // 親の幅の3%
                        0,
                        constraints.maxWidth * 0.03, // 親の幅の3%
                        0,
                      ),
                      child: ValueListenableBuilder<double>(
                        valueListenable: widget.game.player!.stressNotifier,
                        builder: (context, currentStress, child) {
                          return Text(
                            '${currentStress.toInt()} / ${widget.game.player!.maxStress.toInt()}',
                            style: TextStyle(
                              fontSize: widget.screenSize.width * 0.012,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'TRS-Million-Rg',
                              letterSpacing: 5,
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

  Widget _buildDigitalClockContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = constraints.maxHeight * 0.6;
        return Container(
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
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth * 0.03,
                    ), // 親の幅の3%
                    child: FittedBox(
                      child: Text(
                        widget.timeService.getFormattedDay(),
                        style: TextStyle(
                          fontSize: fontSize,
                          fontFamily: 'TRS-Million-Rg',
                          letterSpacing: 5,
                          color: Colors.greenAccent.shade700,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth * 0.03,
                    ), // 親の幅の3%
                    child: FittedBox(
                      child: Text(
                        widget.timeService.getFormattedTime(),
                        style: TextStyle(
                          fontSize: fontSize,
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

  Widget _buildPointsContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = constraints.maxHeight * 0.8;
        final fontSize = constraints.maxHeight * 0.4;

        return Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: widget.game.player!.currencyNotifier,
                builder: (context, child) {
                  return Row(
                    children: [
                      Image.asset(
                        'assets/images/money.png',
                        width: iconSize,
                        height: iconSize,
                      ),
                      SizedBox(width: constraints.maxWidth * 0.02), // 親の幅の2%
                      Text(
                        '${widget.game.player!.currencyNotifier.value}',
                        style: TextStyle(
                          fontSize: fontSize,
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
                animation: widget.game.player!.miningPointsNotifier,
                builder: (context, child) {
                  return Row(
                    children: [
                      Image.asset(
                        'assets/images/shovel.png',
                        width: iconSize,
                        height: iconSize,
                      ),
                      SizedBox(width: constraints.maxWidth * 0.02), // 親の幅の2%
                      Text(
                        '${widget.game.player!.currentMiningPoints}',
                        style: TextStyle(
                          fontSize: fontSize,
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

  Widget _buildPauseButton() {
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
        padding: EdgeInsets.all(widget.screenSize.width * 0.02), // 画面幅の2%
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Icon(
        Icons.pause,
        color: Colors.white,
        size: widget.screenSize.width * 0.03,
      ),
    );
  }

  Widget _buildItemBagButton() {
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
        backgroundColor: const Color.fromARGB(255, 141, 75, 0), // アイテムバッグの色
        padding: EdgeInsets.all(widget.screenSize.width * 0.02), // 画面幅の2%
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Icon(
        Icons.backpack, // アイテムバッグのアイコン
        color: Colors.white,
        size: widget.screenSize.width * 0.03,
      ),
    );
  }

  // ポーズボタンとアイテムバッグボタンをグループ化する新しいメソッド
  Widget _buildTopRightButtons() {
    return Positioned(
      top: widget.screenSize.height * 0.02, // 画面高さの2%
      right: widget.screenSize.width * 0.02, // 画面幅の2% (右端に配置)
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPauseButton(), // ポーズボタン
          SizedBox(height: widget.screenSize.height * 0.01), // ボタン間のスペース
          _buildItemBagButton(), // アイテムバッグボタン
          SizedBox(height: widget.screenSize.height * 0.01), // ボタン間のスペース
          _buildTestTextBoxButton(), // テスト用のテキストボックス表示ボタン
        ],
      ),
    );
  }

  Widget _buildTestTextBoxButton() {
    return ElevatedButton(
      onPressed: () {
        widget.windowManager.showWindow(
          GameWindowType.message,
          MessageWindow(
            messages: ['開発者の特権を使用します。(アイテムをランダムに生成する)'],
            onFinish: () {
              widget.windowManager.hideWindow();
              // テスト用アイテムの生成
              Item.spawnTestItems(widget.game, widget.game.player!);
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
                    return Icon(
                      iconData,
                      size: widget.iconSize, // 可変サイズ
                      color: Colors.white.withOpacity(opacity),
                    );
                  },
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
