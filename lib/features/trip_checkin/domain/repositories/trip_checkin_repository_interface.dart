import 'package:ride_sharing_user_app/interface/repository_interface.dart';

abstract class TripCheckinRepositoryInterface implements RepositoryInterface {
  Future<dynamic> getInfo(String? tripId);
  Future<dynamic> answer(String checkinId, String answer);
  Future<dynamic> setNightShare(String contactId, bool on);
}
