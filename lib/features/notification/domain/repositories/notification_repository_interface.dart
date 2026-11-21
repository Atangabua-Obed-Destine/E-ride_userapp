import 'package:ride_sharing_user_app/interface/repository_interface.dart';

abstract class NotificationRepositoryInterface implements RepositoryInterface{
  Future<dynamic> sendReadStatus(int notificationId);
  Future<dynamic> getGroupList({int offset = 1, String? group});
  Future<dynamic> getCounts();
  Future<dynamic> readAll({String? group});
}
