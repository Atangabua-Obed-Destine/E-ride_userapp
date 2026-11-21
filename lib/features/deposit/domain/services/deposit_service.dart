import 'package:ride_sharing_user_app/features/deposit/domain/repositories/deposit_repository_interface.dart';
import 'package:ride_sharing_user_app/features/deposit/domain/services/deposit_service_interface.dart';

class DepositService implements DepositServiceInterface {
  final DepositRepositoryInterface depositRepositoryInterface;
  DepositService({required this.depositRepositoryInterface});

  @override
  Future getDeposit(String tripId) => depositRepositoryInterface.getDeposit(tripId);

  @override
  Future payWithWallet(String tripId) => depositRepositoryInterface.payWithWallet(tripId);

  @override
  Future getPayUrl(String tripId, String paymentMethod) => depositRepositoryInterface.getPayUrl(tripId, paymentMethod);

  @override
  Future getReportReasons() => depositRepositoryInterface.getReportReasons();

  @override
  Future reportDriver(String tripId, String reason, String comment) =>
      depositRepositoryInterface.reportDriver(tripId, reason, comment);
}
