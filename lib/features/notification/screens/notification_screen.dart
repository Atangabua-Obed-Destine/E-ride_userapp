import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/notification/controllers/notification_controller.dart';
import 'package:ride_sharing_user_app/features/notification/widgets/notification_card.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/notification/widgets/notification_shimmer.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/no_data_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/paginated_list_widget.dart';

/// Notifications, with chips to show one part of E-Ride (Trips, Market, Jobs...) and the unread count of each.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    final c = Get.find<NotificationController>();
    c.getNotificationList(1);
    c.loadCounts();
    super.initState();
  }

  static IconData _icon(String group) => switch (group) {
        'trips' => Icons.directions_car_outlined,
        'travel' => Icons.directions_bus_outlined,
        'market' => Icons.storefront_outlined,
        'jobs' => Icons.work_outline_rounded,
        'homes' => Icons.home_work_outlined,
        'food' => Icons.restaurant_outlined,
        'safety' => Icons.shield_outlined,
        'wallet' => Icons.account_balance_wallet_outlined,
        _ => Icons.campaign_outlined,
      };

  Widget _chip(BuildContext context, NotificationController c, String? group) {
    final theme = Theme.of(context);
    final selected = c.group == group;
    final unread = group == null ? c.unreadTotal : (c.unreadByGroup[group] ?? 0);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: group == null ? null : Icon(_icon(group), size: 16, color: selected ? theme.primaryColor : theme.hintColor),
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(group == null ? 'notif_group_all'.tr : 'notif_group_$group'.tr),
          if (unread > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(10)),
              child: Text(unread > 99 ? '99+' : '$unread', style: textBold.copyWith(fontSize: 10, color: Colors.white)),
            ),
          ],
        ]),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => c.setGroup(group),
        selectedColor: theme.primaryColor.withValues(alpha: 0.12),
        labelStyle: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: selected ? theme.primaryColor : theme.textTheme.bodyLarge?.color),
        side: BorderSide(color: selected ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.35), width: selected ? 1.5 : 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BodyWidget(
      appBar:  AppBarWidget(title: 'notification'.tr, showBackButton: false,),
      body: Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        child: GetBuilder<NotificationController>(builder: (notificationController) {
          final shown = [for (final g in NotificationController.groups) if (notificationController.groupsWithAny.contains(g)) g];
          final unreadHere = notificationController.group == null
              ? notificationController.unreadTotal
              : (notificationController.unreadByGroup[notificationController.group] ?? 0);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (shown.length > 1)
              SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [
                _chip(context, notificationController, null),
                for (final g in shown) _chip(context, notificationController, g),
              ])),
            if (unreadHere > 0)
              Align(alignment: Alignment.centerRight, child: TextButton.icon(
                onPressed: notificationController.readAll,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: Text(notificationController.group == null ? 'notif_read_all'.tr
                    : 'notif_read_all_in'.trParams({'group': 'notif_group_${notificationController.group}'.tr})),
                style: TextButton.styleFrom(foregroundColor: theme.primaryColor),
              ))
            else if (shown.length > 1)
              const SizedBox(height: 8),

            Expanded(child: notificationController.notificationModel != null ?
              (notificationController.notificationModel!.data != null && notificationController.notificationModel!.data!.isNotEmpty) ?
              RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([notificationController.getNotificationList(1), notificationController.loadCounts()]);
                },
                child: SingleChildScrollView(controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: PaginatedListWidget(
                    scrollController: scrollController,
                    totalSize: notificationController.notificationModel!.totalSize,
                    offset: (notificationController.notificationModel != null && notificationController.notificationModel!.offset != null) ?
                    int.parse(notificationController.notificationModel!.offset.toString()) : null,
                    onPaginate: (int? offset) async {
                      await notificationController.getNotificationList(offset!);
                    },

                    itemView: ListView.builder(
                      itemCount: notificationController.notificationModel!.data!.length,
                      padding: const EdgeInsets.all(0),
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemBuilder: (BuildContext context, int index) {
                        return NotificationCard(
                          previousNotification: index == 0 ? null : notificationController.notificationModel!.data![index - 1],
                          notification: notificationController.notificationModel!.data![index],
                          nextNotification: (index == notificationController.notificationModel!.data!.length-1) ? null : notificationController.notificationModel!.data![index + 1],
                          index: index,
                        );
                      },
                    ),
                  ),
                ),
              ) :
              const NoDataWidget(title: 'no_notification_found') :
              const NotificationShimmer()),

            Container(height: 100),
          ]);
        }),
      ),
    );
  }
}
