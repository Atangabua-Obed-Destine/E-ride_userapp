import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/bidding_model.dart';
import 'package:ride_sharing_user_app/features/ride/widgets/bidding_list_screen.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';

/// A driver's offer while the request is out: who they are, what they drive,
/// how far away, and the fare they bid, with Decline / Accept. The accept
/// and ignore calls are the same ones the shipped card made.
class RiderDetailsWidget extends StatefulWidget {
  final bool fromNotification;
  final Bidding bidding;
  final String tripId;
  const RiderDetailsWidget({super.key,this.fromNotification = true, required this.bidding, required this.tripId});

  @override
  State<RiderDetailsWidget> createState() => _RiderDetailsWidgetState();
}

class _RiderDetailsWidgetState extends State<RiderDetailsWidget> {

  @override
  Widget build(BuildContext context) {
    final Bidding bid = widget.bidding;
    final Color accent = Theme.of(context).primaryColor;
    final Color hint = Theme.of(context).hintColor;
    final Color text = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final String? driverBase = Get.find<ConfigController>().config?.imageBaseUrl?.profileImageDriver;
    final String rating = bid.driverAvgRating != null
        ? double.parse(bid.driverAvgRating.toString()).toStringAsFixed(1) : '0';

    return GetBuilder<RideController>(builder: (rideController) {
      final String? distance = rideController.remainingDistanceModel.isNotEmpty
          ? rideController.remainingDistanceModel[0].distanceText : null;

      return Padding(
        padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
        child: Material(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: ()=> Get.off(()=> BiddingListScreen(tripId: widget.tripId, fromList: true)),
            child: Container(
              padding: const EdgeInsets.all(Dimensions.paddingSize),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: hint.withValues(alpha: 0.18)),
              ),
              child: Column(children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: 2)),
                    child: ClipOval(
                      child: ImageWidget(
                        height: 48, width: 48, fit: BoxFit.cover,
                        placeholder: Images.personPlaceholder,
                        image: '$driverBase/${bid.driver?.profileImage ?? ''}',
                      ),
                    ),
                  ),
                  const SizedBox(width: Dimensions.paddingSize),

                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      '${bid.driver?.firstName ?? ''} ${bid.driver?.lastName ?? ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: text),
                    ),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFC53D)),
                      const SizedBox(width: 3),
                      Text(rating, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: text)),
                      if ((bid.driver?.vehicle?.model?.name ?? '').isNotEmpty) ...[
                        Text('  ·  ', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: hint)),
                        Flexible(child: Text(
                          bid.driver!.vehicle!.model!.name!,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: hint),
                        )),
                      ],
                    ]),
                    if (distance != null) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: hint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          '$distance ${'away'.tr}',
                          style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: text),
                        ),
                      ),
                    ],
                  ])),
                  const SizedBox(width: Dimensions.paddingSizeSmall),

                  Text(
                    PriceConverter.convertPrice(bid.bidFare!),
                    style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: accent),
                  ),
                ]),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                Row(children: [
                  Expanded(child: ButtonWidget(
                    buttonText: 'decline'.tr,
                    transparent: true,
                    showBorder: true,
                    borderColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.6),
                    textColor: Theme.of(context).colorScheme.error,
                    radius: 14,
                    height: 44,
                    fontSize: Dimensions.fontSizeDefault,
                    onPressed: (){
                      rideController.ignoreBidding(widget.bidding.id!,widget.tripId);
                    },
                  )),
                  const SizedBox(width: Dimensions.paddingSizeSmall),

                  Expanded(child: ButtonWidget(
                    buttonText: 'accept'.tr,
                    radius: 14,
                    height: 44,
                    fontSize: Dimensions.fontSizeDefault,
                    onPressed: () async{
                      rideController.tripAcceptOrRejected(widget.bidding.tripRequestsId!, 'accepted', widget.bidding.driver!.id!);
                    },
                  )),
                ]),
              ]),
            ),
          ),
        ),
      );
    });
  }
}
