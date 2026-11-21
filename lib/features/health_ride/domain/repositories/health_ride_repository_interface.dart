import 'package:ride_sharing_user_app/interface/repository_interface.dart';

abstract class HealthRideRepositoryInterface implements RepositoryInterface {
  Future<dynamic> getPlaces(double latitude, double longitude);
}
