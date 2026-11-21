import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Services get a green of their own.
const Color marketServiceFg = Color(0xFF047857);
const Color marketServiceBg = Color(0xFFECFDF5);

/// "From 8 000 FCFA", "2 500 FCFA / hour", "Ask for a quote".
String marketServicePrice(double? price, String priceType) {
  if (priceType == 'quote' || price == null) return 'market_ask_quote'.tr;
  final p = PriceConverter.convertPrice(price);
  return switch (priceType) {
    'from' => 'market_price_from'.trParams({'price': p}),
    'hour' => 'market_price_hour'.trParams({'price': p}),
    _ => p,
  };
}

/// "30 min", "1 h", "1 h 30", "4 h".
String marketDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

String _two(int v) => v.toString().padLeft(2, '0');

/// "Today", "Tomorrow", "Mon 16".
String marketDayLabel(DateTime d) {
  final now = DateTime.now();
  final day = DateTime(d.year, d.month, d.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'market_today_cap'.tr;
  if (diff == 1) return 'market_tomorrow'.tr;
  return '${'market_wd_${d.weekday}'.tr} ${d.day}';
}

/// "Today 15:00", "Mon 16 Nov, 09:00".
String marketWhen(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  final now = DateTime.now();
  final diff = DateTime(l.year, l.month, l.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  final hm = '${_two(l.hour)}:${_two(l.minute)}';
  if (diff == 0) return '${'market_today_cap'.tr} $hm';
  if (diff == 1) return '${'market_tomorrow'.tr} $hm';
  return '${'market_wd_${l.weekday}'.tr} ${l.day} ${'market_mo_${l.month}'.tr}, $hm';
}

/// Chips in the Market: the chosen one is a light brand tint with brand text and border.
class MarketChips extends StatelessWidget {
  final Widget child;
  const MarketChips({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    return Theme(
      data: theme.copyWith(chipTheme: theme.chipTheme.copyWith(
        selectedColor: primary.withValues(alpha: 0.12),
        secondarySelectedColor: primary.withValues(alpha: 0.12),
        checkmarkColor: primary,
        iconTheme: IconThemeData(color: primary, size: 16),
        // The chip resolves the colour by state (selected, disabled).
        labelStyle: textMedium.copyWith(
          fontSize: Dimensions.fontSizeDefault,
          color: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected)
              ? primary
              : (s.contains(WidgetState.disabled) ? theme.hintColor : (theme.textTheme.bodyLarge?.color ?? Colors.black87))),
        ),
        side: WidgetStateBorderSide.resolveWith((s) => s.contains(WidgetState.selected)
            ? BorderSide(color: primary, width: 1.5)
            : BorderSide(color: theme.hintColor.withValues(alpha: 0.45))),
      )),
      child: child,
    );
  }
}

/// "Mon 16 Nov, 10:00 to about 12:00"
String marketWhenRange(DateTime? start, DateTime? end) {
  if (start == null) return '';
  final w = marketWhen(start);
  return '${w.substring(0, w.length - 5)}${marketTimeRange(start, end)}';
}

/// "15:00 to about 19:00"
String marketTimeRange(DateTime? start, DateTime? end) {
  if (start == null) return '';
  final s = start.toLocal();
  final from = '${_two(s.hour)}:${_two(s.minute)}';
  if (end == null) return from;
  final e = end.toLocal();
  return 'market_time_range'.trParams({'from': from, 'to': '${_two(e.hour)}:${_two(e.minute)}'});
}

/// "Y-m-d H:i" for the API.
String marketApiTime(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

String marketApiDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

IconData marketServiceKindIcon(String? kind) => switch (kind) {
      'hair_beauty' => Icons.content_cut_rounded,
      'repairs' => Icons.build_outlined,
      'tailoring' => Icons.checkroom_outlined,
      'cleaning' => Icons.cleaning_services_outlined,
      'lessons' => Icons.school_outlined,
      'events' => Icons.celebration_outlined,
      'photography' => Icons.photo_camera_outlined,
      _ => Icons.handyman_outlined,
    };

IconData marketWhereIcon(String where) => switch (where) {
      'client' => Icons.home_outlined,
      'online' => Icons.videocam_outlined,
      _ => Icons.storefront_outlined,
    };

/// "Service" tag (green).
class MarketServiceTag extends StatelessWidget {
  final bool onPhoto;
  const MarketServiceTag({super.key, this.onPhoto = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: onPhoto ? Colors.white.withValues(alpha: 0.92) : marketServiceBg, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.event_available_outlined, size: 12, color: marketServiceFg),
          const SizedBox(width: 4),
          Text('market_service'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: marketServiceFg)),
        ]),
      );
}

/// Booking status, in words and colours, from the viewer's side.
(String, Color, Color) marketBookingStatus(MarketBooking b) {
  const blue = (Color(0xFF1D4ED8), Color(0xFFE8EEFC));
  const amber = (Color(0xFFB45309), Color(0xFFFFF4E5));
  const green = (Color(0xFF15803D), Color(0xFFE9F7EF));
  const grey = (Color(0xFF6B7675), Color(0xFFF1F3F3));
  const red = (Color(0xFFB91C1C), Color(0xFFFDECEC));
  final (fg, bg) = switch (b.status) {
    MarketBooking.confirmed => green,
    MarketBooking.completed => green,
    MarketBooking.requested || MarketBooking.quoteRequested => b.isProvider ? red : amber,
    MarketBooking.suggested || MarketBooking.quoted => b.isProvider ? amber : blue,
    MarketBooking.noShow => red,
    _ => grey,
  };
  final key = switch (b.status) {
    MarketBooking.requested => b.isProvider ? 'market_bs_requested_p' : 'market_bs_requested_c',
    MarketBooking.quoteRequested => b.isProvider ? 'market_bs_quote_requested_p' : 'market_bs_quote_requested_c',
    MarketBooking.suggested => b.isProvider ? 'market_bs_suggested_p' : 'market_bs_suggested_c',
    MarketBooking.quoted => b.isProvider ? 'market_bs_quoted_p' : 'market_bs_quoted_c',
    _ => 'market_bs_${b.status}',
  };
  return (key.tr, fg, bg);
}

class MarketBookingStatusChip extends StatelessWidget {
  final MarketBooking booking;
  const MarketBookingStatusChip({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = marketBookingStatus(booking);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: fg)),
    );
  }
}
