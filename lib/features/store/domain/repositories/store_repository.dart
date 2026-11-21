import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/store/domain/repositories/store_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class StoreRepository implements StoreRepositoryInterface {
  final ApiClient apiClient;
  StoreRepository({required this.apiClient});

  Map<String, dynamic>? _position(double? latitude, double? longitude) =>
      latitude == null || longitude == null ? null : {'latitude': '$latitude', 'longitude': '$longitude'};

  @override
  Future getStores({double? latitude, double? longitude}) async {
    return await apiClient.getData(AppConstants.storeList, query: _position(latitude, longitude));
  }

  @override
  Future searchStores(String query, {double? latitude, double? longitude}) async {
    return await apiClient.getData('${AppConstants.storeList}/search', query: {'q': query, ...?_position(latitude, longitude)});
  }

  @override
  Future getStore(String storeId, {double? latitude, double? longitude, String? branchId}) async {
    return await apiClient.getData('${AppConstants.storeList}/$storeId', query: {
      ...?_position(latitude, longitude),
      if (branchId != null) 'branch': branchId,
    });
  }

  @override
  Future getBranches(String storeId, {double? latitude, double? longitude, String? branchId}) async {
    return await apiClient.getData('${AppConstants.storeList}/$storeId/branches', query: {
      ...?_position(latitude, longitude),
      if (branchId != null) 'branch': branchId,
    });
  }

  @override
  Future quote(Map<String, dynamic> body) async {
    return await apiClient.postData(AppConstants.storeOrderQuote, body);
  }

  @override
  Future placeOrder(Map<String, dynamic> body) async {
    return await apiClient.postData(AppConstants.storeOrders, body);
  }

  @override
  Future getAttention() async {
    return await apiClient.getData(AppConstants.storeOrderAttention);
  }

  @override
  Future getOrders({int offset = 1}) async {
    return await apiClient.getData(AppConstants.storeOrders, query: {'limit': '20', 'offset': '$offset'});
  }

  @override
  Future getOrder(String orderId) async {
    return await apiClient.getData('${AppConstants.storeOrders}/$orderId');
  }

  @override
  Future cancelOrder(String orderId) async {
    return await apiClient.putData('${AppConstants.storeOrders}/$orderId/cancel', {});
  }

  @override
  Future payOrder(String orderId, String paymentMethod) async {
    return await apiClient.postData('${AppConstants.storeOrders}/$orderId/payment', {'payment_method': paymentMethod});
  }

  @override
  Future deliverInstead(String orderId, Map<String, dynamic> body) async {
    return await apiClient.postData('${AppConstants.storeOrders}/$orderId/deliver', body);
  }

  @override
  Future claimLinkReferral(String slug) async {
    return await apiClient.postData('${AppConstants.storeList}/referral', {'slug': slug});
  }

  @override
  Future keepWay(String orderId) async {
    return await apiClient.postData('${AppConstants.storeOrders}/$orderId/keep-way', {});
  }

  @override
  Future confirmReceived(String orderId) async {
    return await apiClient.postData('${AppConstants.storeOrders}/$orderId/received', {});
  }

  @override
  Future answerChanges(String orderId, bool accept) async {
    return await apiClient.postData('${AppConstants.storeOrders}/$orderId/changes', {'accept': accept});
  }

  @override
  Future reviewOrder(String orderId, Map<String, dynamic> body) async {
    return await apiClient.postData('${AppConstants.storeOrders}/$orderId/review', body);
  }

  @override
  Future add(value) => throw UnimplementedError();

  @override
  Future delete(String id) => throw UnimplementedError();

  @override
  Future get(String id) => throw UnimplementedError();

  @override
  Future getList({int? offset = 1}) => throw UnimplementedError();

  @override
  Future update(value, {int? id}) => throw UnimplementedError();
}
