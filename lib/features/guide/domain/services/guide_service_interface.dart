abstract class GuideServiceInterface {
  Future<dynamic> getThings({double? latitude, double? longitude});
  Future<dynamic> getPlaceGuide(String id, {double? latitude, double? longitude});
  Future<dynamic> ratePlace(String id, {required int stars, String? comment, String? name});
  Future<dynamic> getTours({double? latitude, double? longitude});
  Future<dynamic> getTour(String id, {double? latitude, double? longitude});
}
