import 'package:ride_sharing_user_app/features/area_safety/domain/repositories/area_safety_repository_interface.dart';
import 'package:ride_sharing_user_app/features/area_safety/domain/services/area_safety_service_interface.dart';

class AreaSafetyService implements AreaSafetyServiceInterface {
  final AreaSafetyRepositoryInterface areaSafetyRepositoryInterface;
  AreaSafetyService({required this.areaSafetyRepositoryInterface});

  @override
  Future getMeta() => areaSafetyRepositoryInterface.getMeta();

  @override
  Future getNearby(double latitude, double longitude) => areaSafetyRepositoryInterface.getNearby(latitude, longitude);

  @override
  Future report(Map<String, dynamic> body) => areaSafetyRepositoryInterface.report(body);
}
