import 'package:ride_sharing_user_app/data/api_client.dart';

abstract class MoveServiceInterface {
  Future<dynamic> uploadPhotos(List<MultipartBody> photos);
  Future<dynamic> getDirectory(String? vehicleCategoryId);
  Future<dynamic> logContact(String listingId, String channel);
  Future<dynamic> noAgreement(String tripId);
}
