import 'package:ride_sharing_user_app/features/activity/domain/repositories/activity_repository_interface.dart';
import 'package:ride_sharing_user_app/features/activity/domain/services/activity_service_interface.dart';

class ActivityService implements ActivityServiceInterface {
  final ActivityRepositoryInterface activityRepositoryInterface;
  ActivityService({required this.activityRepositoryInterface});

  @override
  Future getActivity() => activityRepositoryInterface.getActivity();
}
