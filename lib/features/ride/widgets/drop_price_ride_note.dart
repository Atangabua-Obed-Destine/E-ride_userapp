import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/trip_details_model.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// During a drop-price ride: the fixed price holds when the ride ends at the
/// destination; ending somewhere else (another stop on the way) uses the normal fare.
class DropPriceRideNote extends StatelessWidget {
  final TripDetails trip;
  const DropPriceRideNote({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.sell_outlined, size: 20, color: theme.primaryColor),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Expanded(child: Text(
          'drop_price_ride_note'.trParams({'price': PriceConverter.convertPrice(trip.dropFarePrice ?? 0)}),
          style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, height: 1.35),
        )),
      ]),
    );
  }
}
