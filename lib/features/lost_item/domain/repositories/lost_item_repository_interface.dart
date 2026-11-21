import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/interface/repository_interface.dart';

abstract class LostItemRepositoryInterface implements RepositoryInterface {
  Future<dynamic> getForTrip(String tripId);
  Future<dynamic> report(String tripId, String description, XFile? photo);
  Future<dynamic> act(String id, String action);
}
