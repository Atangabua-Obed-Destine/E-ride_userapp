import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/features/id_verification/domain/repositories/id_verification_repository_interface.dart';
import 'package:ride_sharing_user_app/features/id_verification/domain/services/id_verification_service_interface.dart';

class IdVerificationService implements IdVerificationServiceInterface {
  final IdVerificationRepositoryInterface idVerificationRepositoryInterface;
  IdVerificationService({required this.idVerificationRepositoryInterface});

  @override
  Future getStatus() => idVerificationRepositoryInterface.getStatus();

  @override
  Future submit(Map<String, String> fields, XFile front, XFile? back, XFile selfie) =>
      idVerificationRepositoryInterface.submit(fields, front, back, selfie);
}
