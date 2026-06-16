/// ローグ装備の戦闘役割（クラフト・装備名で参照）。
class RogueWeaponProfile {
  final double meleeDamageMultiplier;
  final double movementSpeedMultiplier;
  final double guardStressReduction;
  final double snatchRadiusBonus;
  final int bonusParticlesOnKill;
  final double particleCargoValueMultiplier;

  const RogueWeaponProfile({
    this.meleeDamageMultiplier = 1.0,
    this.movementSpeedMultiplier = 1.0,
    this.guardStressReduction = 0.0,
    this.snatchRadiusBonus = 0.0,
    this.bonusParticlesOnKill = 0,
    this.particleCargoValueMultiplier = 1.0,
  });

  static const RogueWeaponProfile bareHand = RogueWeaponProfile();

  static const Map<String, RogueWeaponProfile> byItemName = {
    '石付き棒': RogueWeaponProfile(),
    '削岩棒': RogueWeaponProfile(
      meleeDamageMultiplier: 1.25,
      bonusParticlesOnKill: 1,
    ),
    '長い棒': RogueWeaponProfile(
      movementSpeedMultiplier: 1.08,
      snatchRadiusBonus: 24.0,
    ),
    '軽装の足袋': RogueWeaponProfile(
      movementSpeedMultiplier: 1.10,
      snatchRadiusBonus: 16.0,
    ),
    '簡易盾': RogueWeaponProfile(
      guardStressReduction: 0.25,
      movementSpeedMultiplier: 0.94,
    ),
    '広刃棒': RogueWeaponProfile(
      meleeDamageMultiplier: 0.9,
      bonusParticlesOnKill: 2,
      particleCargoValueMultiplier: 1.1,
    ),
    '火炎瓶': RogueWeaponProfile(meleeDamageMultiplier: 0.85),
    '火炎放射器': RogueWeaponProfile(meleeDamageMultiplier: 1.15),
  };

  static RogueWeaponProfile forEquipped(String? itemName) {
    if (itemName == null || itemName.isEmpty) return bareHand;
    return byItemName[itemName] ?? bareHand;
  }
}
