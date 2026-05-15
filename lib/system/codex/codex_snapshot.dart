/// 図鑑5分類（§7）。永続スナップショット。`connectionStatus` の `blacked` は不可逆。
class CodexSnapshot {
  /// NPC uniqueId → `normal` | `blacked`
  final Map<String, String> connectionStatus;
  final Map<String, int> itemCreatedCount;
  final Map<String, int> itemUsedCount;
  final int automationDeviceOps;
  final Map<String, int> craftCreatedCount;
  final Map<String, int> furnitureInteractionCount;

  const CodexSnapshot({
    this.connectionStatus = const {},
    this.itemCreatedCount = const {},
    this.itemUsedCount = const {},
    this.automationDeviceOps = 0,
    this.craftCreatedCount = const {},
    this.furnitureInteractionCount = const {},
  });

  static CodexSnapshot empty() => const CodexSnapshot();

  CodexSnapshot copyWith({
    Map<String, String>? connectionStatus,
    Map<String, int>? itemCreatedCount,
    Map<String, int>? itemUsedCount,
    int? automationDeviceOps,
    Map<String, int>? craftCreatedCount,
    Map<String, int>? furnitureInteractionCount,
  }) {
    return CodexSnapshot(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      itemCreatedCount: itemCreatedCount ?? this.itemCreatedCount,
      itemUsedCount: itemUsedCount ?? this.itemUsedCount,
      automationDeviceOps: automationDeviceOps ?? this.automationDeviceOps,
      craftCreatedCount: craftCreatedCount ?? this.craftCreatedCount,
      furnitureInteractionCount:
          furnitureInteractionCount ?? this.furnitureInteractionCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'connectionStatus': connectionStatus,
        'itemCreatedCount': itemCreatedCount,
        'itemUsedCount': itemUsedCount,
        'automationDeviceOps': automationDeviceOps,
        'craftCreatedCount': craftCreatedCount,
        'furnitureInteractionCount': furnitureInteractionCount,
      };

  factory CodexSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return CodexSnapshot.empty();
    return CodexSnapshot(
      connectionStatus: (json['connectionStatus'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
          {},
      itemCreatedCount: (json['itemCreatedCount'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k.toString(), v as int)) ??
          {},
      itemUsedCount: (json['itemUsedCount'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k.toString(), v as int)) ??
          {},
      automationDeviceOps: json['automationDeviceOps'] as int? ?? 0,
      craftCreatedCount: (json['craftCreatedCount'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k.toString(), v as int)) ??
          {},
      furnitureInteractionCount:
          (json['furnitureInteractionCount'] as Map<String, dynamic>?)
                  ?.map((k, v) => MapEntry(k.toString(), v as int)) ??
              {},
    );
  }
}
