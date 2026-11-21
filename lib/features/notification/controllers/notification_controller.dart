import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/notification/domain/models/notification_model.dart';
import 'package:ride_sharing_user_app/features/notification/domain/services/notification_service_interface.dart';

/// The notification list (all, or one part of E-Ride), the unread counts for the filter chips
/// and the Notification tab's badge, and "mark all as read".
class NotificationController extends GetxController implements GetxService {
  final NotificationServiceInterface notificationServiceInterface;
  NotificationController({required this.notificationServiceInterface});

  /// The groups the server knows, in the order of the chips.
  static const List<String> groups = ['trips', 'travel', 'market', 'jobs', 'homes', 'food', 'safety', 'wallet', 'other'];

  bool isLoading = false;
  NotificationsModel? notificationModel;
  /// null: all notifications.
  String? group;
  int _call = 0;

  int unreadTotal = 0;
  final Map<String, int> unreadByGroup = {};
  final Set<String> groupsWithAny = {};

  Future<void> getNotificationList(int offset, {bool reload = false}) async {
    final call = ++_call;
    isLoading = true;
    final String? g = group;
    Response response = await notificationServiceInterface.getGroupList(offset: offset, group: g);
    if (call != _call && offset == 1) return;
    if (response.statusCode == 200) {
      if (offset == 1) {
        notificationModel = NotificationsModel.fromJson(response.body);
      } else {
        notificationModel?.data!.addAll(NotificationsModel.fromJson(response.body).data!);
        notificationModel?.offset = NotificationsModel.fromJson(response.body).offset;
        notificationModel?.totalSize = NotificationsModel.fromJson(response.body).totalSize;
      }
      isLoading = false;
    } else {
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    update();
  }

  /// Show one group (or all with null), from the first page.
  void setGroup(String? value) {
    group = group == value ? null : value;
    notificationModel = null;
    update();
    getNotificationList(1);
  }

  Future<void> loadCounts() async {
    Response response = await notificationServiceInterface.getCounts();
    if (response.statusCode == 200 && response.body['data'] is Map) {
      final data = response.body['data'];
      unreadTotal = int.tryParse('${data['unread']}') ?? 0;
      unreadByGroup.clear();
      groupsWithAny.clear();
      for (final g in (data['groups'] as List? ?? const [])) {
        final name = '${g['group']}';
        unreadByGroup[name] = int.tryParse('${g['unread']}') ?? 0;
        if (g['has'] == true) groupsWithAny.add(name);
      }
      update();
    }
  }

  /// Mark everything read, or the group on screen.
  Future<void> readAll() async {
    Response response = await notificationServiceInterface.readAll(group: group);
    if (response.statusCode == 200) {
      for (final n in notificationModel?.data ?? <Notifications>[]) {
        n.isRead = true;
      }
      update();
      loadCounts();
    } else {
      ApiChecker.checkApi(response);
    }
  }

  Future<void> sendReadStatus(int notificationId, int index) async {
    final wasUnread = !(notificationModel?.data?[index].isRead ?? true);
    Response response = await notificationServiceInterface.sendReadStatus(notificationId);
    if (response.statusCode == 200) {
      notificationModel?.data?[index].isRead = true;
      if (wasUnread) {
        final g = notificationModel?.data?[index].group;
        if (unreadTotal > 0) unreadTotal--;
        if (g != null && (unreadByGroup[g] ?? 0) > 0) unreadByGroup[g] = unreadByGroup[g]! - 1;
      }
    } else {
      ApiChecker.checkApi(response);
    }
    update();
  }
}
