abstract class TripCheckinServiceInterface {
  Future<dynamic> getInfo(String? tripId);
  Future<dynamic> answer(String checkinId, String answer);
  Future<dynamic> setNightShare(String contactId, bool on);
}
