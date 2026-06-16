import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../farm_resource_cost_row.dart';
import '../farm_resource_icons.dart';
import '../widgets/automation_lock_overlay.dart';
import '../../system/automation_ability_catalog.dart';
import '../../system/automation_fuel.dart';
import '../../system/automation_fuel_rank.dart';
import '../../system/automation_tool_kind.dart';
import '../../system/automation_upgrade_entry.dart';
import '../../system/automation_shop_catalog.dart';
import '../../system/automation_shop_entry.dart';
import '../../system/automation_shop_grade.dart';
import '../../system/farm_resource_cost.dart';
import '../../system/farm_role_profile.dart';
import '../../system/storage/game_runtime_state.dart';
import '../../component/game_stage/building/automation/upkeep_automation_tool.dart';
import '../window_manager.dart';
import 'window_base.dart';

/// 統合されたオートメーションメニュー — 開放・強化・操作。
class AutomationMenuWindow extends StatefulWidget {
  final MyGame game;
  final WindowManager windowManager;
  final AutomationShopTab initialTab;

  const AutomationMenuWindow({
    super.key,
    required this.game,
    required this.windowManager,
    this.initialTab = AutomationShopTab.harvest,
  });

  @override
  State<AutomationMenuWindow> createState() => _AutomationMenuWindowState();
}

