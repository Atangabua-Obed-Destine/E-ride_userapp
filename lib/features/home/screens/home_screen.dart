import 'package:ride_sharing_user_app/features/guide/widgets/guide_widgets.dart';
import 'package:ride_sharing_user_app/features/id_verification/controllers/id_verification_controller.dart';
import 'package:ride_sharing_user_app/features/bus/controllers/bus_controller.dart';
import 'package:ride_sharing_user_app/features/assistant/widgets/did_you_know_card.dart';
import 'package:ride_sharing_user_app/features/assistant/controllers/assistant_controller.dart';
import 'package:ride_sharing_user_app/features/assistant/screens/assistant_screen.dart';
import 'package:ride_sharing_user_app/features/assistant/widgets/home_tour.dart';
import 'package:ride_sharing_user_app/features/area_safety/controllers/area_safety_controller.dart';
import 'package:ride_sharing_user_app/features/area_safety/widgets/area_safety_widgets.dart';
import 'package:ride_sharing_user_app/features/home/widgets/home_discover_widgets.dart';
import 'package:ride_sharing_user_app/features/home/widgets/home_service_grid.dart';
import 'package:ride_sharing_user_app/features/health_ride/widgets/health_ride_widgets.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/explore/controllers/explore_controller.dart';
import 'package:ride_sharing_user_app/features/message/controllers/chat_inbox_controller.dart';
import 'package:flutter/material.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';
import 'package:get/get.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/home/widgets/banner_view.dart';
import 'package:ride_sharing_user_app/features/home/widgets/best_offers_widget.dart';
import 'package:ride_sharing_user_app/features/home/widgets/home_header_motif.dart';
import 'package:ride_sharing_user_app/features/home/widgets/home_hero_search.dart';
import 'package:ride_sharing_user_app/features/home/widgets/home_saved_places.dart';
import 'package:ride_sharing_user_app/features/home/widgets/home_services_row.dart';
import 'package:ride_sharing_user_app/features/home/widgets/coupon_home_widget.dart';
import 'package:ride_sharing_user_app/features/home/widgets/home_map_view.dart';
import 'package:ride_sharing_user_app/features/home/widgets/home_referral_view_widget.dart';
import 'package:ride_sharing_user_app/features/home/widgets/visit_to_mart_widget.dart';
import 'package:ride_sharing_user_app/features/my_offer/controller/offer_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/screens/parcel_list_view_screen.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/driver_request_dialog.dart';
import 'package:ride_sharing_user_app/features/ride/screens/ride_list_view_screen.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/splash/domain/models/config_model.dart';
import 'package:ride_sharing_user_app/helper/home_screen_helper.dart';
import 'package:ride_sharing_user_app/helper/pusher_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/address/controllers/address_controller.dart';
import 'package:ride_sharing_user_app/features/home/controllers/banner_controller.dart';
import 'package:ride_sharing_user_app/features/home/controllers/category_controller.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _lastTab = 0;
  void Function()? _stopWatchingTabs;
  DateTime? _lastLiveRefresh;

  void _onTabChanged() {
    final int tab = Get.find<BottomMenuController>().currentTab;
    if (tab == 0 && _lastTab != 0) _refreshLiveTrips();
    _lastTab = tab;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // The customer may have moved while the app was in the background.
    Get.find<LocationController>().syncAddressWithGps();
    if (Get.find<BottomMenuController>().currentTab == 0) _refreshLiveTrips();
  }

  /// Home stays mounted behind the other tabs and the app can sit in the
  /// background, and a trip can end meanwhile: keep its chip honest. Only the two
  /// running lists, and only while home is the screen on top.
  void _refreshLiveTrips() {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final DateTime now = DateTime.now();
    if (_lastLiveRefresh != null && now.difference(_lastLiveRefresh!) < const Duration(seconds: 5)) return;
    _lastLiveRefresh = now;
    Get.find<RideController>().getRunningRideList();
    Get.find<ParcelController>().getRunningParcelList();
  }

  JustTheController rideShareToolTip = JustTheController();
  JustTheController parcelDeliveryToolTip = JustTheController();
  final ScrollController _scrollController = ScrollController();
  bool _isShowRideIcon = true;


  String greetingMessage() {
    var timeNow = DateTime.now().hour;
    if (timeNow <= 12) {
      return 'good_morning'.tr;
    } else if ((timeNow > 12) && (timeNow <= 16)) {
      return 'good_afternoon'.tr;
    } else if ((timeNow > 16) && (timeNow < 20)) {
      return 'good_evening'.tr;
    } else {
      return 'good_night'.tr;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastTab = Get.find<BottomMenuController>().currentTab;
    _stopWatchingTabs = Get.find<BottomMenuController>().addListener(_onTabChanged);
    Get.find<AddressController>().updateLastLocation();
    // Unread chat badges (menu button, drawer, profile).
    Get.find<ChatInboxController>().refreshUnread();

    // Rebuild only when the icon flips, not on every scroll event.
    _scrollController.addListener((){
      final bool show = _scrollController.offset <= 20;
      if (show != _isShowRideIcon) setState(() => _isShowRideIcon = show);
    });

    // After the first frame: the loaders notify GetBuilders right away, and a
    // home screen opened over another one (Get.offAll from a trip) would
    // otherwise rebuild them mid-build ("setState() called during build").
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) loadData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopWatchingTabs?.call();
    rideShareToolTip.dispose();
    parcelDeliveryToolTip.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool clickedMenu = false;
  Future<void> loadData({bool isReload = false}) async{

    if(isReload) {
      Get.find<ConfigController>().getConfigData();
    }

    final ConfigModel? config = Get.find<ConfigController>().config;
    final bool storesOn = config?.storeOrderingStatus ?? false;
    final RideController rides = Get.find<RideController>();
    final ParcelController parcels = Get.find<ParcelController>();
    final address = Get.find<LocationController>().getUserAddress();

    // Two waves. The server answers a few requests at a time, and Home asks
    // for about twenty, so the customer's trip and the top of the page come
    // first; banners, offers and the rest follow once those are in.

    // Wave 1: the greeting, safety notices, a food order in progress, the info
    // sheets (the tour waits for them below) and the trip state.
    final help = Get.find<AssistantController>().loadHelp();
    // Home may have opened with the saved profile: load the fresh one once.
    if(isReload || !Get.find<ProfileController>().loadedThisSession){
      Get.find<ProfileController>().getProfileInfo();
    }
    Get.find<AreaSafetyController>().loadNearby();
    if (storesOn) Get.find<StoreController>().loadOrders();
    await Future.wait<void>([
      () async {
        await rides.getRunningRideList();
        for (var element in rides.runningRideList?.data ?? const []) {
          PusherHelper().pusherDriverStatus(element.id!);
        }
      }(),
      () async {
        await rides.getCurrentRegularRide();
        if (rides.rideDetails != null) {
          rides.getBiddingList(rides.rideDetails!.id!, 1);
        } else {
          rides.clearBiddingList();
        }
      }(),
      () async {
        await parcels.getRunningParcelList();
        // The list stays empty when the load fails (timeout, 429).
        for (var element in parcels.parcelListModel?.data ?? const []) {
          PusherHelper().pusherDriverStatus(element.id!);
        }
      }(),
    ]);
    if (!mounted) return;

    // Wave 2: the rest of the page.
    Get.find<ParcelController>().getUnpaidParcelList();
    Get.find<BannerController>().getBannerList();
    Get.find<CategoryController>().getCategoryList();
    Get.find<AddressController>().getAddressList(1);
    Get.find<CategoryController>().setCouponFilterIndex(0, isUpdate: false);
    Get.find<OfferController>().getOfferList(1);
    if (config?.exploreStatus ?? config?.stayStatus ?? false) {
      Get.find<ExploreController>().loadCategories();
    }
    // Partner stores, for the food section.
    if (storesOn) Get.find<StoreController>().loadStores();
    // What the "Did you know?" cards and the smart search check: bus booking on
    // (and its destinations), and whether the customer is already ID verified.
    await Future.wait<void>([
      Get.find<BusController>().loadMeta(),
      Get.find<IdVerificationController>().load(),
      if (address?.latitude != null && address?.longitude != null)
        rides.getNearestDriverList(address!.latitude!.toString(), address.longitude!.toString()),
    ]);
    if (!mounted) return;

    // A fresh configuration may still be on its way (the app opened with the saved one).
    await Get.find<ConfigController>().refreshing;

    Get.find<RideController>().toggleShowDriverNearByTooltip(false);
    Get.find<RideController>().toggleShowDriverVerificationTooltip(false);

    HomeScreenHelper.checkMaintanceMode();

    // The first-time tour (once), when the screen has settled; otherwise a
    // "Did you know?" card, chosen now that Home knows what is on.
    await help;
    Get.find<AssistantController>().showTips();
    if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => HomeTour.maybeShow());
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The drawer lives on DashboardScreen's Scaffold (above the nav dock);
      // the menu button in the app bar below opens it.
      // Rebuilds when the configuration changes (the saved one opens Home, the
      // fresh one follows). It used to rebuild on every ride and parcel update,
      // which during a trip meant the whole page, many times a minute.
      body: GetBuilder<ConfigController>(builder: (configController) {
            final ConfigModel? config = configController.config;
            // The hero pill straddles the seam between the dark header and the
            // body card. It lives in this outer Stack, not inside the card, so
            // the half that overlaps the header still receives taps.
            // Dark space under the address line so the hero card never covers it.
            const double headerGap = 58;
            final double headerHeight = MediaQuery.paddingOf(context).top + AppBarWidget.toolbarHeight + headerGap;
            const BorderRadius cardRadius = BorderRadius.vertical(top: Radius.circular(28));

            return Stack(clipBehavior: Clip.none, children: [
              Column(children: [
                GetBuilder<ProfileController>(builder: (profileController) => AppBarWidget(
                  title: '${greetingMessage()}, ${profileController.customerFirstName()}',
                  showBackButton: false, isHome: true, showMenuButton: true, fontSize: Dimensions.fontSizeLarge,
                )),
                const SizedBox(height: headerGap),

                Expanded(child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(borderRadius: cardRadius, color: Theme.of(context).cardColor),
                  child: ClipRRect(
                    borderRadius: cardRadius,
                    child: RefreshIndicator(
                      edgeOffset: HomeHeroSearch.height - HomeHeroSearch.overlap,
                      onRefresh: () async {
                        await loadData(isReload: true);
                      },
                      child: CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // Room for the part of the hero card inside the body.
                            const SizedBox(height: HomeHeroSearch.height - HomeHeroSearch.overlap + Dimensions.paddingSizeLarge),

                            // A food order in progress comes first.
                            const HomeActiveOrders(),

                            // A tour or a one-place visit in progress.
                            const ActiveTourBanner(),

                            // Paused or no-go areas and danger near the rider.
                            const AreaSafetyBanner(),

                            const HomeSavedPlaces(),
                            const SizedBox(height: Dimensions.paddingSizeExtraLarge),

                            HomeSectionHeader(
                              title: 'what_do_you_need_today'.tr,
                              // Ask E-Ride, when the admin has it on.
                              trailing: GetBuilder<AssistantController>(builder: (a) => a.enabled
                                  ? ActionChip(
                                      key: HomeTour.askKey,
                                      avatar: Icon(Icons.auto_awesome_rounded, size: 16, color: Theme.of(context).primaryColor),
                                      label: Text('assistant_ask_short'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor)),
                                      onPressed: () => Get.to(() => const AssistantScreen()),
                                      backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.06),
                                      side: BorderSide(color: Theme.of(context).primaryColor.withValues(alpha: 0.25)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      visualDensity: VisualDensity.compact,
                                    )
                                  : const SizedBox.shrink()),
                            ),
                            // One service the customer has not tried yet.
                            const DidYouKnowCard(),
                            KeyedSubtree(key: HomeTour.servicesKey, child: const HomeServiceGrid()),
                            const HealthRideHomeCard(),

                            const HomeFoodStrip(),
                            const HomeExploreSection(),

                            if((config?.externalSystem ?? false) && Get.find<AuthController>().isLoggedIn())
                              const Padding(
                                padding: EdgeInsets.fromLTRB(
                                  Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, 0,
                                ),
                                child: VisitToMartWidget(),
                              ),

                            GetBuilder<BannerController>(builder: (bannerController) {
                              if(bannerController.bannerList?.isEmpty ?? false) return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraLarge),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  HomeSectionHeader(title: 'offers_for_you'.tr),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                                    child: BannerView(),
                                  ),
                                ]),
                              );
                            }),
                            const SizedBox(height: Dimensions.paddingSizeExtraLarge),

                            const HomeMapView(),
                            const SizedBox(height: Dimensions.paddingSizeDefault),

                            if(config?.referralEarningStatus ?? false)
                              const HomeReferralViewWidget(),

                            const BestOfferWidget(),

                            const HomeCouponWidget(),

                            // Clears the floating nav dock and its raised book button.
                            const SizedBox(height: 124),
                          ])),
                        ],
                      ),
                    ),
                  ),
                )),
              ]),

              // Route motif over the dark header, under the hero card.
              Positioned(
                top: MediaQuery.paddingOf(context).top, left: 0, right: 0,
                height: headerHeight - MediaQuery.paddingOf(context).top,
                child: HomeHeaderMotif(accent: Theme.of(context).primaryColor),
              ),

              Positioned(
                top: headerHeight - HomeHeroSearch.overlap,
                left: Dimensions.paddingSizeDefault,
                right: Dimensions.paddingSizeDefault,
                child: const HomeHeroSearch(),
              ),
            ]);
      }),
      // The trip and parcel buttons follow both lists.
      floatingActionButton: GetBuilder<ParcelController>(builder: (_) => GetBuilder<RideController>(builder: (rideController){
        if(Get.find<ConfigController>().isShowToolTips){
          showToolTips();
        }
        return Column(mainAxisSize:MainAxisSize.min, children: [
          (Get.find<ParcelController>().parcelListModel?.totalSize ?? 0) > 0 && _isShowRideIcon ?
          Padding(
            padding: EdgeInsets.only(
                bottom:rideController.biddingList.isEmpty && ((rideController.runningRideList?.data?.length ?? 0) == 0) ? Get.height * 0.08 : 0
            ),
            child: JustTheTooltip(
              backgroundColor: Get.isDarkMode ?
              Theme.of(context).primaryColor :
              Theme.of(context).textTheme.bodyMedium!.color,
              controller: parcelDeliveryToolTip,
              preferredDirection: AxisDirection.right,
              tailLength: 10,
              tailBaseWidth: 20,
              content: Container(width: 150,
                padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                child: Text(
                  'parcel_delivery'.tr,
                  style: textRegular.copyWith(
                    color: Colors.white, fontSize: Dimensions.fontSizeDefault,
                  ),
                ),
              ),
              child: InkWell(
                onTap: ()=> Get.to(()=> const ParcelListViewScreen(title: 'ongoing_parcel_list')),
                child: Stack(children: [
                  Container(height: 38,width: 38,
                    padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
                    margin: EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).primaryColor
                    ),
                    child: Image.asset(Images.parcelDeliveryIcon),
                  ),

                  Positioned(right: 0,top: 0,
                    child: Container(height: 20,width: 20,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).cardColor
                      ),

                      child: Center(
                        child: Container(height: 18,width: 18,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.error
                          ),
                          child: Center(child: Text(
                            '${Get.find<ParcelController>().parcelListModel?.totalSize}',
                            style: textRegular.copyWith(color: Theme.of(context).cardColor,fontSize: Dimensions.fontSizeSmall),
                          )),
                        ),
                      ),
                    ),
                  )
                ]),
              ),
            ),
          ) :
          const SizedBox(),
          const SizedBox(height: Dimensions.paddingSizeSmall),

          (rideController.runningRideList?.data?.length ?? 0) > 0 && _isShowRideIcon ?
          Padding(
            padding: EdgeInsets.only(bottom: rideController.biddingList.isEmpty ? Get.height * 0.08 : 0),
            child: JustTheTooltip(
              backgroundColor: Get.isDarkMode ?
              Theme.of(context).primaryColor :
              Theme.of(context).textTheme.bodyMedium!.color,
              controller: rideShareToolTip,
              preferredDirection: AxisDirection.right,
              tailLength: 10,
              tailBaseWidth: 20,
              content: Container(width: 100,
                padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                child: Text(
                  'ride_share'.tr,
                  style: textRegular.copyWith(
                    color: Colors.white, fontSize: Dimensions.fontSizeDefault,
                  ),
                ),
              ),
              child: InkWell(
                onTap: ()=> Get.to(()=> const RideListViewScreen()),
                child: Stack(children: [
                  Container(height: 38,width: 38,
                    padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
                    margin: EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).primaryColor
                    ),
                    child: Image.asset(Images.rideShareIcon),
                  ),

                  Positioned(right: 0,top: 0,
                    child: Container(height: 20,width: 20,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).cardColor
                      ),

                      child: Center(
                        child: Container(height: 18,width: 18,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.error
                          ),
                          child: Center(child: Text(
                            '${rideController.runningRideList?.data?.length}',
                            style: textRegular.copyWith(color: Theme.of(context).cardColor,fontSize: Dimensions.fontSizeSmall),
                          )),
                        ),
                      ),
                    ),
                  )
                ]),
              ),
            ),
          ) :
          const SizedBox(),

          rideController.biddingList.isNotEmpty && _isShowRideIcon ?
          Padding(
            padding: EdgeInsets.only(bottom: Get.height * 0.08),
            child: InkWell(
              onTap: (){
                if(!rideController.isLoading){
                  rideController.getBiddingList(
                      rideController.rideDetails!.id!, 1
                  ).then((value) {
                    if(rideController.biddingList.isNotEmpty){

                      Get.dialog(
                          barrierDismissible: true,
                          barrierColor: Colors.black.withValues(alpha:0.5),
                          transitionDuration: const Duration(milliseconds: 500),
                          DriverRideRequestDialog(tripId: Get.find<RideController>().rideDetails!.id!)
                      );
                    }
                  });
                }
              },
              child: Stack(children: [
                Container(height: 38,width: 38,
                  padding: EdgeInsets.all(Dimensions.paddingSizeSeven),
                  margin: EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).primaryColor
                  ),
                  child: Image.asset(Images.biddingIcon),
                ),

                Positioned(right: 0,top: 6,
                  child: Container(height: 12,width: 12,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).cardColor
                    ),
                    child: Center(child: Container(
                      height: 10,width: 10,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.error
                      ),
                    )),
                  ),
                )
              ]),
            ),
          ) :
          const SizedBox()
        ]);
      })),
    );
  }

  void showToolTips(){
    WidgetsBinding.instance.addPostFrameCallback((_){
      Future.delayed(const Duration(seconds: 1)).then((_){
        int ridingCount = (Get.find<RideController>().runningRideList?.data?.length ?? 0);
        int parcelCount = Get.find<ParcelController>().parcelListModel?.totalSize ?? 0;
        if(ridingCount > 0 && _isShowRideIcon){
          rideShareToolTip.showTooltip();
          Get.find<ConfigController>().hideToolTips();
          Future.delayed(const Duration(seconds: 5)).then((_){
            rideShareToolTip.hideTooltip();
          });
        }

        if(parcelCount > 0 && _isShowRideIcon){
          parcelDeliveryToolTip.showTooltip();
          Get.find<ConfigController>().hideToolTips();
          Future.delayed(const Duration(seconds: 5)).then((_){
            parcelDeliveryToolTip.hideTooltip();
          });
        }

      });
    });
  }

}




