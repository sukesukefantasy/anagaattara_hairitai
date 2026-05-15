/// v8.3 §6.1 — 屋外IDをまたいだときのみ永続する微細ログ（シナリオ差し替えなし）。
class StageMicroLogEntry {
  final String fromOutdoorId;
  final String toOutdoorId;
  final int rogueHints;
  final int farmHints;
  final int exploreHints;
  final int specialHints;

  const StageMicroLogEntry({
    required this.fromOutdoorId,
    required this.toOutdoorId,
    required this.rogueHints,
    required this.farmHints,
    required this.exploreHints,
    required this.specialHints,
  });

  Map<String, dynamic> toJson() => {
        'fromOutdoorId': fromOutdoorId,
        'toOutdoorId': toOutdoorId,
        'rogueHints': rogueHints,
        'farmHints': farmHints,
        'exploreHints': exploreHints,
        'specialHints': specialHints,
      };

  factory StageMicroLogEntry.fromJson(Map<String, dynamic> json) {
    return StageMicroLogEntry(
      fromOutdoorId: json['fromOutdoorId'] as String? ?? '',
      toOutdoorId: json['toOutdoorId'] as String? ?? '',
      rogueHints: json['rogueHints'] as int? ?? 0,
      farmHints: json['farmHints'] as int? ?? 0,
      exploreHints: json['exploreHints'] as int? ?? 0,
      specialHints: json['specialHints'] as int? ?? 0,
    );
  }
}
