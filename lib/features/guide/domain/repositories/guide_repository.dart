import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/guide/domain/repositories/guide_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class GuideRepository implements GuideRepositoryInterface {
  final ApiClient apiClient;
  GuideRepository({required this.apiClient});

  static Map<String, String>? _point(double? latitude, double? longitude) =>
      latitude != null && longitude != null ? {'latitude': '$latitude', 'longitude': '$longitude'} : null;

  @override
  Future getThings({double? latitude, double? longitude}) =>
      apiClient.getData(AppConstants.guideThings, query: _point(latitude, longitude));

  @override
  Future getPlaceGuide(String id, {double? latitude, double? longitude}) =>
      apiClient.getData('${AppConstants.guidePlaces}/${Uri.encodeComponent(id)}/guide', query: _point(latitude, longitude));

  @override
  Future ratePlace(String id, {required int stars, String? comment, String? name}) =>
      apiClient.postData('${AppConstants.guidePlaces}/${Uri.encodeComponent(id)}/rate', {
        'stars': stars,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        if (name != null) 'name': name,
      });

  @override
  Future getTours({double? latitude, double? longitude}) =>
      apiClient.getData(AppConstants.guideTours, query: _point(latitude, longitude));

  @override
  Future getTour(String id, {double? latitude, double? longitude}) =>
      apiClient.getData('${AppConstants.guideTours}/${Uri.encodeComponent(id)}', query: _point(latitude, longitude));

  @override
  Future add(value) => throw UnimplementedError();

  @override
  Future delete(String id) => throw UnimplementedError();

  @override
  Future get(String id) => throw UnimplementedError();

  @override
  Future getList({int? offset = 1}) => throw UnimplementedError();

  @override
  Future update(value, {int? id}) => throw UnimplementedError();
}
