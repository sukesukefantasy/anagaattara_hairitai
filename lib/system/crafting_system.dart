import 'package:flame/components.dart';
import '../component/item/item.dart';
import '../component/item/item_bag.dart';
import 'storage/game_runtime_state.dart';

/// アイテム合成レシピの定義
class CraftingRecipe {
  /// 合成に必要な素材 (アイテム名 → 必要数)
  final Map<String, int> ingredients;

  /// 消費する採掘ポイント
  final int miningPointCost;

  /// 合成結果のアイテム名
  final String resultItemName;

  /// 結果の個数
  final int resultCount;

  const CraftingRecipe({
    required this.ingredients,
    required this.miningPointCost,
    required this.resultItemName,
    this.resultCount = 1,
  });
}

/// アイテム合成システム。
/// 素材とminingPointsを消費して新しいアイテムを生成する。
/// 合成はプレイヤーの手作業であり、自動化はしない（設計思想に沿う）。
class CraftingSystem {
  static const List<CraftingRecipe> recipes = [
    // 石 + 棒 → 石付き棒
    CraftingRecipe(
      ingredients: {'石': 1, '棒': 1},
      miningPointCost: 5,
      resultItemName: '石付き棒',
    ),
    // 石付き棒 + 採掘の気力 → 削岩棒
    CraftingRecipe(
      ingredients: {'石付き棒': 1, '採掘の気力': 1},
      miningPointCost: 15,
      resultItemName: '削岩棒',
    ),
    // 石 + 石 → 鋭い石
    CraftingRecipe(
      ingredients: {'石': 2},
      miningPointCost: 3,
      resultItemName: '鋭い石',
    ),
    // 棒 + 棒 → 長い棒
    CraftingRecipe(
      ingredients: {'棒': 2},
      miningPointCost: 3,
      resultItemName: '長い棒',
    ),
    // はしご
    CraftingRecipe(
      ingredients: {'石': 1},
      miningPointCost: 0,
      resultItemName: 'はしご',
    ),
    // ランタン
    CraftingRecipe(
      ingredients: {'石': 1},
      miningPointCost: 0,
      resultItemName: 'ランタン',
    ),
    // --- ローグビルド（§ ローグ駆け引き v0.1）---
    CraftingRecipe(
      ingredients: {'棒': 2, '石': 1},
      miningPointCost: 8,
      resultItemName: '広刃棒',
    ),
    CraftingRecipe(
      ingredients: {'棒': 1, '石': 2},
      miningPointCost: 6,
      resultItemName: '簡易盾',
    ),
    CraftingRecipe(
      ingredients: {'棒': 1},
      miningPointCost: 4,
      resultItemName: '軽装の足袋',
    ),
  ];

  /// 指定レシピが現在のバッグと採掘ポイントで合成可能かチェック
  static bool canCraft(
    CraftingRecipe recipe,
    ItemBag bag,
    GameRuntimeState state,
  ) {
    if (state.miningPoints < recipe.miningPointCost) return false;
    for (final entry in recipe.ingredients.entries) {
      if (bag.getItemCount(entry.key) < entry.value) return false;
    }
    return true;
  }

  /// 合成を実行する。成功したら true を返す
  static bool craft(
    CraftingRecipe recipe,
    ItemBag bag,
    GameRuntimeState state,
  ) {
    if (!canCraft(recipe, bag, state)) return false;

    // 素材を消費
    for (final entry in recipe.ingredients.entries) {
      bag.removeItem(entry.key, count: entry.value);
    }

    // 採掘ポイントを消費（spendMiningPoints が notifyListeners も呼ぶ）
    state.spendMiningPoints(recipe.miningPointCost);

    // 結果アイテムをバッグに追加（positionはバッグ内なのでダミー）
    for (int i = 0; i < recipe.resultCount; i++) {
      final item = ItemFactory.createItemByName(
        recipe.resultItemName,
        Vector2.zero(),
      );
      if (item != null) bag.addItem(item);
    }

    state.codexIncrementCraft(recipe.resultItemName);

    return true;

  }
}
