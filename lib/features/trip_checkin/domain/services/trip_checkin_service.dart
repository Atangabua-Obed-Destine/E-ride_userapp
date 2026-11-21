import 'package:ride_sharing_user_app/features/trip_checkin/domain/repositories/trip_checkin_repository_interface.dart';
import 'package:ride_sharing_user_app/features/trip_checkin/domain/services/trip_checkin_service_interface.dart';

class TripCheckinService implements TripCheckinServiceInterface {
  final TripCheckinRepositoryInterface tripCheckinRepositoryInterface;
  TripCheckinService({required this.tripCheckinRepositoryInterface});

  @override
  Future getInfo(String? tripId) => tripCheckinRepositoryInterface.getInfo(tripId);

  @override
  Future answer(String checkinId, String answer) => tripCheckinRepositoryInterface.answer(checkinId, answer);

  @override
  Future setNightShare(String contactId, bool on) => tripCheckinRepositoryInterface.setNightShare(contactId, on);
}
