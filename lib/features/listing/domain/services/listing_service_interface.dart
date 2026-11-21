import 'package:image_picker/image_picker.dart';

abstract class ListingServiceInterface {
  Future<dynamic> getMeta();
  Future<dynamic> search(Map<String, dynamic> query, int offset);
  Future<dynamic> getMine();
  Future<dynamic> getListing(String id);
  Future<dynamic> create(Map<String, String> fields, List<XFile> photos);
  Future<dynamic> edit(String id, Map<String, String> fields, List<XFile> photos, List<int> removePhotoIds);
  Future<dynamic> confirm(String id);
  Future<dynamic> markRented(String id);
  Future<dynamic> requestVerification(String id);
  Future<dynamic> report(String id, String reason, String? note);
  Future<dynamic> bookVisit(String listingId, String date, String window);
  Future<dynamic> getVisits();
  Future<dynamic> ownerRespond(String visitId, String action, {String? date, String? window});
  Future<dynamic> seekerRespond(String visitId, String action);
  Future<dynamic> outcome(String visitId, String outcome, String? note);
  Future<dynamic> taking(String visitId);
  Future<dynamic> reserve(String visitId, String moveInDate);
  /// {id}/wallet, cancel, respond, moved-in, problem, refund-to-momo.
  Future<dynamic> reservationAction(String reservationId, String action, Map<String, dynamic> body);
  Future<dynamic> reservationPayUrl(String reservationId, String gateway);
  Future<dynamic> getAlerts();
  Future<dynamic> addAlert(Map<String, dynamic> alert);
  Future<dynamic> deleteAlert(int id);
}
