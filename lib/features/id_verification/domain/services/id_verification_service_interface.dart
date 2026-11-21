import 'package:image_picker/image_picker.dart';

abstract class IdVerificationServiceInterface {
  Future<dynamic> getStatus();
  Future<dynamic> submit(Map<String, String> fields, XFile front, XFile? back, XFile selfie);
}
