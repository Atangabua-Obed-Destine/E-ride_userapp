import 'package:ride_sharing_user_app/helper/image_size_helper.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';
import 'package:ride_sharing_user_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ride_sharing_user_app/features/payment/screens/review_screen.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/move/controllers/move_controller.dart';
import 'package:ride_sharing_user_app/features/move/screens/move_directory_screen.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/trip_details_model.dart';
import 'package:ride_sharing_user_app/features/safety_setup/controllers/safety_alert_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// "What are you moving?" and up to 3 photos of the load, on the booking
/// sheet. The text is the trip note; the driver sees both while it rings.
class MoveLoadWidget extends StatelessWidget {
  const MoveLoadWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RideController ride = Get.find<RideController>();
    return GetBuilder<MoveController>(builder: (move) {
      return Container(
        margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
        padding: const EdgeInsets.all(Dimensions.paddingSize),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.hintColor.withValues(alpha: 0.18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('move_what_are_you_moving'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault)),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          TextField(
            controller: ride.noteController,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault),
            decoration: InputDecoration(
              hintText: 'move_load_hint'.tr,
              hintStyle: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor),
              counterText: '',
              filled: true,
              fillColor: theme.hintColor.withValues(alpha: 0.06),
              contentPadding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text('move_photos_label'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Row(children: [
            for (int i = 0; i < move.photos.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
                child: _PhotoThumb(file: move.photos[i], onRemove: () => move.removePhoto(i)),
              ),
            if (move.photos.length < MoveController.maxPhotos)
              _AddPhotoButton(onTap: () => _choosePhotoSource(move)),
          ]),
        ]),
      );
    });
  }

  void _choosePhotoSource(MoveController move) {
    Get.bottomSheet(
      Builder(builder: (context) {
        final ThemeData theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(Dimensions.radiusExtraLarge)),
          ),
          child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: Icon(Icons.photo_camera_rounded, color: theme.primaryColor),
              title: Text('take_a_photo'.tr),
              onTap: () { Navigator.of(context).pop(); move.pickPhoto(ImageSource.camera); },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: theme.primaryColor),
              title: Text('choose_from_gallery'.tr),
              onTap: () { Navigator.of(context).pop(); move.pickPhoto(ImageSource.gallery); },
            ),
          ])),
        );
      }),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;
  const _PhotoThumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(File(file.path), width: 64, height: 64, fit: BoxFit.cover),
      ),
      Positioned(
        top: -6, right: -6,
        child: Semantics(
          button: true,
          label: 'remove'.tr,
          child: InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _AddPhotoButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'move_add_photo'.tr,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.primaryColor.withValues(alpha: 0.4)),
          ),
          child: Icon(Icons.add_a_photo_outlined, color: theme.primaryColor),
        ),
      ),
    );
  }
}

/// In place of the fare on the booking sheet: the deposit is the only amount
/// E-Ride charges, and the price is agreed with the driver.
class MoveDepositSummary extends StatelessWidget {
  final double deposit;
  const MoveDepositSummary({super.key, required this.deposit});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool asks = deposit > 0 && (Get.find<ConfigController>().config?.moveDepositStatus ?? false);
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSize),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (asks)
          Row(children: [
            Expanded(child: Text('move_deposit_label'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault))),
            Text(PriceConverter.convertPrice(deposit), style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.primaryColor)),
          ]),
        if (asks) const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.handshake_outlined, size: 18, color: theme.hintColor),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(child: Text(
            asks ? 'move_deposit_explainer'.tr : 'move_price_explainer'.tr,
            style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.35),
          )),
        ]),
      ]),
    );
  }
}

/// A one-line "Price: agree with your driver" for the trip screens.
class MovePriceRow extends StatelessWidget {
  const MovePriceRow({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        color: theme.hintColor.withValues(alpha: 0.1),
      ),
      child: Row(children: [
        Icon(Icons.handshake_outlined, size: 18, color: theme.textTheme.bodyMedium?.color),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Expanded(child: Text('move_price_agree_with_driver'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault))),
      ]),
    );
  }
}

/// The load the customer described, with its photos.
class MoveLoadSummary extends StatelessWidget {
  final TripDetails trip;
  const MoveLoadSummary({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String note = (trip.note ?? '').trim();
    if (note.isEmpty && trip.movePhotos.isEmpty) return const SizedBox();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        color: theme.hintColor.withValues(alpha: 0.1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('move_your_load'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault)),
        if (note.isNotEmpty) ...[
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text(note, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, height: 1.35)),
        ],
        if (trip.movePhotos.isNotEmpty) ...[
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Row(children: [
            for (final String url in trip.movePhotos)
              Padding(
                padding: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
                child: InkWell(
                  onTap: () => _openPhoto(context, url),
                  borderRadius: BorderRadius.circular(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(url, width: 56, height: 56, fit: BoxFit.cover, cacheWidth: ImageSizeHelper.decodeWidth(context, 56, 56),
                        errorBuilder: (_, __, ___) => Container(width: 56, height: 56, color: theme.hintColor.withValues(alpha: 0.2))),
                  ),
                ),
              ),
          ]),
        ],
      ]),
    );
  }

  void _openPhoto(BuildContext context, String url) {
    showDialog(context: context, builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
    ));
  }
}

