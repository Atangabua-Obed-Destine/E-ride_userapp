import 'package:ride_sharing_user_app/interface/repository_interface.dart';

abstract class ActivityRepositoryInterface implements RepositoryInterface {
  /// GET /api/customer/activity: food orders, bus bookings and hotel chats in progress.
  Future<dynamic> getActivity();
}
