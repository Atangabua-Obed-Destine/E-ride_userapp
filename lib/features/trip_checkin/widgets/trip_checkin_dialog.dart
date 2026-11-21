import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/features/trip_checkin/controllers/trip_checkin_controller.dart';
import 'package:ride_sharing_user_app/features/trip_checkin/domain/models/trip_checkin_model.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// "Is everything OK on your trip?" The driver is not told. Without an answer
/// in time, E-Ride and the trusted contacts are alerted.
class TripCheckinDialog extends StatefulWidget {
  final TripCheckin checkin;
  const TripCheckinDialog({super.key, required this.checkin});

  @override
  State<TripCheckinDialog> createState() => _TripCheckinDialogState();
}

class _TripCheckinDialogState extends State<TripCheckinDialog> {
  late int _left;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _left = widget.checkin.secondsLeft;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left = _left > 0 ? _left - 1 : 0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _reason => switch (widget.checkin.reason) {
    'stopped' => 'trip_checkin_reason_stopped'.tr,
    'off_route' => 'trip_checkin_reason_off_route'.tr,
    'too_long' => 'trip_checkin_reason_too_long'.tr,
    _ => '',
  };

  Future<void> _answer(TripCheckinController controller, String answer) async {
    final String? status = await controller.answer(widget.checkin, answer);
    if (status == null || !mounted) return;
    Navigator.of(context).pop();
    controller.confirm(status);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color danger = theme.colorScheme.error;
    final String time = '${_left ~/ 60}:${(_left % 60).toString().padLeft(2, '0')}';
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.paddingSizeLarge)),
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
          child: GetBuilder<TripCheckinController>(builder: (controller) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.health_and_safety_rounded, size: 40, color: theme.primaryColor),
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              Text('trip_checkin_title'.tr, textAlign: TextAlign.center,
                  style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge)),
              if (_reason.isNotEmpty) ...[
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Text(_reason, textAlign: TextAlign.center, style: textRegular.copyWith(height: 1.4)),
              ],
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Text('trip_checkin_driver_not_told'.tr, textAlign: TextAlign.center,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                decoration: BoxDecoration(color: danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall)),
                child: Text(
                  _left > 0 ? 'trip_checkin_countdown'.trParams({'time': time}) : 'trip_checkin_alerting'.tr,
                  textAlign: TextAlign.center,
                  style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: danger, height: 1.35),
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeLarge),
              if (controller.answering)
                const Padding(padding: EdgeInsets.all(Dimensions.paddingSizeSmall), child: CircularProgressIndicator())
              else ...[
                ButtonWidget(buttonText: 'trip_checkin_ok'.tr, onPressed: () => _answer(controller, TripCheckinController.ok)),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: danger,
                      side: BorderSide(color: danger),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall)),
                    ),
                    icon: const Icon(Icons.sos_rounded),
                    label: Text('trip_checkin_help'.tr, style: textSemiBold.copyWith(color: danger)),
                    onPressed: () => _answer(controller, TripCheckinController.help),
                  ),
                ),
              ],
            ]);
          }),
        ),
      ),
    );
  }
}
