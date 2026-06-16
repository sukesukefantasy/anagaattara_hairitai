import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../../UI/window_manager.dart';
import '../../../../UI/windows/automation_menu_window.dart';
import '../../../../game/world_scale.dart';
import '../../../../main.dart';
import '../../../../system/automation_fuel.dart';
import '../../../../system/automation_shop_grade.dart';
import '../../../../system/automation_tool_kind.dart';
import '../../../../system/farm_role_profile.dart';
import '../../../../system/storage/game_runtime_state.dart';
import '../../../common/hitboxes/interact_hitbox.dart';

/// 3種自動化装置の共通基底。
abstract class AutomationToolBase extends PositionComponent
    with HasGameReference<MyGame>, CollisionCallbacks {
  final AutomationToolKind kind;
  final String instanceId;

  SpriteComponent? _sprite;
  RectangleComponent? _pulseOverlay;
  TextComponent? _label;
  double _pulseTimer = 0;

  AutomationToolBase({
    required this.kind,
    required this.instanceId,
    required super.position,
    Vector2? toolSize,
  }) : super(
         anchor: Anchor.bottomCenter,
         size: toolSize ?? Vector2(40, 40),
       );

  @override
  Future<void> onLoad() async {
    priority = WorldScale.outdoorAutomationKitRenderPriority;
    await super.onLoad();
    try {
      final sprite = await Sprite.load(kind.spriteAsset);
      _sprite = SpriteComponent(sprite: sprite, size: size);
      add(_sprite!);
    } catch (_) {
      add(
        RectangleComponent(
          size: size,
          paint: Paint()..color = const Color(0xFF2a2a4e),
        ),
      );
    }
    _pulseOverlay = RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.transparent,
    );
    add(_pulseOverlay!);
    _label = TextComponent(
      text: kind.displayLabel,
      position: Vector2(size.x / 2, size.y + 4),
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.tealAccent,
          fontSize: 8,
          fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
        ),
      ),
    );
    add(_label!);
    add(
      InteractHitbox(
        size: Vector2(size.x + 20, size.y + 20),
        position: Vector2(-10, -10),
        onInteract: _onInteract,
        icon: _interactIconFor(kind),
      ),
    );
    onToolLoaded();
  }

  void onToolLoaded() {}

  static IconData _interactIconFor(AutomationToolKind kind) => switch (kind) {
        AutomationToolKind.harvest => Icons.download_rounded,
        AutomationToolKind.upkeep => Icons.build_circle_outlined,
        AutomationToolKind.ward => Icons.shield_outlined,
      };

  void setDisplayLabel(String text) {
    _label?.text = text;
  }

  @override
  void update(double dt) {
    super.update(dt);
    game.gameRuntimeState.tickFarmInterventionWindow(dt);
    _pulseTimer += dt;
    _updatePulse();
    state.tickToolFuel(kind, dt);
    if (!state.canToolOperate(kind)) {
      if (!state.toolsRunWithoutFuelTank) {
        setDisplayLabel('${kind.displayLabel}（燃料切れ）');
      }
      return;
    }
    tickTool(dt);
  }

  void tickTool(double dt);

  Color pulseColor();

  void _updatePulse() {
    final pulse = (sin(_pulseTimer * 2.0) + 1) / 2;
    final c = pulseColor();
    _pulseOverlay?.paint.color = c.withValues(alpha: pulse * 0.45);
  }

  void _onInteract() {
    final wm = game.windowManager;
    wm.showWindow(
      GameWindowType.automationMenu,
      AutomationMenuWindow(
        game: game,
        windowManager: wm,
        initialTab: _shopTabForKind(kind),
      ),
    );
  }

  AutomationShopTab _shopTabForKind(AutomationToolKind kind) => switch (kind) {
        AutomationToolKind.harvest => AutomationShopTab.harvest,
        AutomationToolKind.upkeep => AutomationShopTab.upkeep,
        AutomationToolKind.ward => AutomationShopTab.ward,
      };

  void openAutomationShop() {
    final wm = game.windowManager;
    wm.hideWindow();
    wm.showWindow(
      GameWindowType.automationMenu,
      AutomationMenuWindow(
        game: game,
        windowManager: wm,
        initialTab: _shopTabForKind(kind),
      ),
    );
  }

  GameRuntimeState get state => game.gameRuntimeState;
}
