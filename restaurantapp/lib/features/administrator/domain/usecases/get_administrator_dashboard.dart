import '../entities/administrator_dashboard.dart';
import '../repositories/administrator_repository.dart';

class GetAdministratorDashboard {
  const GetAdministratorDashboard(this.repository);

  final AdministratorRepository repository;

  AdministratorDashboard call() => repository.getDashboard();
}
