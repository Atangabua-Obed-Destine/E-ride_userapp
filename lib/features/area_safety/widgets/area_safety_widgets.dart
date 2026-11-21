import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/features/area_safety/controllers/area_safety_controller.dart';
import 'package:ride_sharing_user_app/features/area_safety/domain/models/area_safety_model.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

String _when(DateTime? d) {
  if (d == null) return '';
  final DateTime now = DateTime.now();
  final String hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  if (d.year == now.year && d.month == now.month && d.day == now.day) return hm;
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[d.weekday - 1]} ${d.day}, $hm';
}

String dangerTypeLabel(String type) => 'danger_type_$type'.tr;

/// Home: paused or no-go areas near the rider, pauses planned soon, and confirmed danger reports.
class AreaSafetyBanner extends StatelessWidget {
  const AreaSafetyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AreaSafetyController>(builder: (c) {
      final SafetyNearby n = c.nearby;
      if (!c.enabled || n.isEmpty) return const SizedBox();
      final ThemeData theme = Theme.of(context);
      final List<Widget> rows = [
        for (final a in n.areas)
          _Row(
            icon: Icons.block_rounded,
            color: theme.colorScheme.error,
            title: a.inside ? (n.blocksTrips ? 'area_you_are_inside' : 'area_you_are_inside_alert').tr : (a.kind == 'pause' ? 'area_paused_near'.tr : 'area_no_go_near'.tr),
            // Pauses that only warn: trips still run, so say "stay alert", not "no trips".
            body: (n.blocksTrips ? 'area_until' : 'area_until_alert').trParams({'place': a.title, 'reason': a.reason, 'time': _when(a.endsAt)}),
          ),
        for (final a in n.upcoming)
          _Row(
            icon: Icons.event_busy_rounded,
            color: const Color(0xFFE59A12),
            title: 'area_pause_planned'.tr,
            body: 'area_planned_body'.trParams({'place': a.title, 'reason': a.reason, 'from': _when(a.startsAt), 'to': _when(a.endsAt)}),
          ),
        for (final r in n.reports)
          _Row(
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFE59A12),
            title: 'danger_reported_near'.trParams({'what': dangerTypeLabel(r.type)}),
            body: 'danger_report_where'.trParams({'place': r.place ?? 'danger_close_to_you'.tr, 'minutes': '${r.minutesAgo}'}),
          ),
      ];
      return Padding(
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault),
        child: Column(children: rows),
      );
    });
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Row({required this.icon, required this.color, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
        padding: const EdgeInsets.all(Dimensions.paddingSize),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).textTheme.bodyLarge?.color)),
            const SizedBox(height: 2),
            Text(body, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).textTheme.bodyMedium?.color)),
          ])),
        ]),
      );
}

/// "Report danger", under Share trip during a ride.
class ReportDangerLink extends StatelessWidget {
  final String? tripId;
  const ReportDangerLink({super.key, this.tripId});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AreaSafetyController>(builder: (c) {
      if (!c.enabled) return const SizedBox();
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          // The ride on screen, so E-Ride sees which trip the report came from.
          onPressed: () => ReportDangerSheet.show(tripId: tripId ?? Get.find<RideController>().tripDetails?.id),
          icon: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error, size: 20),
          label: Text('report_danger'.tr, style: textMedium.copyWith(color: Theme.of(context).colorScheme.error)),
        ),
      );
    });
  }
}

/// What is happening; the position is added by the app.
class ReportDangerSheet extends StatefulWidget {
  final String? tripId;
  const ReportDangerSheet({super.key, this.tripId});

  static Future<void> show({String? tripId}) =>
      Get.bottomSheet(ReportDangerSheet(tripId: tripId), isScrollControlled: true, backgroundColor: Colors.transparent);

  @override
  State<ReportDangerSheet> createState() => _ReportDangerSheetState();
}

class _ReportDangerSheetState extends State<ReportDangerSheet> {
  String? type;
  final TextEditingController note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GetBuilder<AreaSafetyController>(builder: (c) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      padding: EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault,
          Dimensions.paddingSizeDefault + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        Row(children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Text('report_danger'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
        ]),
        const SizedBox(height: 4),
        Text('report_danger_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        for (final t in c.types)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(type == t ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: type == t ? theme.colorScheme.error : theme.hintColor),
            title: Text(dangerTypeLabel(t)),
            onTap: () => setState(() => type = t),
          ),
        TextField(controller: note, maxLines: 2, maxLength: 500,
            decoration: InputDecoration(hintText: 'report_danger_note'.tr, border: const OutlineInputBorder())),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        ButtonWidget(
          buttonText: c.reporting ? 'report_danger_sending'.tr : 'report_danger_send'.tr,
          backgroundColor: theme.colorScheme.error,
          onPressed: type == null || c.reporting ? null : () async {
            final bool ok = await c.report(type!, note.text, tripId: widget.tripId);
            if (ok && context.mounted) Navigator.of(context).pop();
          },
        ),
      ])),
    ));
  }
}
