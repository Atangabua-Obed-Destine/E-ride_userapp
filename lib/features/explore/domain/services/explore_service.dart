import 'package:ride_sharing_user_app/features/explore/domain/repositories/explore_repository_interface.dart';
import 'package:ride_sharing_user_app/features/explore/domain/services/explore_service_interface.dart';

class ExploreService implements ExploreServiceInterface {
  final ExploreRepositoryInterface exploreRepositoryInterface;
  ExploreService({required this.exploreRepositoryInterface});

  @override
  Future getCategories() => exploreRepositoryInterface.getCategories();

  @override
  Future getPlaces(String category, {double? latitude, double? longitude, Map<String, String>? extra}) =>
      exploreRepositoryInterface.getPlaces(category, latitude: latitude, longitude: longitude, extra: extra);
}
