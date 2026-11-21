import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/features/lost_item/domain/repositories/lost_item_repository_interface.dart';
import 'package:ride_sharing_user_app/features/lost_item/domain/services/lost_item_service_interface.dart';

class LostItemService implements LostItemServiceInterface {
  final LostItemRepositoryInterface lostItemRepositoryInterface;
  LostItemService({required this.lostItemRepositoryInterface});

  @override
  Future getForTrip(String tripId) => lostItemRepositoryInterface.getForTrip(tripId);

  @override
  Future report(String tripId, String description, XFile? photo) => lostItemRepositoryInterface.report(tripId, description, photo);

  @override
  Future act(String id, String action) => lostItemRepositoryInterface.act(id, action);
}
