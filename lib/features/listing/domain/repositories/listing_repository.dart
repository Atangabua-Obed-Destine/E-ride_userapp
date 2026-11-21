import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/listing/domain/repositories/listing_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class ListingRepository implements ListingRepositoryInterface {
  final ApiClient apiClient;
  ListingRepository({required this.apiClient});

  @override
  Future getMeta() => apiClient.getData('${AppConstants.listings}/meta');

  @override
  Future search(Map<String, dynamic> query, int offset) =>
      apiClient.getData(AppConstants.listings, query: {...query, 'limit': 20, 'offset': offset});

  @override
  Future getMine() => apiClient.getData('${AppConstants.listings}/mine');

  @override
  Future getListing(String id) => apiClient.getData('${AppConstants.listings}/$id');

  List<MultipartBody> _photos(List<XFile> photos) =>
      [for (int i = 0; i < photos.length; i++) MultipartBody('photos[$i]', photos[i])];

  @override
  Future create(Map<String, String> fields, List<XFile> photos) =>
      apiClient.postMultipartData(AppConstants.listings, fields, MultipartBody('', null), _photos(photos));

  @override
  Future edit(String id, Map<String, String> fields, List<XFile> photos, List<int> removePhotoIds) => apiClient.postMultipartData(
        '${AppConstants.listings}/$id/update',
        {...fields, for (int i = 0; i < removePhotoIds.length; i++) 'remove_photos[$i]': '${removePhotoIds[i]}'},
        MultipartBody('', null),
        _photos(photos),
      );

  @override
  Future confirm(String id) => apiClient.postData('${AppConstants.listings}/$id/confirm', {});

  @override
  Future markRented(String id) => apiClient.postData('${AppConstants.listings}/$id/rented', {});

  @override
  Future requestVerification(String id) => apiClient.postData('${AppConstants.listings}/$id/verification', {});

  @override
  Future report(String id, String reason, String? note) =>
      apiClient.postData('${AppConstants.listings}/$id/report', {'reason': reason, if (note != null && note.isNotEmpty) 'note': note});

  @override
  Future bookVisit(String listingId, String date, String window) =>
      apiClient.postData('${AppConstants.listings}/$listingId/visits', {'date': date, 'window': window});

  @override
  Future getVisits() => apiClient.getData(AppConstants.listingVisits);

  @override
  Future ownerRespond(String visitId, String action, {String? date, String? window}) => apiClient.postData(
        '${AppConstants.listingVisits}/$visitId/respond',
        {'action': action, if (date != null) 'date': date, if (window != null) 'window': window},
      );

  @override
  Future seekerRespond(String visitId, String action) =>
      apiClient.postData('${AppConstants.listingVisits}/$visitId/seeker', {'action': action});

  @override
  Future outcome(String visitId, String outcome, String? note) => apiClient.postData(
        '${AppConstants.listingVisits}/$visitId/outcome', {'outcome': outcome, if (note != null && note.isNotEmpty) 'note': note});

  @override
  Future taking(String visitId) => apiClient.postData('${AppConstants.listingVisits}/$visitId/taking', {});

  @override
  Future reserve(String visitId, String moveInDate) =>
      apiClient.postData('${AppConstants.listingVisits}/$visitId/reserve', {'move_in_date': moveInDate});

  @override
  Future reservationAction(String reservationId, String action, Map<String, dynamic> body) =>
      apiClient.postData('${AppConstants.listingReservations}/$reservationId/$action', body);

  @override
  Future reservationPayUrl(String reservationId, String gateway) =>
      apiClient.getData('${AppConstants.listingReservations}/$reservationId/pay-url', query: {'payment_method': gateway});

  @override
  Future getAlerts() => apiClient.getData(AppConstants.listingAlerts);

  @override
  Future addAlert(Map<String, dynamic> alert) => apiClient.postData(AppConstants.listingAlerts, alert);

  @override
  Future deleteAlert(int id) => apiClient.deleteData('${AppConstants.listingAlerts}/$id');

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
