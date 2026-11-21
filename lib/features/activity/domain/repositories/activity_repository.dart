import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/activity/domain/repositories/activity_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class ActivityRepository implements ActivityRepositoryInterface {
  final ApiClient apiClient;
  ActivityRepository({required this.apiClient});

  @override
  Future getActivity() async {
    return await apiClient.getData(AppConstants.customerActivity);
  }

  @override
  Future add(value) => throw UnimplementedError();

  @override
  Future delete(String id) => throw UnimplementedError();

  @override
  Future get(String id) => throw UnimplementedError();

  @override
  Future getList({int? offset = 1}) => throw UnimplementedError();

  @override
  Future update(value, {int? id}) => throw UnimplementedError();
}
