import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/explore/domain/repositories/explore_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class ExploreRepository implements ExploreRepositoryInterface {
  final ApiClient apiClient;
  ExploreRepository({required this.apiClient});

  @override
  Future getCategories() async {
    return await apiClient.getData(AppConstants.explore);
  }

  @override
  Future getPlaces(String category, {double? latitude, double? longitude, Map<String, String>? extra}) async {
    final Map<String, String> query = {
      if (latitude != null && longitude != null) ...{'latitude': '$latitude', 'longitude': '$longitude'},
      ...?extra,
    };
    return await apiClient.getData('${AppConstants.explore}/$category', query: query.isEmpty ? null : query);
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
