import '../../../../core/network/api_config.dart';
import '../../../../core/network/http_client_service.dart';
import '../../domain/entities/reward.dart';
import '../../domain/repositories/rewards_repository.dart';

class SpringBootRewardsRepository implements RewardsRepository {
  SpringBootRewardsRepository({required this.httpClient});

  final HttpClientService httpClient;

  @override
  Future<RewardsSnapshot> load() async {
    final responses = await Future.wait<dynamic>([
      httpClient.get(ApiConfig.rewardsUrl),
      httpClient.get(ApiConfig.rewardsHistoryUrl),
    ]);
    final summary = responses[0];
    final rawHistory = responses[1];
    if (summary is! Map || rawHistory is! List) {
      throw const FormatException(
        'Spring Boot devolvió la información de recompensas con formato inválido.',
      );
    }

    final rawCatalog = summary['catalog'];
    if (rawCatalog is! List) {
      throw const FormatException(
        'Spring Boot devolvió el catálogo de recompensas con formato inválido.',
      );
    }
    return RewardsSnapshot(
      joined: summary['joined'] == true,
      pointsBalance: _asInt(summary['pointsBalance']),
      catalog: rawCatalog
          .whereType<Map>()
          .map(
            (row) => RewardCatalogItem.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(),
      history: rawHistory
          .whereType<Map>()
          .map(
            (row) => RewardLedgerEntry.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(),
    );
  }

  @override
  Future<RewardsSnapshot> join() async {
    await httpClient.post(ApiConfig.rewardsJoinUrl, body: const {});
    return load();
  }

  int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
