import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/lost_item/domain/repositories/lost_item_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class LostItemRepository implements LostItemRepositoryInterface {
  final ApiClient apiClient;
  LostItemRepository({required this.apiClient});

  @override
  Future getForTrip(String tripId) => apiClient.getData(AppConstants.lostItems, query: {'trip_request_id': tripId});

  @override
  Future report(String tripId, String description, XFile? photo) => apiClient.postMultipartData(
    AppConstants.lostItems,
    {'trip_request_id': tripId, 'description': description},
    MultipartBody('', null),
    photo != null ? [MultipartBody('photo', photo)] : [],
  );

  @override
  Future act(String id, String action) => apiClient.postData('${AppConstants.lostItems}/$id/action', {'action': action});

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
