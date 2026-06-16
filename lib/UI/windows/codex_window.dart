import 'package:flutter/material.dart';
import '../../main.dart';
import '../../system/codex/codex_snapshot.dart';
import '../../system/automation_tool_kind.dart';
import '../../system/automation_tool_state.dart';
import '../../system/storage/game_runtime_state.dart';
import '../window_manager.dart';

class CodexWindow extends StatelessWidget {
  final MyGame game;
  final WindowManager windowManager;

  const CodexWindow({
    super.key,
    required this.game,
    required this.windowManager,
  });

  @override
  Widget build(BuildContext context) {
    final CodexSnapshot c = game.gameRuntimeState.codex;
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 440,
          constraints: const BoxConstraints(maxHeight: 520),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF120812).withOpacity(0.96),
            border: Border.all(color: Colors.indigo.shade200.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '図鑑',
                style: TextStyle(
                  color: Colors.indigo.shade100,
                  fontSize: windowManager.fontSize + 2,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                ),
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: DefaultTabController(
                  length: 5,
                  child: Column(
                    children: [
                      TabBar(
                        isScrollable: true,
                        labelStyle:
                            TextStyle(fontSize: windowManager.fontSize - 2),
                        tabs: const [
                          Tab(text: 'つながり'),
                          Tab(text: 'アイテム'),
                          Tab(text: '自動装置'),
                          Tab(text: 'クラフト'),
                          Tab(text: '家具'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildConnections(c),
                            _buildItemTab(c),
                            _automationTab(game.gameRuntimeState),
                            _buildMapList(c.craftCreatedCount, '作成数'),
                            _buildMapList(
                                c.furnitureInteractionCount, '回数'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: () => windowManager.hideWindow(),
                child: const Text('閉じる', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnections(CodexSnapshot c) {
    if (c.connectionStatus.isEmpty) {
      return _centerText('まだ記録がない');
    }
    return ListView(
      children: c.connectionStatus.entries.map((e) {
        final isBlack = e.value == 'blacked';
        final isSat = e.value == 'satisfied';
        final label =
            isBlack ? '〈黒塗り〉' : (isSat ? '〈共闘済〉' : '〈遭遇〉');
        return ListTile(
          title: Text(
            '${e.key} $label',
            style: TextStyle(
              color: isBlack ? Colors.black87 : Colors.white,
              backgroundColor:
                  isBlack ? Colors.grey.shade800 : Colors.transparent,
              fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
              fontSize: windowManager.fontSize,
            ),
          ),
          subtitle: Text(
            '状態: ${e.value}',
            style: TextStyle(
              color: Colors.white54,
              fontSize: windowManager.fontSize - 2,
              fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildItemTab(CodexSnapshot c) {
    final keys = {
      ...c.itemCreatedCount.keys,
      ...c.itemUsedCount.keys,
    }.toList()
      ..sort();
    if (keys.isEmpty) return _centerText('データなし');
    return ListView.builder(
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final k = keys[i];
        final created = c.itemCreatedCount[k] ?? 0;
        final used = c.itemUsedCount[k] ?? 0;
        return ListTile(
          title: Text(
            k,
            style: TextStyle(
              color: Colors.white,
              fontSize: windowManager.fontSize,
              fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
            ),
          ),
          subtitle: Text(
            '作成 $created ・ 使用 $used',
            style: TextStyle(
              color: Colors.white54,
              fontSize: windowManager.fontSize - 2,
            ),
          ),
        );
      },
    );
  }

  Widget _automationTab(GameRuntimeState s) {
    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: [
        ListTile(
          title: const Text('3種装置', style: TextStyle(color: Colors.white)),
          subtitle: Text(
            '収穫:${s.hasToolPlaced(AutomationToolKind.harvest) ? "設置" : "—"} '
            '整備:${s.hasToolPlaced(AutomationToolKind.upkeep) ? "設置" : "—"} '
            '防衛:${s.hasToolPlaced(AutomationToolKind.ward) ? "設置" : "—"}',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        ListTile(
          title: const Text('キット段階（整備）', style: TextStyle(color: Colors.white)),
          subtitle: Text(
            '${s.automationKitStage}（0=未設置 … 4=C-2）',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        ListTile(
          title: const Text('ショップ段階', style: TextStyle(color: Colors.white)),
          subtitle: Text(
            '収穫${s.automationShopGradeHarvest} '
            '整備${s.automationShopGradeUpkeep} '
            '防衛${s.automationShopGradeWard} '
            '共通${s.automationShopGradeCommon}',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        ListTile(
          title: const Text('稼働・契約', style: TextStyle(color: Colors.white)),
          subtitle: Text(
            '稼働 ${s.automationKitTotalRuntime.toStringAsFixed(0)} / '
            '記録オプス ${s.codex.automationDeviceOps} / C-2:${s.automationContractC2}',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        ListTile(
          title: const Text('母星人間性', style: TextStyle(color: Colors.white)),
          subtitle: Text(
            '${s.homePlanetHumanity.toStringAsFixed(0)} / 100 '
            '（効率 ${s.homePlanetEfficiency.toStringAsFixed(0)}・'
            '現実 ${s.homePlanetRealism.toStringAsFixed(0)}）',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        ListTile(
          title: const Text('警戒狩人', style: TextStyle(color: Colors.white)),
          subtitle: Text(
            s.hunterToolsGranted.isEmpty
                ? '未撃破 — 警戒↑で出現'
                : '付与: ${s.hunterToolsGranted.join(", ")}',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _buildMapList(Map<String, int> map, String suffix) {
    if (map.isEmpty) return _centerText('データなし');
    final keys = map.keys.toList()..sort();
    return ListView.builder(
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final k = keys[i];
        return ListTile(
          title: Text(k,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: windowManager.fontSize,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular')),
          trailing: Text('${map[k]} $suffix',
              style: const TextStyle(color: Colors.white70)),
        );
      },
    );
  }

  Widget _centerText(String t) => Center(
        child: Text(
          t,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: windowManager.fontSize,
            fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
          ),
        ),
      );
}
