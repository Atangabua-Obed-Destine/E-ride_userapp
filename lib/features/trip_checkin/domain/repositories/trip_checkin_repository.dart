import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/trip_checkin/domain/repositories/trip_checkin_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class TripCheckinRepository implements TripCheckinRepositoryInterface {
  final ApiClient apiClient;
  TripCheckinRepository({required this.apiClient});

  @override
  Future getInfo(String? tripId) =>
      apiClient.getData(AppConstants.tripCheckin, query: tripId == null ? null : {'trip_request_id': tripId});

  @override
  Future answer(String checkinId, String answer) =>
      apiClient.postData('${AppConstants.tripCheckin}/$checkinId/answer', {'answer': answer});

  @override
  Future setNightShare(String contactId, bool on) =>
      apiClient.postData('${AppConstants.trustedContacts}/$contactId/night-share', {'on': on});

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
