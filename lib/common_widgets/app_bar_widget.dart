import 'package:ride_sharing_user_app/features/message/controllers/chat_inbox_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/unread_badge.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing_user_app/common_widgets/calender_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/drop_down_widget.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/location/view/access_location_screen.dart';
import 'package:ride_sharing_user_app/features/location/view/pick_map_screen.dart';
import 'package:ride_sharing_user_app/features/trip/controllers/trip_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final bool showActionButton;
  final Function()? onBackPressed;
  final bool centerTitle;
  final double? fontSize;
  final bool isHome;
  final String? subTitle;
  final bool showTripHistoryFilter;
  final bool showDiscountHint;
  final bool showBonusHint;
  /// Replaces the logo in the leading slot with a menu button that opens the
  /// nearest Scaffold's drawer. Only the home screen sets this.
  final bool showMenuButton;
  /// Height of the toolbar row, below the status bar. HomeScreen reads this
  /// to place the hero search pill on the header/body seam.
  static const double toolbarHeight = 70;

  /// Where screens float their pill tab selector over this app bar: just
  /// under the title, whatever the status bar height. (A share of the screen
  /// height put the pills on the title on phones with a tall status bar.)
  static double overlayTop(BuildContext context) => MediaQuery.paddingOf(context).top + 62;
  const AppBarWidget({
    super.key,
    required this.title,
    this.subTitle,
    this.showBackButton = true,
    this.onBackPressed,
    this.centerTitle= false,
    this.showActionButton= true,
    this.isHome = false,
    this.showTripHistoryFilter = false,
    this.fontSize,
    this.showDiscountHint = false,
    this.showBonusHint = false,
    this.showMenuButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(150.0),
      child: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        toolbarHeight: toolbarHeight,
        automaticallyImplyLeading: false,
        title: InkWell(
          onTap: isHome ? () {
            Address? currentAddress = Get.find<LocationController>().getUserAddress();
            if(currentAddress == null || currentAddress.longitude == null){
              Get.to(() => const AccessLocationScreen());
            }else{
              Get.find<LocationController>().updatePosition(
                  LatLng(currentAddress.latitude!, currentAddress.longitude!), false,LocationType.location,
              );
              Get.to(() => PickMapScreen(type: LocationType.accessLocation,address: currentAddress));
            }
            
          } : null,
          child: Padding(
            padding: EdgeInsets.only(left: isHome ? Dimensions.paddingSizeExtraSmall : 0),
            child: Column(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center, children: [
                if(subTitle != null)
                Text(
                  subTitle ?? '',
                  style: textRegular.copyWith(
                    fontSize: fontSize ?? (isHome ?  Dimensions.fontSizeLarge : Dimensions.fontSizeLarge),
                    color:Get.isDarkMode ? Colors.white.withValues(alpha: 0.8) : Colors.white,
                  ), maxLines: 1,textAlign: TextAlign.start, overflow: TextOverflow.ellipsis,
                ),

                Row(mainAxisAlignment: _getAlignment(), children: [
                  const SizedBox(),

                  Flexible(
                    child: Text(
                      title.tr,
                      style: textRegular.copyWith(
                        fontSize: fontSize ??   Dimensions.fontSizeLarge , color: Get.isDarkMode ? Colors.white.withValues(alpha: 0.9) : Colors.white,
                      ), maxLines: 1,textAlign: TextAlign.start, overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  if(showTripHistoryFilter)
                    _TripHistoryFilter(),

                  if(showBonusHint)
                    _BonusHintWidget(),

                  if(showDiscountHint)
                    _DiscountHint()
                ]),

                isHome ?
                GetBuilder<LocationController>(builder: (locationController) {
                  return Padding(
                    padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
                    child: Row(mainAxisAlignment: isHome ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
                      Icon(Icons.place_outlined,color: Get.isDarkMode ? Colors.white.withValues(alpha:0.8) : Colors.white, size: 16),
                      const SizedBox(width: Dimensions.paddingSizeSeven),

                      Flexible(child: Text(
                        locationController.getUserAddress()?.address ?? '',
                        maxLines: 1,overflow: TextOverflow.ellipsis,
                        style: textRegular.copyWith(color:Get.isDarkMode ? Colors.white.withValues(alpha:0.8) : Colors.white,
                            fontSize: Dimensions.fontSizeExtraSmall),
                      )),
                    ]),
                  );
                }) :
                const SizedBox.shrink(),
              ],
            ),
          ),
        ),
        centerTitle: centerTitle,
        excludeHeaderSemantics: true,
        titleSpacing: 0,
        leading: showBackButton ?
        IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Get.isDarkMode ? Colors.white.withValues(alpha:0.8) : Colors.white,
          onPressed: () => onBackPressed != null ? onBackPressed!() : Navigator.canPop(context) ? Get.back() : Get.offAll(()=> const DashboardScreen()),
        ) :
        showMenuButton ?
        // Builder so the context is below the Scaffold that owns the drawer.
        Builder(builder: (context) => IconButton(
          tooltip: 'profile'.tr,
          icon: GetBuilder<ChatInboxController>(builder: (inbox) => UnreadBadge(
            count: inbox.totalUnread,
            dot: true,
            offset: const Offset(-1, -1),
            borderColor: Theme.of(context).scaffoldBackgroundColor,
            child: const Icon(Icons.menu_rounded),
          )),
          color: Get.isDarkMode ? Colors.white.withValues(alpha:0.8) : Colors.white,
          onPressed: () => (DashboardScreen.scaffoldState ?? Scaffold.of(context)).openDrawer(),
        )) :
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
          // Was the DriveMond green car hexagon (assets/image/icon.png). This is
          // the E-Ride mark in the dark-background variant, because the app bar
          // sits on scaffoldBackgroundColor (#222222) where the shipped logo's
          // dark artwork would disappear.
          child: Image.asset(
            Images.brandMarkOnDark,
            height: 30,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
          ),
        ),

        actions: [
          if(!showTripHistoryFilter && !showBonusHint  && !showDiscountHint)
          SizedBox(width: Get.width * 0.15)
        ],
      ),
    );
  }

  MainAxisAlignment _getAlignment() {
    if (isHome) {
      return MainAxisAlignment.start;
    } else if(showTripHistoryFilter || showBonusHint || showDiscountHint){
      return MainAxisAlignment.spaceBetween;
    }else {
      return MainAxisAlignment.center;
    }
  }

  @override
  Size get preferredSize => const Size(Dimensions.webMaxWidth, 150);
}

