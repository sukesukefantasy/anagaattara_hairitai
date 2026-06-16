/// 3種自動化装置（収穫・整備・防衛）。
enum AutomationToolKind {
  harvest,
  upkeep,
  ward;

  String get itemName => switch (this) {
        AutomationToolKind.harvest => '自動収穫ツール',
        AutomationToolKind.upkeep => '自動整備ツール',
        AutomationToolKind.ward => '自動防衛ツール',
      };

  String get spriteAsset => switch (this) {
        AutomationToolKind.harvest => 'nozzle.png',
        AutomationToolKind.upkeep => 'valve.png',
        AutomationToolKind.ward => 'igniter.png',
      };

  String get placeableEffect => switch (this) {
        AutomationToolKind.harvest => 'automationHarvest',
        AutomationToolKind.upkeep => 'automationUpkeep',
        AutomationToolKind.ward => 'automationWard',
      };

  String get displayLabel => switch (this) {
        AutomationToolKind.harvest => '自動収穫',
        AutomationToolKind.upkeep => '自動整備',
        AutomationToolKind.ward => '自動防衛',
      };

  static AutomationToolKind? fromJson(String? s) {
    if (s == null) return null;
    return switch (s) {
      'harvest' => AutomationToolKind.harvest,
      'upkeep' => AutomationToolKind.upkeep,
      'ward' => AutomationToolKind.ward,
      _ => null,
    };
  }

  String toJson() => name;
}
