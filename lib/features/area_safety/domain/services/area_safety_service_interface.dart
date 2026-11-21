abstract class AreaSafetyServiceInterface {
  Future<dynamic> getMeta();
  Future<dynamic> getNearby(double latitude, double longitude);
  Future<dynamic> report(Map<String, dynamic> body);
}
