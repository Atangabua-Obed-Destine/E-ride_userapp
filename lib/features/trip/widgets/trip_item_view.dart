import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/auth/domain/enums/refund_status_enum.dart';
import 'package:ride_sharing_user_app/features/map/screens/map_screen.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/payment/screens/payment_screen.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/trip_details_model.dart';
import 'package:ride_sharing_user_app/features/trip/screens/trip_details_screen.dart';
import 'package:ride_sharing_user_app/helper/date_converter.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';

/// One trip in the Activity list: vehicle or parcel tile, destination, date
/// and reference, with the fare and a status pill on the right. The tap
/// routing below is unchanged from the shipped widget.
class TripItemView extends StatefulWidget {
  final TripDetails tripDetails;
  const TripItemView({super.key, required this.tripDetails});

  @override
  State<TripItemView> createState() => _TripItemViewState();
}

class _TripItemViewState extends State<TripItemView> {

  TripDetails get trip => widget.tripDetails;

  bool get _isParcel => trip.type == AppConstants.parcel;

  Color _statusColor(BuildContext context) {
    switch (trip.currentStatus) {
      case AppConstants.cancelled:
        return Theme.of(context).colorScheme.error;
      case AppConstants.completed:
      case 'returned':
        return const Color(0xFF1DB954);
      case 'returning':
        return Theme.of(context).hintColor;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  double? get _amount {
    if (trip.estimatedFare == null) return null;
    final bool settled = trip.currentStatus == AppConstants.cancelled || trip.currentStatus == AppConstants.completed ||
        (trip.parcelInformation?.payer == AppConstants.sender && trip.currentStatus == AppConstants.ongoing) ||
        trip.currentStatus == 'returning' || trip.currentStatus == 'returned';
    if (settled) return trip.paidFare ?? 0;
    return (trip.discountActualFare ?? 0) > 0 ? trip.discountActualFare! : (trip.actualFare ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final Color hint = Theme.of(context).hintColor;
    final Color text = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final Color status = _statusColor(context);
    final String? imageBase = Get.find<ConfigController>().config?.imageBaseUrl?.vehicleCategory;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _open,
        child: Container(
          padding: const EdgeInsets.all(Dimensions.paddingSize),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: hint.withValues(alpha: 0.14)),
          ),
          child: Row(children: [
            Container(
              width: 54, height: 54,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hint.withValues(alpha: Get.isDarkMode ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: _isParcel
                  ? Image.asset(Images.parcel, fit: BoxFit.contain)
                  : CachedNetworkImage(
                      imageUrl: '$imageBase/${trip.vehicleCategory?.image ?? ''}',
                      fit: BoxFit.contain,
                      placeholder: (_, __) => Icon(Icons.directions_car_rounded, color: text.withValues(alpha: 0.55)),
                      errorWidget: (_, __, ___) => Icon(Icons.directions_car_rounded, color: text.withValues(alpha: 0.55)),
                    ),
            ),
            const SizedBox(width: Dimensions.paddingSize),

            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _isParcel ? (trip.parcelInformation?.parcelCategoryName ?? 'parcel'.tr) : (trip.destinationAddress ?? ''),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: text),
              ),
              const SizedBox(height: 3),
              Text(
                '${DateConverter.isoStringToTripHistoryFormat(trip.createdAt!)}  ·  '
                '${_isParcel ? 'parcel'.tr : (trip.vehicleCategory?.name ?? '')}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: hint),
              ),
              const SizedBox(height: 3),
              Row(children: [
                Flexible(child: Text(
                  '#${trip.refId ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: hint),
                )),
                if (trip.parcelRefund?.status == RefundStatus.pending || trip.parcelRefund?.status == RefundStatus.approved) ...[
                  const SizedBox(width: 6),
                  Image.asset(Images.tripDetailsRefundIcon, height: 14, width: 14),
                ],
                if (trip.customerSafetyAlert != null) ...[
                  const SizedBox(width: 6),
                  Image.asset(Images.safelyShieldIcon1, height: 14, width: 14),
                ],
              ]),
            ])),
            const SizedBox(width: Dimensions.paddingSizeSmall),

            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (trip.isHealthRide)
                Text('health_ride'.tr, maxLines: 1, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).colorScheme.error)),
              if (trip.isMove)
                Text('move_label'.tr, maxLines: 1, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: text))
              else if (_amount != null)
                Text(
                  PriceConverter.convertPrice(_amount!),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: text),
                ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: status.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  (trip.currentStatus ?? '').tr,
                  style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: status),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _open() {
    if(trip.currentStatus == AppConstants.accepted || trip.currentStatus == AppConstants.outForPickup ||
        trip.currentStatus == AppConstants.ongoing|| trip.currentStatus == AppConstants.pending){
      if(trip.type == AppConstants.parcel){
        _screenNavigationForParcel(trip);

      }else{
        if(trip.type == 'scheduled_request'){
          _screenNavigationForScheduleRide(trip);

        }else{
          _screenNavigationForRide(trip);

        }
      }

    }else{
      if(trip.currentStatus == AppConstants.completed && trip.paymentStatus == AppConstants.unPaid){
        Get.find<RideController>().getFinalFare(trip.id!).then((value){
          Get.to(()=> PaymentScreen(fromParcel: trip.type == AppConstants.parcel ? true : false));
        });

      }else{
        Get.to(()=> TripDetailsScreen(tripId: trip.id!));
      }
    }
  }

}

