import 'package:flutter/material.dart';
import '../window_manager.dart';
import 'window_base.dart';
import '../../component/item/item_bag.dart';
import '../../system/crafting_system.dart';
import '../../system/storage/game_runtime_state.dart';

class CraftingWindow extends StatefulWidget {
  final WindowManager windowManager;
  final ItemBag itemBag;
  final GameRuntimeState state;

  const CraftingWindow({
    super.key,
    required this.windowManager,
    required this.itemBag,
    required this.state,
  });

  @override
  State<CraftingWindow> createState() => _CraftingWindowState();
}

class _CraftingWindowState extends State<CraftingWindow>
    with GameWindowResponsiveMixin {
  String? _resultMessage;

  void _tryCraft(CraftingRecipe recipe) {
    final success = CraftingSystem.craft(
      recipe,
      widget.itemBag,
      widget.state,
    );
    setState(() {
      _resultMessage = success
          ? '「${recipe.resultItemName}」を合成した'
          : '素材または採掘ポイントが足りない';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = getIsMobile(widget.windowManager);
    final wm = widget.windowManager;
    final screenWidth = wm.screenWidth;
    final screenHeight = wm.screenHeight;
    final fontSize = getResponsiveFontSize(wm, mobile: 12, desktopFactor: 0.018);

    return GameWindow(
      windowManager: wm,
      title: 'CRAFT',
      showCloseButton: true,
      backgroundColor: const Color(0xFF1a1a2e),
      child: Column(
        children: [
          // 採掘ポイント表示
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.03,
              vertical: screenHeight * 0.01,
            ),
            child: AnimatedBuilder(
              animation: widget.state,
              builder: (context, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.construction,
                      color: Colors.orangeAccent,
                      size: isMobile ? 18 : screenWidth * 0.025,
                    ),
                    SizedBox(width: screenWidth * 0.01),
                    Text(
                      '採掘ポイント: ${widget.state.miningPoints}',
                      style: TextStyle(
                        fontSize: fontSize,
                        color: Colors.orangeAccent,
                        fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 結果メッセージ
          if (_resultMessage != null)
            Container(
              margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.02,
                vertical: screenHeight * 0.008,
              ),
              decoration: BoxDecoration(
                color: _resultMessage!.contains('足りない')
                    ? Colors.red.withOpacity(0.3)
                    : Colors.teal.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _resultMessage!.contains('足りない')
                      ? Colors.red
                      : Colors.tealAccent,
                  width: 1,
                ),
              ),
              child: Text(
                _resultMessage!,
                style: TextStyle(
                  fontSize: fontSize * 0.9,
                  color: Colors.white,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                ),
              ),
            ),

          SizedBox(height: screenHeight * 0.01),

          // レシピリスト
          Expanded(
            child: AnimatedBuilder(
              animation: widget.itemBag,
              builder: (context, _) {
                return ListView.builder(
                  itemCount: CraftingSystem.recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = CraftingSystem.recipes[index];
                    final canCraft = CraftingSystem.canCraft(
                      recipe,
                      widget.itemBag,
                      widget.state,
                    );
                    return _buildRecipeCard(
                      recipe,
                      canCraft,
                      isMobile,
                      screenWidth,
                      screenHeight,
                      fontSize,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(
    CraftingRecipe recipe,
    bool canCraft,
    bool isMobile,
    double screenWidth,
    double screenHeight,
    double fontSize,
  ) {
    final cardColor = canCraft
        ? const Color(0xFF16213e).withOpacity(0.8)
        : Colors.black.withOpacity(0.5);
    final borderColor =
        canCraft ? Colors.orangeAccent.withOpacity(0.8) : Colors.grey.withOpacity(0.3);

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.02,
        vertical: screenHeight * 0.005,
      ),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.015),
        child: Row(
          children: [
            // 結果アイテム名
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.resultItemName,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: canCraft ? Colors.white : Colors.grey,
                      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.005),
                  // 素材リスト
                  ...recipe.ingredients.entries.map((e) {
                    final have = widget.itemBag.getItemCount(e.key);
                    final need = e.value;
                    final ok = have >= need;
                    return Text(
                      '${e.key} × $need  (所持: $have)',
                      style: TextStyle(
                        fontSize: fontSize * 0.8,
                        color: ok ? Colors.lightGreenAccent : Colors.redAccent,
                        fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                      ),
                    );
                  }),
                  SizedBox(height: screenHeight * 0.003),
                  Text(
                    '採掘ポイント: ${recipe.miningPointCost}',
                    style: TextStyle(
                      fontSize: fontSize * 0.8,
                      color: widget.state.miningPoints >= recipe.miningPointCost
                          ? Colors.orangeAccent
                          : Colors.redAccent,
                      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                    ),
                  ),
                ],
              ),
            ),
            // 合成ボタン
            SizedBox(
              width: isMobile ? 60 : screenWidth * 0.08,
              height: isMobile ? 40 : screenHeight * 0.06,
              child: ElevatedButton(
                onPressed: canCraft ? () => _tryCraft(recipe) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canCraft
                      ? Colors.orangeAccent
                      : Colors.grey.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  '合成',
                  style: TextStyle(
                    fontSize: fontSize * 0.85,
                    color: canCraft ? Colors.black : Colors.grey,
                    fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
