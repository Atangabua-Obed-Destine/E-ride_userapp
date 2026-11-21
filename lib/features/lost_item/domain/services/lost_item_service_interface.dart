import 'package:image_picker/image_picker.dart';

abstract class LostItemServiceInterface {
  Future<dynamic> getForTrip(String tripId);
  Future<dynamic> report(String tripId, String description, XFile? photo);
  Future<dynamic> act(String id, String action);
}
