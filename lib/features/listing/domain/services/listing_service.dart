import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/features/listing/domain/repositories/listing_repository_interface.dart';
import 'package:ride_sharing_user_app/features/listing/domain/services/listing_service_interface.dart';

class ListingService implements ListingServiceInterface {
  final ListingRepositoryInterface listingRepositoryInterface;
  ListingService({required this.listingRepositoryInterface});

  ListingRepositoryInterface get _repo => listingRepositoryInterface;

  @override
  Future getMeta() => _repo.getMeta();

  @override
  Future search(Map<String, dynamic> query, int offset) => _repo.search(query, offset);

  @override
  Future getMine() => _repo.getMine();

  @override
  Future getListing(String id) => _repo.getListing(id);

  @override
  Future create(Map<String, String> fields, List<XFile> photos) => _repo.create(fields, photos);

  @override
  Future edit(String id, Map<String, String> fields, List<XFile> photos, List<int> removePhotoIds) =>
      _repo.edit(id, fields, photos, removePhotoIds);

  @override
  Future confirm(String id) => _repo.confirm(id);

  @override
  Future markRented(String id) => _repo.markRented(id);

  @override
  Future requestVerification(String id) => _repo.requestVerification(id);

  @override
  Future report(String id, String reason, String? note) => _repo.report(id, reason, note);

  @override
  Future bookVisit(String listingId, String date, String window) => _repo.bookVisit(listingId, date, window);

  @override
  Future getVisits() => _repo.getVisits();

  @override
  Future ownerRespond(String visitId, String action, {String? date, String? window}) =>
      _repo.ownerRespond(visitId, action, date: date, window: window);

  @override
  Future seekerRespond(String visitId, String action) => _repo.seekerRespond(visitId, action);

  @override
  Future outcome(String visitId, String outcome, String? note) => _repo.outcome(visitId, outcome, note);

  @override
  Future taking(String visitId) => _repo.taking(visitId);

  @override
  Future reserve(String visitId, String moveInDate) => _repo.reserve(visitId, moveInDate);

  @override
  Future reservationAction(String reservationId, String action, Map<String, dynamic> body) =>
      _repo.reservationAction(reservationId, action, body);

  @override
  Future reservationPayUrl(String reservationId, String gateway) => _repo.reservationPayUrl(reservationId, gateway);

  @override
  Future getAlerts() => _repo.getAlerts();

  @override
  Future addAlert(Map<String, dynamic> alert) => _repo.addAlert(alert);

  @override
  Future deleteAlert(int id) => _repo.deleteAlert(id);
}
