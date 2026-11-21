import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/id_verification/domain/repositories/id_verification_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class IdVerificationRepository implements IdVerificationRepositoryInterface {
  final ApiClient apiClient;
  IdVerificationRepository({required this.apiClient});

  @override
  Future getStatus() => apiClient.getData(AppConstants.idVerification);

  @override
  Future submit(Map<String, String> fields, XFile front, XFile? back, XFile selfie) => apiClient.postMultipartData(
      AppConstants.idVerification, fields, MultipartBody('front', front), [MultipartBody('back', back), MultipartBody('selfie', selfie)]);
}
