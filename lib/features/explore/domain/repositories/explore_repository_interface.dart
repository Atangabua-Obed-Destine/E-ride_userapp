import 'package:ride_sharing_user_app/interface/repository_interface.dart';

abstract class ExploreRepositoryInterface implements RepositoryInterface {
  Future<dynamic> getCategories();
  Future<dynamic> getPlaces(String category, {double? latitude, double? longitude, Map<String, String>? extra});
}
