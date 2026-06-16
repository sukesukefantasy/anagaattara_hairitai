/// 収穫ツール内蔵ストレージ（カーゴ種別＋通貨・採掘Pt）。
class AutomationHarvestStorage {
  int life;
  int history;
  int inorganic;
  int currency;
  int miningPoints;

  AutomationHarvestStorage({
    this.life = 0,
    this.history = 0,
    this.inorganic = 0,
    this.currency = 0,
    this.miningPoints = 0,
  });

  int get totalResidue => life + history + inorganic;

  int get totalSlots => totalResidue + (currency > 0 ? 1 : 0) + (miningPoints > 0 ? 1 : 0);

  Map<String, dynamic> toJson() => {
        'life': life,
        'history': history,
        'inorganic': inorganic,
        'currency': currency,
        'miningPoints': miningPoints,
      };

  factory AutomationHarvestStorage.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AutomationHarvestStorage();
    return AutomationHarvestStorage(
      life: json['life'] as int? ?? 0,
      history: json['history'] as int? ?? 0,
      inorganic: json['inorganic'] as int? ?? 0,
      currency: json['currency'] as int? ?? 0,
      miningPoints: json['miningPoints'] as int? ?? 0,
    );
  }

  void clear() {
    life = history = inorganic = currency = miningPoints = 0;
  }
}