class _TripHistoryFilter extends StatelessWidget {
  const _TripHistoryFilter();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<TripController>(builder: (tripController){
      return SizedBox(width: 45,
        child: Padding(
          padding: const EdgeInsets.only(right: Dimensions.paddingSizeDefault),
          child: DropDownWidget<int>(
            showText: false,
            showLeftSide: false,
            menuItemWidth: 120,
            icon: Container(height: 30,width: 30,
              decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  shape: BoxShape.circle
              ),
              child: Icon(Icons.filter_list_sharp, color: Theme.of(context).primaryColor,size: 16),
            ),
            maxListHeight: 200,
            items: tripController.filterList.map((item) => CustomDropdownMenuItem<int>(
              value: tripController.filterList.indexOf(item),
              child: Text(item.tr,
                style: textRegular.copyWith(
                  color: Get.isDarkMode ?
                  Get.find<TripController>().filterIndex == Get.find<TripController>().filterList.indexOf(item) ?
                  Theme.of(context).primaryColor :
                  Colors.white :
                  Get.find<TripController>().filterIndex == Get.find<TripController>().filterList.indexOf(item) ?
                  Theme.of(context).primaryColor :
                  Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
            )).toList(),
            hintText: tripController.filterList[Get.find<TripController>().filterIndex].tr,
            borderRadius: 5,
            onChanged: (int selectedItem) {
              if(selectedItem == tripController.filterList.length-1) {
                showDialog(context: context,
                  builder: (_) => CalenderWidget(onChanged: (value) => Get.back()),
                );
              }else {
                tripController.setFilterTypeName(selectedItem);
              }
            },
          ),
        ),
      );
    });
  }
}

class _BonusHintWidget extends StatelessWidget {
  const _BonusHintWidget();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: Get.width * 0.05, left: Get.width * 0.05),
      child: InkWell(
        onTap: ()=> Get.bottomSheet(
          SizedBox(width: Get.width,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 30),

              Text('we_do_the_best_for_you'.tr,style: textSemiBold),

              Divider(color: Theme.of(context).hintColor.withValues(alpha:0.15)),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
                child: Text(
                  'if_you_have_multiple_eligible_bonus_we_will_automatically_apply_the_maximum'.tr,
                  style: textRegular.copyWith(color: Theme.of(context).hintColor), textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 50)
            ]),
          ) ,
          backgroundColor: Theme.of(context).cardColor,
        ),
        child: Icon(Icons.info, color: Theme.of(context).cardColor),
      ),
    );
  }
}

class _DiscountHint extends StatelessWidget {
  const _DiscountHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: Get.width * 0.05, left: Get.width * 0.05),
      child: InkWell(
        onTap: ()=> Get.bottomSheet(
          SizedBox(width: Get.width,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 30),

              Text('we_do_the_best_for_you'.tr,style: textSemiBold),

              Divider(color: Theme.of(context).hintColor.withValues(alpha:0.15)),

              Text(
                'if_you_have_multiple_eligible_discounts_we_will_automatically_apply_the_discount_that_will_save_you_the_most_to_your_next_trip'.tr,
                style: textRegular.copyWith(color: Theme.of(context).hintColor), textAlign: TextAlign.center,
              ),

              const SizedBox(height: 50)
            ]),
          ) ,
          backgroundColor: Theme.of(context).cardColor,
        ),
        child: Icon(Icons.info, color: Theme.of(context).cardColor),
      ),
    );
  }
}

