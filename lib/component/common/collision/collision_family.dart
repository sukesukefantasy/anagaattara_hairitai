import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

/// アクションゲーム向けの当たり判定ファミリー（論理レイヤー）。
///
/// Flame の [CollisionType] だけでは表現できない組み合わせ（B≠C かつ E≠C 等）を
/// [FamilyFilteredCollisionDetection] と [collisionFamiliesInteract] で扱う。
enum CollisionFamily {
  /// 未分類。常に他ファミリーと衝突を許可（後方互換・段階的移行用）
  unspecified,

  /// A: プレイヤー
  player,

  /// B: 敵・NPC 等のエンティティ
  entity,

  /// C: 建物・小物（自販機、駅、家具の固体など）
  prop,

  /// D: 地形（地面・掘削グリッド等）
  terrain,

  /// E: ワールド上のアイテム（投擲・物理）
  item,

  /// 割れ家具など: **飛来 Item とのヒット検知専用**（プレイヤー・敵とは衝突しない）
  propItemStrike,

  /// インタラクト UI 用ボリューム（プレイヤーとのみ衝突）
  interactUi,

  /// 回収可能な残滓微粒子（プレイヤー・地形と相互作用。地形では足場として押し出す）
  collectibleResidue,
}

/// ヒットボックス自身のファミリーを親より優先して使う場合に実装する。
abstract interface class HitboxCollisionTag {
  CollisionFamily get collisionFamily;
}

/// コンポーネント木から [CollisionFamily] を解決する。
mixin HasCollisionFamily on Component {
  CollisionFamily get collisionFamily;
}

/// 2 ファミリー間で衝突コールバックを流すか（対称）。
bool collisionFamiliesInteract(CollisionFamily a, CollisionFamily b) {
  if (a == CollisionFamily.unspecified || b == CollisionFamily.unspecified) {
    return true;
  }

  // 割れ家具の Item 検知ヒットボックス: Item とのみ
  if (a == CollisionFamily.propItemStrike ||
      b == CollisionFamily.propItemStrike) {
    return a == CollisionFamily.item || b == CollisionFamily.item;
  }

  // インタラクト UI: プレイヤーとのみ
  if (a == CollisionFamily.interactUi || b == CollisionFamily.interactUi) {
    return a == CollisionFamily.player || b == CollisionFamily.player;
  }

  // 残滓微粒子: プレイヤーと地形（足場）とのみ
  if (a == CollisionFamily.collectibleResidue ||
      b == CollisionFamily.collectibleResidue) {
    final other = a == CollisionFamily.collectibleResidue ? b : a;
    return other == CollisionFamily.player || other == CollisionFamily.terrain;
  }

  final pair = {a, b};
  if (pair.contains(CollisionFamily.entity) && pair.contains(CollisionFamily.prop)) {
    return false;
  }
  if (pair.contains(CollisionFamily.item) && pair.contains(CollisionFamily.prop)) {
    return false;
  }

  return true;
}

/// [ShapeHitbox] からファミリーを解決する。
CollisionFamily collisionFamilyOf(ShapeHitbox h) {
  if (h is HitboxCollisionTag) {
    return (h as HitboxCollisionTag).collisionFamily;
  }
  Component? walk = h.hitboxParent;
  while (walk != null) {
    if (walk is HasCollisionFamily) {
      return walk.collisionFamily;
    }
    walk = walk.parent;
  }
  return CollisionFamily.unspecified;
}
