abstract class NotificationServiceInterface{
  Future<dynamic> getList({int? offset = 1});
  Future<dynamic> getGroupList({int offset = 1, String? group});
  Future<dynamic> getCounts();
  Future<dynamic> readAll({String? group});
  Future<dynamic> sendReadStatus(int notificationId);
}
