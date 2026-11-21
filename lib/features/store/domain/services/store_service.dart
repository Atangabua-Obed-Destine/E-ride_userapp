import 'package:ride_sharing_user_app/features/store/domain/repositories/store_repository_interface.dart';
import 'package:ride_sharing_user_app/features/store/domain/services/store_service_interface.dart';

class StoreService implements StoreServiceInterface {
  final StoreRepositoryInterface storeRepositoryInterface;
  StoreService({required this.storeRepositoryInterface});

  @override
  Future getStores({double? latitude, double? longitude}) =>
      storeRepositoryInterface.getStores(latitude: latitude, longitude: longitude);

  @override
  Future searchStores(String query, {double? latitude, double? longitude}) =>
      storeRepositoryInterface.searchStores(query, latitude: latitude, longitude: longitude);

  @override
  Future getStore(String storeId, {double? latitude, double? longitude, String? branchId}) =>
      storeRepositoryInterface.getStore(storeId, latitude: latitude, longitude: longitude, branchId: branchId);

  @override
  Future getBranches(String storeId, {double? latitude, double? longitude, String? branchId}) =>
      storeRepositoryInterface.getBranches(storeId, latitude: latitude, longitude: longitude, branchId: branchId);

  @override
  Future quote(Map<String, dynamic> body) => storeRepositoryInterface.quote(body);

  @override
  Future placeOrder(Map<String, dynamic> body) => storeRepositoryInterface.placeOrder(body);

  @override
  Future getOrders({int offset = 1}) => storeRepositoryInterface.getOrders(offset: offset);

  @override
  Future getAttention() => storeRepositoryInterface.getAttention();

  @override
  Future getOrder(String orderId) => storeRepositoryInterface.getOrder(orderId);

  @override
  Future cancelOrder(String orderId) => storeRepositoryInterface.cancelOrder(orderId);

  @override
  Future payOrder(String orderId, String paymentMethod) => storeRepositoryInterface.payOrder(orderId, paymentMethod);

  @override
  Future deliverInstead(String orderId, Map<String, dynamic> body) => storeRepositoryInterface.deliverInstead(orderId, body);

  @override
  Future keepWay(String orderId) => storeRepositoryInterface.keepWay(orderId);

  @override
  Future confirmReceived(String orderId) => storeRepositoryInterface.confirmReceived(orderId);

  @override
  Future claimLinkReferral(String slug) => storeRepositoryInterface.claimLinkReferral(slug);

  @override
  Future answerChanges(String orderId, bool accept) => storeRepositoryInterface.answerChanges(orderId, accept);

  @override
  Future reviewOrder(String orderId, Map<String, dynamic> body) => storeRepositoryInterface.reviewOrder(orderId, body);
}
