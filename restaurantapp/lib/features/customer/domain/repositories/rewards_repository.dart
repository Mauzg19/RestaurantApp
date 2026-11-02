import '../entities/reward.dart';

abstract interface class RewardsRepository {
  Future<RewardsSnapshot> load();

  Future<RewardsSnapshot> join();
}
