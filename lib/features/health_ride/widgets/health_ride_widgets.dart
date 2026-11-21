import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/health_ride/controllers/health_ride_controller.dart';
import 'package:ride_sharing_user_app/features/health_ride/domain/models/health_place_model.dart';
import 'package:ride_sharing_user_app/features/health_ride/screens/health_ride_screen.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/splash/domain/models/config_model.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// "This is not an ambulance", with the emergency numbers to tap. Shown on the
/// health ride screen, the trip setup, the fare screen and while searching.
class HealthRideNotice extends StatelessWidget {
  final bool compact;
  const HealthRideNotice({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color red = theme.colorScheme.error;
    final List<EmergencyNumber> numbers = Get.find<ConfigController>().config?.emergencyNumbers ?? const [];
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: compact ? 0 : Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: red.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: red.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.health_and_safety_rounded, color: red, size: 22),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('health_ride_not_ambulance'.tr, style: textBold.copyWith(color: red, fontSize: Dimensions.fontSizeSmall)),
            if (!compact) ...[
              const SizedBox(height: 2),
              Text('health_ride_notice'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.35)),
            ],
          ])),
        ]),
        if (numbers.isNotEmpty) ...[
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Wrap(spacing: Dimensions.paddingSizeExtraSmall, runSpacing: Dimensions.paddingSizeExtraSmall, children: [
            for (final EmergencyNumber n in numbers)
              ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(Icons.call_rounded, size: 16, color: red),
                label: Text('${n.label} ${n.number}', style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: red)),
                backgroundColor: theme.cardColor,
                side: BorderSide(color: red.withValues(alpha: 0.4)),
                onPressed: () => HealthRideController.call(n.number),
              ),
          ]),
        ],
      ]),
    );
  }
}

/// The home screen's way in: a clear red card under the services.
class HealthRideHomeCard extends StatelessWidget {
  const HealthRideHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(Get.find<ConfigController>().config?.healthRideStatus ?? false)) return const SizedBox();
    final ThemeData theme = Theme.of(context);
    final Color red = theme.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall, Dimensions.paddingSizeDefault, 0),
      child: Material(
        color: red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        child: InkWell(
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          onTap: () => Get.to(() => const HealthRideScreen()),
          child: Container(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              border: Border.all(color: red.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: red, borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
                child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: Dimensions.paddingSizeDefault),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('health_ride'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: red)),
                const SizedBox(height: 2),
                Text('health_ride_home_sub'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              ])),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: red),
            ]),
          ),
        ),
      ),
    );
  }
}

/// One place in the health ride list: name, where, how far, open or on duty.
class HealthPlaceTile extends StatelessWidget {
  final HealthPlace place;
  final bool busy;
  final VoidCallback onTap;
  const HealthPlaceTile({super.key, required this.place, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color red = theme.colorScheme.error;
    final String? distance = place.distanceKm == null ? null
        : place.distanceKm! < 1 ? '${(place.distanceKm! * 1000).round()} m' : '${place.distanceKm!.toStringAsFixed(1)} km';
    return Container(
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: theme.hintColor.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
              child: Icon(place.isPharmacy ? Icons.local_pharmacy_rounded : Icons.local_hospital_rounded, color: red),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textSemiBold)),
                if (place.verified) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.verified_rounded, size: 15, color: theme.primaryColor),
                ],
              ]),
              if (place.address.isNotEmpty)
                Text(place.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              const SizedBox(height: 2),
              Wrap(spacing: Dimensions.paddingSizeSmall, children: [
                if (distance != null) Text(distance, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
                if (place.onDuty)
                  Text('health_on_duty'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.green))
                else if (place.openNow == true)
                  Text('health_open_now'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.green))
                else if (place.openNow == false)
                  Text('health_closed_now'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              ]),
            ])),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.local_taxi_rounded, color: red),
          ]),
        ),
      ),
    );
  }
}
