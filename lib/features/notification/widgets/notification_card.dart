import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/notification/controllers/notification_controller.dart';
import 'package:ride_sharing_user_app/features/notification/domain/models/notification_model.dart';
import 'package:ride_sharing_user_app/features/notification/helpers/notification_open.dart';
import 'package:ride_sharing_user_app/helper/date_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// One notification: icon tile (red while unread, grey once read), title,
/// one-line description, time, and a red dot for unread. Day labels are
/// drawn as small uppercase eyebrows between groups. Tapping marks it read
/// and opens the detail sheet, exactly as before.
class NotificationCard extends StatelessWidget {
  final Notifications notification;
  final Notifications? previousNotification;
  final Notifications? nextNotification;
  final int? index;
  const NotificationCard({super.key, required this.notification, required this.nextNotification, required this.previousNotification, this.index});

  bool get _read => notification.isRead ?? false;

  @override
  Widget build(BuildContext context) {
    int currentNotificationMinutes = calculateMinute(notification.createdAt!);
    final Color hint = Theme.of(context).hintColor;
    final Color text = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final Color accent = Theme.of(context).primaryColor;
    final Color tone = _read ? hint : accent;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if(previousNotification == null)
        _DayLabel(text: _dayText(notification.createdAt!)),

      Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openDetails(context),
          child: Container(
            padding: const EdgeInsets.all(Dimensions.paddingSize),
            margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: hint.withValues(alpha: 0.14)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: tone.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13)),
                child: Center(child: _groupIcon(notification.group) != null
                    ? Icon(_groupIcon(notification.group), size: 21, color: tone)
                    : Image.asset(
                        _getIcons(notification.notificationType ?? ''),
                        width: 20, height: 20, fit: BoxFit.contain, color: tone,
                      )),
              ),
              const SizedBox(width: Dimensions.paddingSize),

              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(
                    notification.title ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: (_read ? textMedium : textSemiBold).copyWith(fontSize: Dimensions.fontSizeDefault, color: text),
                  )),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Text(
                    currentNotificationMinutes < 1 ? 'just_now'.tr
                        : currentNotificationMinutes < 60 ? '$currentNotificationMinutes ${'min_ago'.tr}'
                        : DateConverter.isoDateTimeStringToLocalTime(notification.createdAt!),
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: hint),
                  ),
                  if (!_read) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 8, height: 8,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                    ),
                  ],
                ]),
                const SizedBox(height: 3),

                Text(
                  notification.description ?? '',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: _read ? hint : text.withValues(alpha: 0.8),
                  ),
                ),
              ])),
            ]),
          ),
        ),
      ),

      if(((nextNotification == null) && (previousNotification != null) &&
          (DateConverter.isoStringToLocalDateAndMonthOnly(notification.createdAt!) != DateConverter.isoStringToLocalDateAndMonthOnly(previousNotification!.createdAt!))))
        _DayLabel(text: _dayText(notification.createdAt ?? '2024-07-13T04:59:40.000000Z', todayAllowed: false)),

      if((nextNotification != null) &&
          (DateConverter.isoStringToLocalDateAndMonthOnly(notification.createdAt!) != DateConverter.isoStringToLocalDateAndMonthOnly(nextNotification!.createdAt!)))
        _DayLabel(text: _dayText(nextNotification?.createdAt ?? '2024-07-13T04:59:40.000000Z', todayAllowed: false)),
    ]);
  }

  static String _dayText(String iso, {bool todayAllowed = true}) {
    final String day = DateConverter.isoStringToLocalDateAndMonthOnly(iso);
    if (todayAllowed && day == DateConverter.localDateTimeToDateAndMonthOnly(DateTime.now())) return 'today'.tr;
    if (day == DateConverter.localDateTimeToDateAndMonthOnly(DateTime.now().subtract(const Duration(days: 1)))) return 'last_day'.tr;
    return DateConverter.isoDateTimeStringToDateOnly(iso);
  }

  void _openDetails(BuildContext context) {
    Get.find<NotificationController>().sendReadStatus(notification.id ?? 0, index ?? 0);
    Get.bottomSheet(Container(
      width: Get.width,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 44, height: 4,
            margin: const EdgeInsets.only(top: 4, bottom: Dimensions.paddingSizeLarge),
            decoration: BoxDecoration(
              color: Theme.of(context).hintColor.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: _groupIcon(notification.group) != null
                ? Icon(_groupIcon(notification.group), size: 26, color: Theme.of(context).primaryColor)
                : Image.asset(
                    _getIcons(notification.notificationType ?? ''),
                    width: 24, height: 24, fit: BoxFit.contain,
                    color: Theme.of(context).primaryColor,
                  )),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          Text(notification.title ?? '',
              style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge),
              textAlign: TextAlign.center
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),

          Text(
            notification.description ?? '', textAlign: TextAlign.center,
            style: textRegular.copyWith(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          // Where it needs the person: the chat, the order, the job, the trip...
          if (NotificationOpen.label(notification) != null) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () {
                  Get.back();
                  NotificationOpen.open(notification);
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: Text(NotificationOpen.label(notification)!.tr, style: textSemiBold.copyWith(color: Colors.white)),
              ),
            ),
          ],
          const SizedBox(height: 30),
        ]),
      ),
    ));
  }
}

class _DayLabel extends StatelessWidget {
  final String text;
  const _DayLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, Dimensions.paddingSizeSmall, 0, Dimensions.paddingSizeSmall),
      child: Text(
        text.toUpperCase(),
        style: textSemiBold.copyWith(
          fontSize: Dimensions.fontSizeExtraSmall,
          letterSpacing: 1.2,
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }
}

/// Parts of E-Ride without their own notification image get an icon that says where the notification is from.
IconData? _groupIcon(String? group) => switch (group) {
      'travel' => Icons.directions_bus_outlined,
      'market' => Icons.storefront_outlined,
      'jobs' => Icons.work_outline_rounded,
      'homes' => Icons.home_work_outlined,
      'food' => Icons.restaurant_outlined,
      'safety' => Icons.shield_outlined,
      _ => null,
    };

String _getIcons(String notificationType){
  switch (notificationType) {
    case 'trip':
    return Images.notificationTripIcon;

    case 'parcel':
      return Images.notificationParcelIcon;

    case 'coupon':
      return Images.notificationCouponIcon;

    case 'review':
      return Images.notificationReviewIcon;

    case 'referral_code':
      return Images.notificationReferralIcon;

    case 'safety_alert':
      return Images.notificationSafetyAlertIcon;

    case 'business_page':
      return Images.notificationBusinessIcon;

    case 'chatting':
      return Images.notificationChattingIcon;

    case 'level':
      return Images.notificationLevelIcon;

    case 'fund':
      return Images.notificationFundIcon;

    case 'withdraw_request':
      return Images.notificationWalletIcon;

    default:
    return Images.notificationOthersIcon;
  }

}

int calculateMinute(String isoDateTime){
  DateTime dateTime = DateConverter.isoStringToLocalDate(isoDateTime);
  return DateTime.now().difference(dateTime).inMinutes;
}
