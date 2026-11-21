import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/move/domain/models/move_listing_model.dart';
import 'package:ride_sharing_user_app/features/move/domain/services/move_service_interface.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/file_validation_helper.dart';

/// E-Ride Move: photos of the load before booking, the truck owner directory
/// for when no truck is available, and "We couldn't agree" at the pickup.
/// The move itself is booked through RideController (move mode).
class MoveController extends GetxController implements GetxService {
  final MoveServiceInterface moveServiceInterface;
  MoveController({required this.moveServiceInterface});

  static const int maxPhotos = 3;

  List<XFile> photos = [];
  bool uploading = false;

  List<MoveListing>? directory;
  bool loadingDirectory = false;

  bool cancelling = false;

  void resetBooking() {
    photos = [];
    uploading = false;
    update();
  }

  Future<void> pickPhoto(ImageSource source) async {
    if (photos.length >= maxPhotos) return;
    final XFile? image = await FileValidationHelper.validateAndPickImage(source: source, imageQuality: 70);
    if (image != null) {
      photos.add(image);
      update();
    }
  }

  void removePhoto(int index) {
    photos.removeAt(index);
    update();
  }

  /// Sends the photos and returns their server names, for the request.
  /// Null when the upload failed (the request should not go out then).
  Future<List<String>?> uploadPhotos() async {
    if (photos.isEmpty) return [];
    uploading = true;
    update();
    final Response response = await moveServiceInterface.uploadPhotos([
      for (final XFile photo in photos) MultipartBody('photos[]', photo),
    ]);
    uploading = false;
    update();
    if (response.statusCode == 200 && response.body['data']?['photos'] is List) {
      return List<String>.from((response.body['data']['photos'] as List).map((e) => '$e'));
    }
    showCustomSnackBar(firstError(response));
    return null;
  }

  Future<void> getDirectory(String? vehicleCategoryId) async {
    loadingDirectory = true;
    update();
    final Response response = await moveServiceInterface.getDirectory(vehicleCategoryId);
    loadingDirectory = false;
    if (response.statusCode == 200 && response.body['data'] is List) {
      directory = [
        for (final item in response.body['data'] as List)
          if (item is Map<String, dynamic>) MoveListing.fromJson(item),
      ];
    } else {
      directory ??= [];
    }
    update();
  }

  /// Counted on the server so E-Ride knows which owners get work. Fire and forget.
  void logContact(MoveListing listing, String channel) {
    moveServiceInterface.logContact(listing.id, channel);
  }

  /// "We couldn't agree" on the price at the pickup. True when the move was cancelled.
  Future<bool> noAgreement(String tripId) async {
    if (cancelling) return false;
    cancelling = true;
    update();
    final Response response = await moveServiceInterface.noAgreement(tripId);
    cancelling = false;
    update();
    if (response.statusCode == 200) return true;
    showCustomSnackBar(firstError(response));
    return false;
  }

  static String firstError(Response response) {
    final body = response.body;
    if (body is Map) {
      final errors = body['errors'];
      if (errors is List && errors.isNotEmpty && errors.first is Map) return errors.first['message'].toString();
      if (errors is Map && errors.isNotEmpty) return (errors.values.first is List ? errors.values.first.first : errors.values.first).toString();
      if (body['message'] != null) return body['message'].toString();
    }
    return 'something_went_wrong'.tr;
  }
}
