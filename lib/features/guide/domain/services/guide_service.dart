import 'package:ride_sharing_user_app/features/guide/domain/repositories/guide_repository_interface.dart';
import 'package:ride_sharing_user_app/features/guide/domain/services/guide_service_interface.dart';

class GuideService implements GuideServiceInterface {
  final GuideRepositoryInterface guideRepositoryInterface;
  GuideService({required this.guideRepositoryInterface});

  @override
  Future getThings({double? latitude, double? longitude}) => guideRepositoryInterface.getThings(latitude: latitude, longitude: longitude);

  @override
  Future getPlaceGuide(String id, {double? latitude, double? longitude}) =>
      guideRepositoryInterface.getPlaceGuide(id, latitude: latitude, longitude: longitude);

  @override
  Future ratePlace(String id, {required int stars, String? comment, String? name}) =>
      guideRepositoryInterface.ratePlace(id, stars: stars, comment: comment, name: name);

  @override
  Future getTours({double? latitude, double? longitude}) => guideRepositoryInterface.getTours(latitude: latitude, longitude: longitude);

  @override
  Future getTour(String id, {double? latitude, double? longitude}) =>
      guideRepositoryInterface.getTour(id, latitude: latitude, longitude: longitude);
}
