import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/home/controllers/category_controller.dart';
import 'package:ride_sharing_user_app/features/map/screens/map_screen.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/dotted_border_card.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/parcel_category_screen.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/home/widgets/banner_view.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';

class ParcelScreen extends StatefulWidget {
  /// Details to fill in, e.g. an E-Ride Market delivery the seller books from a chat.
  final ParcelPrefill? prefill;
  const ParcelScreen({super.key, this.prefill});

  @override
  State<ParcelScreen> createState() => _ParcelScreenState();
}

class _ParcelScreenState extends State<ParcelScreen> {
  @override
  void initState() {
    super.initState();

    Get.find<ParcelController>().getParcelCategoryList(notify: true);
    Get.find<RideController>().initData();
    Get.find<LocationController>().initAddLocationData();
    Get.find<LocationController>().initParcelData();
    Get.find<ParcelController>().initParcelData();
    Get.find<MapController>().initializeData();
    Get.find<CategoryController>().setCouponFilterIndex(1, isUpdate: false);
    if (widget.prefill != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<ParcelController>().applyPrefill(widget.prefill!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        body: Stack(children: [
          BodyWidget(
            appBar: AppBarWidget(title: 'parcel_delivery'.tr),
            body: const Padding(padding: EdgeInsets.all(Dimensions.paddingSizeDefault), child: Column(children:  [

              _MarketDeliveryNote(),

              BannerView(),

              DottedBorderCard(),

              ParcelCategoryView(),

            ])),
          ),

          Positioned(
            bottom: Dimensions.paddingSizeDefault,
            left:  Dimensions.paddingSizeDefault,
            right:  Dimensions.paddingSizeDefault,
            child: ButtonWidget(
              buttonText: 'add_parcel'.tr,
              onPressed: () {
                if(Get.find<ConfigController>().config!.maintenanceMode != null &&
                    Get.find<ConfigController>().config!.maintenanceMode!.maintenanceStatus == 1 &&
                    Get.find<ConfigController>().config!.maintenanceMode!.selectedMaintenanceSystem!.userApp == 1
                ){
                  showCustomSnackBar('maintenance_mode_on_for_parcel'.tr,isError: true);
                }else{
                  if(Get.find<ParcelController>().parcelCategoryList == null || Get.find<ParcelController>().parcelCategoryList!.isEmpty) {
                    showCustomSnackBar('no_parcel_category_found'.tr);
                  }else {
                    Get.find<ParcelController>().updateTabControllerIndex(0);
                    Get.find<ParcelController>().updateParcelState(ParcelDeliveryState.initial);
                    MapScreen.open(const MapScreen(fromScreen: MapScreenType.parcel));
                  }
                }

              },
            ),
          ),

        ]),
      ),
    );
  }
}

/// "E-Ride Market delivery to Grace": who pays what, when the booking came from a market chat.
class _MarketDeliveryNote extends StatelessWidget {
  const _MarketDeliveryNote();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ParcelController>(builder: (parcel) {
      final String? buyer = parcel.marketBuyerName;
      if (buyer == null) return const SizedBox();
      final ThemeData theme = Theme.of(context);
      final String payer = parcel.lockedPayReceiver == null
          ? 'market_parcel_payer_choose'.tr
          : (parcel.lockedPayReceiver! ? 'market_parcel_payer_buyer'.tr : 'market_parcel_payer_seller'.tr);
      return Container(
        margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
        padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.storefront_rounded, color: theme.primaryColor, size: 20),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('market_parcel_for'.trParams({'name': buyer}),
                style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
            const SizedBox(height: 2),
            Text('${'market_parcel_deposit_you'.tr} $payer',
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
          ])),
        ]),
      );
    });
  }
}
