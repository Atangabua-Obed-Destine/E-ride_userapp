abstract class ExploreServiceInterface {
  Future<dynamic> getCategories();
  Future<dynamic> getPlaces(String category, {double? latitude, double? longitude, Map<String, String>? extra});
}