/// "No truck around? Call a truck owner": opens the directory.
class MoveDirectoryLink extends StatelessWidget {
  final String? vehicleCategoryId;
  final bool prominent;
  const MoveDirectoryLink({super.key, this.vehicleCategoryId, this.prominent = false});

  @override
  Widget build(BuildContext context) {
    if (!(Get.find<ConfigController>().config?.moveDirectoryStatus ?? false)) return const SizedBox();
    final ThemeData theme = Theme.of(context);
    void open() => Get.to(() => MoveDirectoryScreen(vehicleCategoryId: vehicleCategoryId));
    if (prominent) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: open,
          icon: const Icon(Icons.call_rounded),
          label: Text('move_call_a_truck_owner'.tr),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.primaryColor,
            side: BorderSide(color: theme.primaryColor),
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
          ),
        ),
      );
    }
    return InkWell(
      onTap: open,
      borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeExtraSmall),
        child: Row(children: [
          Icon(Icons.call_rounded, size: 16, color: theme.primaryColor),
          const SizedBox(width: 6),
          Expanded(child: Text('move_no_truck_call_owner'.tr,
              style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor))),
          Icon(Icons.chevron_right_rounded, size: 18, color: theme.primaryColor),
        ]),
      ),
    );
  }
}

/// "We couldn't agree on the price": at the pickup, once the deposit is paid.
/// The server checks the driver is there and keeps the deposit.
class MoveNoAgreementButton extends StatelessWidget {
  final TripDetails trip;
  const MoveNoAgreementButton({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    if (!trip.isMove || !(trip.deposit?.isPaid ?? false)) return const SizedBox();
    final ThemeData theme = Theme.of(context);
    return GetBuilder<MoveController>(builder: (move) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
        child: SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: move.cancelling ? null : () => _confirm(context),
            icon: move.cancelling
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.do_not_disturb_alt_rounded, color: theme.colorScheme.error),
            label: Text('move_no_agreement_button'.tr, style: textMedium.copyWith(color: theme.colorScheme.error)),
          ),
        ),
      );
    });
  }

  Future<void> _confirm(BuildContext context) async {
    final ThemeData theme = Theme.of(context);
    final bool? yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('move_no_agreement_title'.tr),
      content: Text('move_no_agreement_confirm'.trParams({
        'amount': PriceConverter.convertPrice(trip.deposit?.amount ?? 0),
      })),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('move_keep_talking'.tr)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('move_cancel_the_move'.tr),
        ),
      ],
    ));
    if (yes != true) return;
    final bool done = await Get.find<MoveController>().noAgreement(trip.id!);
    if (!done) return;
    final RideController ride = Get.find<RideController>();
    ride.stopLocationRecord();
    Get.find<SafetyAlertController>().cancelDriverNeedSafetyStream();
    ride.tripDetails = null;
    ride.updateRideCurrentState(RideState.initial);
    Get.find<MapController>().notifyMapController();
    showCustomSnackBar('move_cancelled_no_agreement'.tr, isError: false);
    Get.find<BottomMenuController>().navigateToDashboard();
  }
}

/// The driver completed the move. Nothing is paid in the app (the server
/// marked it paid), so: clear the trip, go to the review, and remind the
/// customer to pay the driver the price they agreed.
void finishCompletedMove(String tripId) {
  final RideController ride = Get.find<RideController>();
  ride.stopLocationRecord();
  Get.find<SafetyAlertController>().cancelDriverNeedSafetyStream();
  ride.clearRideDetails();
  ride.updateRideCurrentState(RideState.initial);
  Get.find<MapController>().notifyMapController();
  if (Get.find<ConfigController>().config?.reviewStatus ?? false) {
    Get.offAll(() => ReviewScreen(tripId: tripId));
  } else {
    Get.offAll(() => const DashboardScreen());
  }
  _whenVisible(showMoveCompletedSheet);
}

/// Runs [show] now if the app is on screen, otherwise when it comes back
/// (a move often ends while the customer is in another app).
void _whenVisible(Future<void> Function() show) {
  if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
    Future.delayed(const Duration(milliseconds: 400), show);
    return;
  }
  late final AppLifecycleListener listener;
  listener = AppLifecycleListener(onResume: () {
    listener.dispose();
    Future.delayed(const Duration(milliseconds: 600), show);
  });
}

/// The driver completed the move: nothing to pay in the app.
Future<void> showMoveCompletedSheet() async {
  await Get.bottomSheet(
    Builder(builder: (context) {
      final ThemeData theme = Theme.of(context);
      return Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Dimensions.radiusExtraLarge)),
        ),
        child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.check_circle_rounded, size: 40, color: theme.primaryColor),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text('move_completed_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge)),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text('move_completed_body'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.hintColor, height: 1.4)),
          const SizedBox(height: Dimensions.paddingSizeLarge),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ok'.tr),
            ),
          ),
        ])),
      );
    }),
    isScrollControlled: true,
  );
}
