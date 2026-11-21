import 'package:ride_sharing_user_app/helper/image_size_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/bus/widgets/bus_widgets.dart';
import 'package:ride_sharing_user_app/features/hotel/controllers/hotel_controller.dart';
import 'package:ride_sharing_user_app/features/hotel/domain/models/hotel_models.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

const Color hotelGreen = Color(0xFF15803D);
const Color hotelAmber = Color(0xFF8A4F00);
const Color hotelAmberBg = Color(0xFFFFF4E5);

String hotelMoney(int? v) {
  if (v == null) return '';
  final s = v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return 'FCFA $s';
}

/// "Mon 16 to Tue 17 · 1 night"
String hotelDates(DateTime from, DateTime to) {
  final n = to.difference(from).inDays;
  return '${busDay(from)} → ${busDay(to)} · ${(n == 1 ? 'hotel_one_night' : 'hotel_n_nights').trParams({'n': '$n'})}';
}

String? hotelAnswerText(int? minutes) {
  if (minutes == null) return null;
  if (minutes <= 5) return 'hotel_answers_5'.tr;
  if (minutes < 60) return 'hotel_answers_min'.trParams({'n': '${((minutes + 4) ~/ 5) * 5}'});
  return 'hotel_answers_hours'.trParams({'n': '${(minutes / 60).ceil()}'});
}

String hotelArrival(String? a) {
  if (a == null) return '';
  if (a == 'afternoon' || a == 'evening' || a == 'late') return 'hotel_arrive_$a'.tr;
  return 'hotel_arrive_at'.trParams({'time': a});
}

/// A small tinted label.
class HotelChip extends StatelessWidget {
  final String text;
  final Color color;
  final Color? background;
  final IconData? icon;
  const HotelChip({super.key, required this.text, required this.color, this.background, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: background ?? color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: color))),
      ]),
    );
  }
}

/// How many rooms are free for the dates, or "Ask the reception" when the hotel's counts are not up to date.
class HotelFreeChip extends StatelessWidget {
  final int? free;
  final bool perType;
  const HotelFreeChip({super.key, required this.free, this.perType = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (free == null) return HotelChip(text: 'hotel_ask_reception'.tr, color: theme.hintColor, icon: Icons.chat_bubble_outline_rounded);
    if (free == 0) return HotelChip(text: perType ? 'hotel_full'.tr : 'hotel_full_dates'.tr, color: theme.hintColor);
    if (free == 1) return HotelChip(text: perType ? 'hotel_last_one'.tr : 'hotel_last_room'.tr, color: hotelAmber, background: hotelAmberBg);
    return HotelChip(text: (perType ? 'hotel_n_free' : 'hotel_n_rooms_free').trParams({'n': '$free'}), color: hotelGreen);
  }
}

/// The partner line on a hotel card in Explore: free rooms and answer time.
class HotelPartnerChips extends StatelessWidget {
  final HotelPartnerInfo partner;
  const HotelPartnerChips({super.key, required this.partner});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answer = hotelAnswerText(partner.answerMinutes);
    return Wrap(spacing: 6, runSpacing: 6, children: [
      HotelFreeChip(free: partner.freeRooms),
      if (answer != null) HotelChip(text: answer, color: theme.textTheme.bodyMedium?.color ?? Colors.black87, background: theme.hintColor.withValues(alpha: 0.10)),
    ]);
  }
}

/// The dates bar: tap to choose arrival and leaving days.
class HotelDatesBar extends StatelessWidget {
  final VoidCallback? onChanged;
  final int maxNights;
  final int daysAhead;
  const HotelDatesBar({super.key, this.onChanged, this.maxNights = 30, this.daysAhead = 120});

  Future<void> pick(BuildContext context) async {
    final c = Get.find<HotelController>();
    final now = HotelController.day(DateTime.now());
    final range = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(Duration(days: daysAhead)),
      initialDateRange: DateTimeRange(start: c.checkIn, end: c.checkOut),
      helpText: 'hotel_pick_dates'.tr,
      saveText: 'hotel_done'.tr,
    );
    if (range == null) return;
    var end = range.end.isAfter(range.start) ? range.end : range.start.add(const Duration(days: 1));
    if (end.difference(range.start).inDays > maxNights) end = range.start.add(Duration(days: maxNights));
    c.setDates(range.start, end);
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GetBuilder<HotelController>(builder: (c) {
      return Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => pick(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.hintColor.withValues(alpha: 0.3))),
            child: Row(children: [
              Icon(Icons.calendar_month_rounded, color: theme.primaryColor, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(hotelDates(c.checkIn, c.checkOut), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color))),
              Text('hotel_change'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
            ]),
          ),
        ),
      );
    });
  }
}

/// A photo from the network with a quiet placeholder.
class HotelPhoto extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BorderRadius? radius;
  const HotelPhoto({super.key, this.url, this.width, this.height, this.radius});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Container(
      width: width, height: height, color: theme.hintColor.withValues(alpha: 0.12),
      alignment: Alignment.center, child: Icon(Icons.bed_rounded, color: theme.hintColor.withValues(alpha: 0.6)),
    );
    final child = url == null
        ? placeholder
        : Image.network(url!, width: width, height: height, fit: BoxFit.cover, cacheWidth: ImageSizeHelper.decodeWidth(context, width, height), errorBuilder: (_, __, ___) => placeholder);
    return ClipRRect(borderRadius: radius ?? BorderRadius.zero, child: child);
  }
}