void _screenNavigationForParcel(TripDetails tripDetails){
  Get.find<RideController>().getRideDetails(tripDetails.id!).then((value) {
    if(tripDetails.currentStatus == AppConstants.accepted){
      Get.find<ParcelController>().updateParcelState(ParcelDeliveryState.otpSent);
      MapScreen.open(const MapScreen(fromScreen: MapScreenType.parcel));

    }else if (tripDetails.currentStatus == AppConstants.ongoing){
      Get.find<ParcelController>().updateParcelState(ParcelDeliveryState.parcelOngoing);
      if(value.body['data']['parcel_information']['payer'] == AppConstants.sender &&
          value.body['data']['payment_status'] == AppConstants.unPaid){
        Get.off(()=>const PaymentScreen(fromParcel: true));

      }else{
        MapScreen.open(const MapScreen(fromScreen: MapScreenType.parcel));

      }
    }else{
      Get.find<ParcelController>().updateParcelState(ParcelDeliveryState.findingRider);
      MapScreen.open(const MapScreen(fromScreen: MapScreenType.parcel));

    }
  });
}

void _screenNavigationForRide(TripDetails tripDetails){
  Get.find<RideController>().getRideDetails(tripDetails.id!).then((value){
    if(tripDetails.currentStatus == AppConstants.outForPickup){
      Get.find<RideController>().updateRideCurrentState(RideState.outForPickup);
    }else if (tripDetails.currentStatus == AppConstants.ongoing){
      Get.find<RideController>().updateRideCurrentState(RideState.ongoingRide);
    }else{
      Get.find<RideController>().updateRideCurrentState(RideState.findingRider);
    }
    MapScreen.open(const MapScreen(fromScreen: MapScreenType.ride));
  });
}

void _screenNavigationForScheduleRide(TripDetails tripDetails){
  Get.find<RideController>().getRideDetails(tripDetails.id!).then((value){
    if(tripDetails.currentStatus == AppConstants.outForPickup){
      Get.find<RideController>().updateRideCurrentState(RideState.outForPickup);
      MapScreen.open(const MapScreen(fromScreen: MapScreenType.ride));
    }else if (tripDetails.currentStatus == AppConstants.ongoing){
      Get.find<RideController>().updateRideCurrentState(RideState.ongoingRide);
      MapScreen.open(const MapScreen(fromScreen: MapScreenType.ride));
    }else{
      Get.to(()=> TripDetailsScreen(tripId: tripDetails.id ?? ''));
    }

  });
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
