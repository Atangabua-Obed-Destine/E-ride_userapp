import 'package:ride_sharing_user_app/interface/repository_interface.dart';

abstract class StoreRepositoryInterface implements RepositoryInterface {
  Future<dynamic> getStores({double? latitude, double? longitude});
  Future<dynamic> searchStores(String query, {double? latitude, double? longitude});
  Future<dynamic> getStore(String storeId, {double? latitude, double? longitude, String? branchId});
  Future<dynamic> getBranches(String storeId, {double? latitude, double? longitude, String? branchId});
  Future<dynamic> quote(Map<String, dynamic> body);
  Future<dynamic> placeOrder(Map<String, dynamic> body);
  Future<dynamic> getOrders({int offset = 1});
  Future<dynamic> getAttention();
  Future<dynamic> getOrder(String orderId);
  Future<dynamic> cancelOrder(String orderId);
  Future<dynamic> payOrder(String orderId, String paymentMethod);
  Future<dynamic> answerChanges(String orderId, bool accept);
  Future<dynamic> deliverInstead(String orderId, Map<String, dynamic> body);
  Future<dynamic> keepWay(String orderId);
  Future<dynamic> confirmReceived(String orderId);
  Future<dynamic> claimLinkReferral(String slug);
  Future<dynamic> reviewOrder(String orderId, Map<String, dynamic> body);
}
