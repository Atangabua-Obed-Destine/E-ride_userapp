import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/deposit/domain/repositories/deposit_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class DepositRepository implements DepositRepositoryInterface {
  final ApiClient apiClient;
  DepositRepository({required this.apiClient});

  @override
  Future getDeposit(String tripId) async {
    return await apiClient.getData('${AppConstants.tripDeposit}$tripId');
  }

  @override
  Future payWithWallet(String tripId) async {
    return await apiClient.postData('${AppConstants.tripDeposit}$tripId/wallet', {});
  }

  @override
  Future getPayUrl(String tripId, String paymentMethod) async {
    return await apiClient.getData('${AppConstants.tripDeposit}$tripId/pay-url', query: {'payment_method': paymentMethod});
  }

  @override
  Future getReportReasons() async {
    return await apiClient.getData(AppConstants.tripReportReasons);
  }

  @override
  Future reportDriver(String tripId, String reason, String comment) async {
    return await apiClient.postData(AppConstants.tripReport, {
      'trip_request_id': tripId,
      'reason': reason,
      if (comment.trim().isNotEmpty) 'comment': comment.trim(),
    });
  }
}
