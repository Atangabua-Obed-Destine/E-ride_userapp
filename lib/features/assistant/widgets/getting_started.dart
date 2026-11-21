import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ride_sharing_user_app/features/address/controllers/address_controller.dart';
import 'package:ride_sharing_user_app/features/address/screens/my_address.dart';
import 'package:ride_sharing_user_app/features/assistant/controllers/assistant_controller.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/models/assistant_models.dart';
import 'package:ride_sharing_user_app/features/assistant/widgets/help_button.dart';
import 'package:ride_sharing_user_app/features/id_verification/controllers/id_verification_controller.dart';
import 'package:ride_sharing_user_app/features/id_verification/screens/id_verification_screen.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/safety_setup/screens/safety_setup_screen.dart';
import 'package:ride_sharing_user_app/features/set_destination/screens/set_destination_screen.dart';
import 'package:ride_sharing_user_app/features/trip_share/controllers/trip_share_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Getting started: the first things a new customer does in E-Ride, ticked
/// off as they are done. Shown on Ask E-Ride for new customers, and from the
/// "Getting started" button any answer can carry.
class GettingStarted {
  static const String _pickupKey = 'guide_pickup_done';

  /// The customer told a driver where to find them (written or voice note).
  static void markPickupDone() => Get.find<SharedPreferences>().setBool(_pickupKey, true);

  static bool get _pickupDone => Get.find<SharedPreferences>().getBool(_pickupKey) ?? false;

  /// New: no ride yet.
  static bool get isNewCustomer => (Get.find<ProfileController>().profileModel?.data?.totalRideCount ?? 0) == 0;

  static Future<void> show() => Get.bottomSheet(
        const SafeArea(child: SingleChildScrollView(padding: EdgeInsets.fromLTRB(16, 12, 16, 16), child: GettingStartedCard(inSheet: true))),
        isScrollControlled: true,
        backgroundColor: Get.theme.cardColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      );
}

class GettingStartedCard extends StatefulWidget {
  final bool inSheet;
  const GettingStartedCard({super.key, this.inSheet = false});

  @override
  State<GettingStartedCard> createState() => _GettingStartedCardState();
}

class _Step {
  final IconData icon;
  final String title;
  final String body;
  final bool done;
  final VoidCallback onTap;
  const _Step(this.icon, this.title, this.body, this.done, this.onTap);
}

class _GettingStartedCardState extends State<GettingStartedCard> {
  @override
  void initState() {
    super.initState();
    // What the ticks depend on, if not loaded yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final AddressController address = Get.find<AddressController>();
      if (address.addressList == null) address.getAddressList(1);
      Get.find<TripShareController>().getContacts();
      final IdVerificationController id = Get.find<IdVerificationController>();
      if (id.status == null) id.load();
    });
  }

  void _go(VoidCallback open) {
    if (widget.inSheet) Get.back();
    open();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GetBuilder<AddressController>(builder: (address) => GetBuilder<TripShareController>(builder: (share) => GetBuilder<IdVerificationController>(builder: (id) {
      final HelpSheet? pickupSheet = Get.find<AssistantController>().sheet('pickup_help');
      final List<_Step> steps = [
        _Step(Icons.local_taxi_rounded, 'guide_ride'.tr, 'guide_ride_body'.tr, !GettingStarted.isNewCustomer,
            () => _go(() => Get.to(() => const SetDestinationScreen()))),
        _Step(Icons.record_voice_over_rounded, 'pickup_help_title'.tr, 'guide_pickup_body'.tr, GettingStarted._pickupDone,
            () => _go(() => pickupSheet != null ? showHelpSheet(pickupSheet) : Get.to(() => const SetDestinationScreen()))),
        _Step(Icons.home_rounded, 'guide_places'.tr, 'guide_places_body'.tr,
            (address.addressList ?? const []).any((a) => a.addressLabel == 'home'), () => _go(() => Get.to(() => const MyAddressScreen()))),
        _Step(Icons.shield_outlined, 'guide_safety'.tr, 'guide_safety_body'.tr, (share.contacts ?? const []).isNotEmpty,
            () => _go(() => Get.to(() => const SafetySetupScreen()))),
        _Step(Icons.verified_user_outlined, 'guide_id'.tr, 'guide_id_body'.tr, id.status?.verified ?? false,
            () => _go(() => Get.to(() => const IdVerificationScreen()))),
      ];
      final int done = steps.where((s) => s.done).length;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(6),
          border: widget.inSheet ? null : Border.all(color: theme.hintColor.withValues(alpha: 0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(Icons.flag_rounded, color: theme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('guide_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color))),
            Text('guide_progress'.trParams({'done': '$done', 'all': '${steps.length}'}),
                style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: done / steps.length, minHeight: 5, color: const Color(0xFF15803D),
                backgroundColor: theme.hintColor.withValues(alpha: 0.15)),
          ),
          const SizedBox(height: 6),
          for (final _Step s in steps) _row(theme, s),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.phone_android_rounded, size: 16, color: theme.hintColor),
            const SizedBox(width: 6),
            Expanded(child: Text('guide_pay_line'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
          ]),
        ]),
      );
    })));
  }

  Widget _row(ThemeData theme, _Step s) {
    const Color green = Color(0xFF15803D);
    return InkWell(
      onTap: s.onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: s.done ? green.withValues(alpha: 0.12) : theme.primaryColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(s.done ? Icons.check_rounded : s.icon, size: 19, color: s.done ? green : theme.primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.title, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault,
                color: s.done ? theme.hintColor : theme.textTheme.bodyLarge?.color,
                decoration: s.done ? TextDecoration.lineThrough : null)),
            if (!s.done)
              Text(s.body, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.35)),
          ])),
          if (!s.done) Icon(Icons.chevron_right_rounded, color: theme.hintColor),
        ]),
      ),
    );
  }
}
