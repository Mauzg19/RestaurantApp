class RewardCatalogItem {
  const RewardCatalogItem({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.requiredPoints,
    required this.discountAmount,
    required this.minimumOrderAmount,
    required this.active,
  });

  final int id;
  final String code;
  final String name;
  final String description;
  final int requiredPoints;
  final int discountAmount;
  final int minimumOrderAmount;
  final bool active;

  factory RewardCatalogItem.fromJson(Map<String, dynamic> json) =>
      RewardCatalogItem(
        id: _asInt(json['id']),
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        requiredPoints: _asInt(json['requiredPoints']),
        discountAmount: _asInt(json['discountAmount']),
        minimumOrderAmount: _asInt(json['minimumOrderAmount']),
        active: json['active'] == true,
      );
}

class RewardLedgerEntry {
  const RewardLedgerEntry({
    required this.id,
    required this.type,
    required this.pointsDelta,
    required this.description,
    required this.createdAt,
  });

  final int id;
  final String type;
  final int pointsDelta;
  final String description;
  final DateTime? createdAt;

  factory RewardLedgerEntry.fromJson(Map<String, dynamic> json) =>
      RewardLedgerEntry(
        id: _asInt(json['id']),
        type: json['type']?.toString() ?? '',
        pointsDelta: _asInt(json['pointsDelta']),
        description: json['description']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}

class RewardsSnapshot {
  const RewardsSnapshot({
    required this.joined,
    required this.pointsBalance,
    required this.catalog,
    required this.history,
  });

  final bool joined;
  final int pointsBalance;
  final List<RewardCatalogItem> catalog;
  final List<RewardLedgerEntry> history;
}

int _asInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
