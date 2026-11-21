import 'package:ride_sharing_user_app/features/notification/domain/repositories/notification_repository_interface.dart';
import 'package:ride_sharing_user_app/features/notification/domain/services/notification_service_interface.dart';

class NotificationService implements NotificationServiceInterface{
  NotificationRepositoryInterface notificationRepositoryInterface;

  NotificationService({required this.notificationRepositoryInterface});

  @override
  Future getList({int? offset = 1}) async{
    return await notificationRepositoryInterface.getList(offset: offset);
  }

  @override
  Future getGroupList({int offset = 1, String? group}) async{
    return await notificationRepositoryInterface.getGroupList(offset: offset, group: group);
  }

  @override
  Future getCounts() async{
    return await notificationRepositoryInterface.getCounts();
  }

  @override
  Future readAll({String? group}) async{
    return await notificationRepositoryInterface.readAll(group: group);
  }

  @override
  Future sendReadStatus(int notificationId) async{
    return await notificationRepositoryInterface.sendReadStatus(notificationId);
  }

}