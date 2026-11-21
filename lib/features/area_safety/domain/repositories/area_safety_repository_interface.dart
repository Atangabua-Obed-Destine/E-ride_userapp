import 'package:ride_sharing_user_app/interface/repository_interface.dart';

abstract class AreaSafetyRepositoryInterface implements RepositoryInterface {
  Future<dynamic> getMeta();
  Future<dynamic> getNearby(double latitude, double longitude);
  Future<dynamic> report(Map<String, dynamic> body);
}
