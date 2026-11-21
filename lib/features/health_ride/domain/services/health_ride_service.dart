import 'package:ride_sharing_user_app/features/health_ride/domain/repositories/health_ride_repository_interface.dart';
import 'package:ride_sharing_user_app/features/health_ride/domain/services/health_ride_service_interface.dart';

class HealthRideService implements HealthRideServiceInterface {
  final HealthRideRepositoryInterface healthRideRepositoryInterface;
  HealthRideService({required this.healthRideRepositoryInterface});

  @override
  Future getPlaces(double latitude, double longitude) => healthRideRepositoryInterface.getPlaces(latitude, longitude);
}
