import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Private sellers (a person selling things they own) get their own colour everywhere.
const Color marketPrivateFg = Color(0xFF3730A3);
const Color marketPrivateBg = Color(0xFFEEF2FF);
const Color marketAuctionBg = Color(0xFF1D2D2B);

/// "Private seller" tag.
class MarketPrivateTag extends StatelessWidget {
  final bool small;
  const MarketPrivateTag({super.key, this.small = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
        decoration: BoxDecoration(color: marketPrivateBg, borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.person_outline_rounded, size: small ? 11 : 13, color: marketPrivateFg),
          const SizedBox(width: 3),
          Text('market_private_seller'.tr, style: textSemiBold.copyWith(fontSize: small ? 9.5 : Dimensions.fontSizeExtraSmall + 1, color: marketPrivateFg)),
        ]),
      );
}

/// "Auction" tag (dark, on photos).
class MarketAuctionTag extends StatelessWidget {
  const MarketAuctionTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: marketAuctionBg.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.gavel_rounded, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text('market_auction'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white)),
        ]),
      );
}

/// What a private seller is, for buyers.
class MarketPrivateExplainer extends StatelessWidget {
  /// A person offering a service themselves, not someone selling a thing they own.
  final bool service;
  const MarketPrivateExplainer({super.key, this.service = false});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: marketPrivateBg, borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.person_outline_rounded, size: 18, color: marketPrivateFg),
            const SizedBox(width: 6),
            Expanded(child: Text((service ? 'market_independent_explain_title' : 'market_private_explain_title').tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: marketPrivateFg))),
          ]),
          const SizedBox(height: 4),
          Text((service ? 'market_independent_explain_body' : 'market_private_explain_body').tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: marketPrivateFg, height: 1.45)),
        ]),
      );
}

/// "2 d 4 h", "2 h 14 min", "5 min", "Ended".
String marketTimeLeft(DateTime? until) {
  if (until == null) return '';
  final left = until.difference(DateTime.now());
  if (left.isNegative) return 'market_ended'.tr;
  if (left.inDays >= 1) return '${left.inDays} ${'market_d'.tr} ${left.inHours % 24} h';
  if (left.inHours >= 1) return '${left.inHours} h ${(left.inMinutes % 60).toString().padLeft(2, '0')} min';
  if (left.inMinutes >= 1) return '${left.inMinutes} min';
  return '${left.inSeconds} s';
}

/// "15/11 11:50" (today: "today 11:50").
String marketDayTime(DateTime t) {
  final l = t.toLocal();
  final now = DateTime.now();
  final hm = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  if (l.year == now.year && l.month == now.month && l.day == now.day) return '${'market_today'.tr} $hm';
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')} $hm';
}

/// A time left that updates by itself (every second near the end).
class MarketTimeLeft extends StatefulWidget {
  final DateTime? until;
  final TextStyle? style;
  const MarketTimeLeft({super.key, required this.until, this.style});

  @override
  State<MarketTimeLeft> createState() => _MarketTimeLeftState();
}

class _MarketTimeLeftState extends State<MarketTimeLeft> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final until = widget.until;
      // Every second in the last 2 hours; otherwise every 30 seconds is plenty.
      if (until == null || until.difference(DateTime.now()).inHours < 2 || DateTime.now().second % 30 == 0) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(marketTimeLeft(widget.until), style: widget.style);
}

/// "Used · Good"
String marketConditionLabel(String condition, String? grade) {
  if (condition != 'used') return 'market_condition_$condition'.tr;
  return grade == null ? 'market_condition_used'.tr : '${'market_condition_used'.tr} · ${'market_grade_$grade'.tr}';
}