class _AutomationMenuWindowState extends State<AutomationMenuWindow>
    with SingleTickerProviderStateMixin, GameWindowResponsiveMixin {
  late TabController _tabController;

  static const _tabs = [
    AutomationShopTab.harvest,
    AutomationShopTab.upkeep,
    AutomationShopTab.ward,
    AutomationShopTab.common,
  ];

  @override
  void initState() {
    super.initState();
    final initialIndex = _tabs.indexOf(widget.initialTab);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex.clamp(0, _tabs.length - 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.game.gameRuntimeState, _tabController]),
      builder: (context, _) {
        final state = widget.game.gameRuntimeState;

        return Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 460,
              constraints: const BoxConstraints(maxHeight: 600),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101028).withValues(alpha: 0.96),
                border: Border.all(
                  color: Colors.cyanAccent.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(state),
                  const SizedBox(height: 8),
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.cyanAccent,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: Colors.cyanAccent,
                    tabs: [
                      for (final t in _tabs) Tab(text: t.label),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        for (final t in _tabs) _buildTabContent(state, t),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  TextButton(
                    onPressed: () => widget.windowManager.hideWindow(),
                    child: const Text('閉じる', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(GameRuntimeState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'オートメーションメニュー',
          style: TextStyle(
            color: Colors.cyanAccent.shade100,
            fontSize: widget.windowManager.fontSize + 2,
            fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '母星人間性: ${state.homePlanetHumanity.toStringAsFixed(0)} / 100',
              style: TextStyle(
                color: Colors.white70,
                fontSize: widget.windowManager.fontSize - 3,
                fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
              ),
            ),
            if (state.farmPrimaryRole != FarmPrimaryRole.none)
              Text(
                '主軸: ${state.farmPrimaryRoleLabel}',
                style: TextStyle(
                  color: Colors.tealAccent.shade100,
                  fontSize: widget.windowManager.fontSize - 3,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabContent(GameRuntimeState state, AutomationShopTab tab) {
    final entries = buildAutomationShopEntriesForTab(state, tab);
    final toolKind = _toolKindForTab(tab);
    final upgrades = toolKind != null ? buildAutomationUpgradeEntries(state, toolKind) : <AutomationUpgradeEntry>[];
    final isNear = toolKind != null && _isPlayerNearTool(state, toolKind);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (toolKind != null) ...[
            _buildToolStatusHeader(state, toolKind),
            const SizedBox(height: 12),
          ],
          
          _buildSectionTitle('能力開放 (ショップ)'),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('項目なし', style: TextStyle(color: Colors.white38, fontSize: 12)),
            )
          else
            for (final e in entries) _buildShopEntryTile(state, e),
            
          if (upgrades.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionTitle('パラメータ強化'),
            for (final u in upgrades) _buildUpgradeEntryTile(state, u),
          ],

          if (toolKind != null) ...[
            const SizedBox(height: 16),
            _buildSectionTitle('装置操作'),
            if (!isNear)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('※装置の近くでのみ操作可能です', style: TextStyle(color: Colors.orangeAccent, fontSize: 10)),
              ),
            ..._buildActionButtons(state, toolKind, isNear),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(width: 4, height: 14, color: Colors.cyanAccent),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolStatusHeader(GameRuntimeState state, AutomationToolKind kind) {
    final fuelLine = state.toolsRunWithoutFuelTank
        ? 'C-2 契約中 — 核から微量の意志を消費'
        : 'タンク: ${state.fuelForKind(kind).toStringAsFixed(0)} / ${state.maxFuelForKind(kind).toStringAsFixed(0)}'
            ' · ${state.tankFuelRankLabel(kind)}'
            ' · ${state.runningCostPerSecond(kind).toStringAsFixed(2)}/秒';

    final List<String> details = [];
    switch (kind) {
      case AutomationToolKind.harvest:
        details.add('ストレージ: ${state.harvestStorage.totalSlots} / ${state.harvestStorageCapacity()}');
        details.add('吸引半径: ${state.harvestVacuumRange().toStringAsFixed(0)}px');
        break;
      case AutomationToolKind.upkeep:
        details.add('稼働段階: ${state.automationKitStage}（2+=自動サイクル）');
        break;
      case AutomationToolKind.ward:
        details.add('攻撃力: ${state.wardMeleeDamage().toStringAsFixed(0)} / 射程 ${state.wardMeleeRange().toStringAsFixed(0)}');
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fuelLine, style: _subStyle()),
          for (final d in details) Text(d, style: _subStyle()),
        ],
      ),
    );
  }

  Widget _buildShopEntryTile(GameRuntimeState state, AutomationShopEntry entry) {
    final style = _styleForShopStatus(entry.status);
    final locked = entry.status == AutomationShopEntryStatus.locked;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: OutlinedButton(
        onPressed: entry.canTapPurchase
            ? () => _purchaseShopEntry(state, entry)
            : entry.canTapLockedHint
                ? () => _showLockedHint(entry)
                : null,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: style.border),
          backgroundColor: style.background,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: automationLockOverlay(
          locked: locked,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title,
                      style: TextStyle(
                        color: style.titleColor,
                        fontSize: widget.windowManager.fontSize - 1,
                        fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                      ),
                    ),
                  ),
                  _statusChip(entry.statusLabel, entry.status),
                ],
              ),
              FarmResourceCostRow(
                cost: resolveShopEntryCost(entry.id, state),
                fontSize: widget.windowManager.fontSize - 3,
                fallbackLabel: entry.costLabel,
                textColor: style.costColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpgradeEntryTile(GameRuntimeState state, AutomationUpgradeEntry entry) {
    final style = _styleForUpgradeStatus(entry.status);
    final locked = entry.status == AutomationUpgradeEntryStatus.locked;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: OutlinedButton(
        onPressed: entry.canTapUpgrade
            ? () => _tryUpgrade(state, entry)
            : entry.canTapLockedHint
                ? () => _showUpgradeLockHint(entry)
                : null,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: style.border),
          backgroundColor: style.background,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: automationLockOverlay(
          locked: locked,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${entry.title} Lv${entry.currentLevel}',
                      style: TextStyle(
                        color: style.titleColor,
                        fontSize: widget.windowManager.fontSize - 1,
                        fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                      ),
                    ),
                  ),
                  _statusChip(entry.statusLabel, entry.status),
                ],
              ),
              FarmResourceCostRow(
                cost: entry.cost,
                fontSize: widget.windowManager.fontSize - 3,
                fallbackLabel: entry.costLabel,
                textColor: style.costColor,
              ),
              if (entry.effectDescription != null)
                Text(
                  entry.effectDescription!,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(GameRuntimeState state, AutomationToolKind kind, bool isNear) {
    final buttons = <Widget>[];

    if (kind == AutomationToolKind.harvest && state.harvestStorage.totalSlots > 0) {
      buttons.add(
        ElevatedButton(
          onPressed: isNear ? () {
            state.transferHarvestStorageToCargo(
              onCurrencyGain: widget.game.player.updateMoneyPoints,
              onMiningGain: widget.game.player.updateMiningPoints,
            );
            widget.windowManager.showDialog(['カーゴへ回収した。']);
          } : null,
          child: const Text('ストレージをカーゴへ回収'),
        ),
      );
    }

    if (kind == AutomationToolKind.upkeep) {
      buttons.add(
        ElevatedButton(
          onPressed: isNear ? () {
            _findUpkeepTool()?.runManualCycle();
            widget.windowManager.showDialog(['手動サイクルを回した。']);
          } : null,
          child: const Text('手動サイクル'),
        ),
      );
    }

    if (!state.toolsRunWithoutFuelTank) {
      buttons.addAll(_fuelProductionButtons(state, kind, isNear));
      buttons.addAll(_fuelLoadButtons(state, kind, isNear));
    }

    return [
      const SizedBox(height: 8),
      ...buttons,
    ];
  }

  List<Widget> _fuelProductionButtons(GameRuntimeState state, AutomationToolKind kind, bool isNear) {
    if (kind != AutomationToolKind.upkeep) return const [];
    final bag = widget.game.itemBag;
    
    return [
      TextButton(
        onPressed: isNear ? () {
          final err = state.produceCrudeFuelFromResidue(bag);
          if (err != null) widget.windowManager.showDialog(['〔圧縮〕', err]);
        } : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FarmResourceIcons.lifeDot(size: 10),
            const SizedBox(width: 4),
            const Text('残滓→粗製燃料', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
      if (state.isFuelRankUnlocked(AutomationFuelRank.s1Solid))
        TextButton(
          onPressed: isNear ? () {
            final err = state.produceSolidFuelFromWillpower(bag);
            if (err != null) widget.windowManager.showDialog(['〔凝固〕', err]);
          } : null,
          child: const Text('意志→凝固燃料', style: TextStyle(color: Colors.cyanAccent)),
        ),
    ];
  }

  List<Widget> _fuelLoadButtons(GameRuntimeState state, AutomationToolKind kind, bool isNear) {
    final bag = widget.game.itemBag;
    final ranks = AutomationFuelRank.values;
    return [
      const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 2),
        child: Text('バッグからタンクへ入れる', style: TextStyle(color: Colors.white38, fontSize: 10)),
      ),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final rank in ranks)
            if (bag.getItemCount(rank.itemName) > 0)
              TextButton(
                onPressed: isNear ? () {
                  final err = state.loadFuelFromBag(bag, kind, rank);
                  if (err != null) widget.windowManager.showDialog(['〔給油〕', err]);
                } : null,
                style: TextButton.styleFrom(foregroundColor: rank.accentColor, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                child: Text('${rank.shortLabel} ×${bag.getItemCount(rank.itemName)}', style: const TextStyle(fontSize: 10)),
              ),
        ],
      ),
    ];
  }

  void _purchaseShopEntry(GameRuntimeState state, AutomationShopEntry entry) {
    if (entry.id == 'common_6') {
      widget.windowManager.showDialog(
        ['〔C-2 契約〕', '最大容量から意志の核を1単位取り外します。', '不可逆 — Nourishment 確定。'],
        options: ['契約する', 'やめる'],
        onSelect: (i) {
          if (i == 0) _toast(state.tryPurchaseCommon6Contract(widget.game.itemBag));
        },
      );
      return;
    }
    _toast(state.tryPurchaseShopEntry(entry.id, widget.game.itemBag));
  }

  void _tryUpgrade(GameRuntimeState state, AutomationUpgradeEntry entry) {
    final err = state.tryUpgradeAutomation(entry.upgradeId);
    if (err != null) widget.windowManager.showDialog(['〔強化〕', err]);
  }

  void _toast(String? err) {
    if (err == null) {
      widget.windowManager.showDialog(['〔自動化ショップ〕', '能力を開放した。']);
    } else {
      widget.windowManager.showDialog(['〔自動化ショップ〕', err]);
    }
  }

  void _showLockedHint(AutomationShopEntry entry) {
    widget.windowManager.showDialog(['〔未開放〕', entry.statusDetail ?? '未開放']);
  }

  void _showUpgradeLockHint(AutomationUpgradeEntry entry) {
    widget.windowManager.showDialog(['〔未開放〕', entry.statusDetail ?? 'ショップで能力を開放してください']);
  }

  Widget _statusChip(String label, dynamic status) {
    Color c = Colors.white38;
    if (status is AutomationShopEntryStatus) {
      c = switch (status) {
        AutomationShopEntryStatus.purchased => Colors.greenAccent,
        AutomationShopEntryStatus.available => Colors.cyanAccent,
        AutomationShopEntryStatus.locked => Colors.white38,
        AutomationShopEntryStatus.insufficient => Colors.orangeAccent,
      };
    } else if (status is AutomationUpgradeEntryStatus) {
      c = switch (status) {
        AutomationUpgradeEntryStatus.maxed => Colors.greenAccent,
        AutomationUpgradeEntryStatus.available => Colors.cyanAccent,
        AutomationUpgradeEntryStatus.insufficient => Colors.orangeAccent,
        AutomationUpgradeEntryStatus.stageCap => Colors.amberAccent,
        AutomationUpgradeEntryStatus.locked => Colors.white38,
      };
    }
    return Text(label, style: TextStyle(color: c, fontSize: widget.windowManager.fontSize - 4));
  }

  TextStyle _subStyle() => TextStyle(
        color: Colors.white70,
        fontSize: widget.windowManager.fontSize - 3,
        fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
      );

  AutomationToolKind? _toolKindForTab(AutomationShopTab tab) => switch (tab) {
        AutomationShopTab.harvest => AutomationToolKind.harvest,
        AutomationShopTab.upkeep => AutomationToolKind.upkeep,
        AutomationShopTab.ward => AutomationToolKind.ward,
        AutomationShopTab.common => null,
      };

  bool _isPlayerNearTool(GameRuntimeState state, AutomationToolKind kind) {
    final playerPos = widget.game.player.absolutePosition;
    final sceneId = state.currentOutdoorSceneId;
    for (final p in state.automationToolPlacements) {
      if (p.kind == kind && p.sceneId == sceneId) {
        final dist = (playerPos - Vector2(p.x, p.y)).length;
        if (dist < 60) return true; // インタラクト範囲内
      }
    }
    return false;
  }

  UpkeepAutomationTool? _findUpkeepTool() {
    final scene = widget.game.sceneManager.currentScene;
    if (scene == null) return null;
    for (final t in scene.children.whereType<UpkeepAutomationTool>()) {
      // 統合メニューでは instanceId を特定しづらいため、最初に見つかったものを対象とする
      // (max 1 台制限があるため実用上問題ない)
      return t;
    }
    return null;
  }

  ({Color border, Color background, Color titleColor, Color costColor, Color detailColor})
      _styleForShopStatus(AutomationShopEntryStatus status) {
    return switch (status) {
      AutomationShopEntryStatus.purchased => (
          border: Colors.green.shade700,
          background: Colors.green.withValues(alpha: 0.12),
          titleColor: Colors.white70,
          costColor: Colors.white38,
          detailColor: Colors.white38,
        ),
      AutomationShopEntryStatus.available => (
          border: Colors.cyanAccent.withValues(alpha: 0.6),
          background: Colors.transparent,
          titleColor: Colors.white,
          costColor: Colors.white54,
          detailColor: Colors.white54,
        ),
      AutomationShopEntryStatus.locked => (
          border: Colors.grey.shade700,
          background: Colors.black.withValues(alpha: 0.25),
          titleColor: Colors.white38,
          costColor: Colors.white30,
          detailColor: Colors.white38,
        ),
      AutomationShopEntryStatus.insufficient => (
          border: Colors.orange.shade700,
          background: Colors.orange.withValues(alpha: 0.08),
          titleColor: Colors.white,
          costColor: Colors.orangeAccent.shade100,
          detailColor: Colors.orangeAccent.shade100,
        ),
    };
  }

  ({Color border, Color background, Color titleColor, Color costColor, Color detailColor})
      _styleForUpgradeStatus(AutomationUpgradeEntryStatus status) {
    return switch (status) {
      AutomationUpgradeEntryStatus.maxed => (
          border: Colors.green.shade700,
          background: Colors.green.withValues(alpha: 0.12),
          titleColor: Colors.white70,
          costColor: Colors.white38,
          detailColor: Colors.white38,
        ),
      AutomationUpgradeEntryStatus.available => (
          border: Colors.cyanAccent.withValues(alpha: 0.6),
          background: Colors.transparent,
          titleColor: Colors.white,
          costColor: Colors.white54,
          detailColor: Colors.white54,
        ),
      AutomationUpgradeEntryStatus.insufficient => (
          border: Colors.orange.shade700,
          background: Colors.orange.withValues(alpha: 0.08),
          titleColor: Colors.white,
          costColor: Colors.orangeAccent.shade100,
          detailColor: Colors.orangeAccent.shade100,
        ),
      AutomationUpgradeEntryStatus.stageCap => (
          border: Colors.amber.shade700,
          background: Colors.amber.withValues(alpha: 0.08),
          titleColor: Colors.white,
          costColor: Colors.white54,
          detailColor: Colors.amberAccent.shade100,
        ),
      AutomationUpgradeEntryStatus.locked => (
          border: Colors.grey.shade700,
          background: Colors.black.withValues(alpha: 0.25),
          titleColor: Colors.white38,
          costColor: Colors.white30,
          detailColor: Colors.white38,
        ),
    };
  }
}
