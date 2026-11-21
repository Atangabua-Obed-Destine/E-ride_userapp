import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/id_verification/domain/models/id_verification_model.dart';
import 'package:ride_sharing_user_app/features/id_verification/domain/services/id_verification_service_interface.dart';

/// E-Ride ID Verified: where the person stands, and sending their ID card or passport with a selfie.
class IdVerificationController extends GetxController implements GetxService {
  final IdVerificationServiceInterface idVerificationServiceInterface;
  IdVerificationController({required this.idVerificationServiceInterface});

  IdVerificationStatus? status;
  bool loading = false;
  bool sending = false;

  Future<IdVerificationStatus?> load() async {
    loading = status == null;
    update();
    Response response = await idVerificationServiceInterface.getStatus();
    loading = false;
    if (response.statusCode == 200) {
      status = IdVerificationStatus.fromJson(Map<String, dynamic>.from(response.body['data']));
    }
    update();
    return status;
  }

  /// fields: doc_type, doc_number, full_name, expires_on (Y-m-d, optional)
  Future<IdVerificationStatus?> submit(Map<String, String> fields, XFile front, XFile? back, XFile selfie) async {
    if (sending) return null;
    sending = true;
    update();
    Response response = await idVerificationServiceInterface.submit(fields, front, back, selfie);
    sending = false;
    if (response.statusCode == 200) {
      status = IdVerificationStatus.fromJson(Map<String, dynamic>.from(response.body['data']));
      update();
      return status;
    }
    update();
    ApiChecker.checkApi(response);
    return null;
  }
}
