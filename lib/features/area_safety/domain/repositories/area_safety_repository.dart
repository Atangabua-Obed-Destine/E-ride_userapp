import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/area_safety/domain/repositories/area_safety_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class AreaSafetyRepository implements AreaSafetyRepositoryInterface {
  final ApiClient apiClient;
  AreaSafetyRepository({required this.apiClient});

  @override
  Future getMeta() => apiClient.getData('${AppConstants.areaSafety}/meta');

  @override
  Future getNearby(double latitude, double longitude) =>
      apiClient.getData('${AppConstants.areaSafety}/nearby', query: {'latitude': '$latitude', 'longitude': '$longitude'});

  @override
  Future report(Map<String, dynamic> body) => apiClient.postData('${AppConstants.areaSafety}/report', body);

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
