import 'package:ride_sharing_user_app/common_widgets/call_options_sheet.dart';
import 'package:ride_sharing_user_app/features/message/controllers/chat_inbox_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/unread_badge.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/localization/localization_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/features/message/controllers/message_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';

class ContactWidget extends StatelessWidget {
  final String driverId;
   const ContactWidget({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideController>(
      builder: (rideController) {
        return  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,children: [

          InkWell(
              onTap: () => Get.find<MessageController>().createChannel(driverId,  Get.find<RideController>().tripDetails?.id),
              child: Padding(
                  padding:Get.find<LocalizationController>().isLtr
                      ? const EdgeInsets.only(top:Dimensions.paddingSizeDefault,bottom:Dimensions.paddingSizeDefault, right: Dimensions.paddingSizeExtraLarge)
                      : const EdgeInsets.only(top:Dimensions.paddingSizeDefault,bottom:Dimensions.paddingSizeDefault, left: Dimensions.paddingSizeExtraLarge),
                child: GetBuilder<ChatInboxController>(builder: (inbox) => UnreadBadge(
                  count: inbox.unreadForTrip(Get.find<RideController>().tripDetails?.id),
                  offset: const Offset(-10, -9),
                  child: SizedBox(width: Dimensions.iconSizeLarge, child: Image.asset(Images.customerMessage, color: Theme.of(context).primaryColor)),
                )),
              ),
          ),

          Container(width: 1,height: 25,color: Theme.of(context).hintColor.withValues(alpha:0.25),padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeDefault)),

          InkWell(
              onTap: () {
                final driver = Get.find<RideController>().tripDetails?.driver;
                CallOptionsSheet.show(phone: driver?.phone, name: '${driver?.firstName ?? ''} ${driver?.lastName ?? ''}');
              },
            child: Padding(
                padding: Get.find<LocalizationController>().isLtr
                    ? const EdgeInsets.only(left:Dimensions.paddingSizeLarge, top: Dimensions.paddingSizeSmall,bottom: Dimensions.paddingSizeSmall)
                    : const EdgeInsets.only(right:Dimensions.paddingSizeLarge, top: Dimensions.paddingSizeSmall,bottom: Dimensions.paddingSizeSmall),
              child: SizedBox(width: Dimensions.iconSizeLarge, child: Image.asset(Images.customerCall, color: Theme.of(context).primaryColor)),
            ),
          ),

        ],);
      }
    );
  }
}
