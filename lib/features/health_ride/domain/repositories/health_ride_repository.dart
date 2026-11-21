import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/health_ride/domain/repositories/health_ride_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class HealthRideRepository implements HealthRideRepositoryInterface {
  final ApiClient apiClient;
  HealthRideRepository({required this.apiClient});

  @override
  Future getPlaces(double latitude, double longitude) =>
      apiClient.getData(AppConstants.healthRidePlaces, query: {'latitude': '$latitude', 'longitude': '$longitude'});

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
