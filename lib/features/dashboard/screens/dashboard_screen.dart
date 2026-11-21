import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/notification/controllers/notification_controller.dart';
import 'package:ride_sharing_user_app/features/market/helpers/market_link_helper.dart';
import 'package:ride_sharing_user_app/features/dashboard/domain/models/navigation_model.dart';
import 'package:ride_sharing_user_app/features/dashboard/widgets/app_drawer.dart';
import 'package:ride_sharing_user_app/features/dashboard/widgets/eride_nav_dock.dart';
import 'package:ride_sharing_user_app/features/dashboard/widgets/quick_book_sheet.dart';
import 'package:ride_sharing_user_app/features/home/screens/home_screen.dart';
import 'package:ride_sharing_user_app/features/notification/screens/notification_screen.dart';
import 'package:ride_sharing_user_app/features/profile/screens/profile_screen.dart';
import 'package:ride_sharing_user_app/features/trip/screens/trip_screen.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';


class DashboardScreen extends StatefulWidget {
  /// The dashboard Scaffold owns the drawer, so it draws above the nav dock.
  /// AppBarWidget's menu button opens it through the dashboard showing now.
  /// Each dashboard has its own key: Get.offAll builds a new dashboard while
  /// the old one is still in the tree, and one shared key collided
  /// ("Duplicate GlobalKey").
  static GlobalKey<ScaffoldState>? _activeKey;
  static ScaffoldState? get scaffoldState => _activeKey?.currentState;

  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    DashboardScreen._activeKey = _scaffoldKey;
    // An E-Ride Market link that came in before the rider was in the app.
    WidgetsBinding.instance.addPostFrameCallback((_) => MarketLinkHelper.onAppReady());
    WidgetsBinding.instance.addObserver(this);
    // The Notification tab's badge.
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<NotificationController>().loadCounts());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Get.find<NotificationController>().loadCounts();
  }

  @override
  void dispose() {
    if (identical(DashboardScreen._activeKey, _scaffoldKey)) DashboardScreen._activeKey = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  final PageStorageBucket bucket = PageStorageBucket();

  @override
  Widget build(BuildContext context) {
    final List<NavigationModel> item = [
      NavigationModel(
        name: 'home'.tr,
        activeIcon: Images.homeActive,
        inactiveIcon: Images.homeOutline,
        screen: const HomeScreen(),
      ),
      NavigationModel(
        name: 'activity'.tr,
        activeIcon: Images.activityActive,
        inactiveIcon: Images.activityOutline,
        screen: const TripScreen(fromProfile: false),
      ),
      NavigationModel(
        name: 'notification'.tr,
        activeIcon: Images.notificationActive,
        inactiveIcon: Images.notificationOutline,
        screen: const NotificationScreen(),
        unreadBadge: true,
      ),
      NavigationModel(
        name: 'profile'.tr,
        activeIcon: Images.profileActive,
        inactiveIcon: Images.profileOutline,
        screen: const ProfileScreen(),
      ),
    ];


    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, val) async {
        // Only a back that the route refused (didPop == false) is ours to
        // handle, and with the drawer open it just closes the drawer.
        if (didPop) return;
        final ScaffoldState? scaffold = _scaffoldKey.currentState;
        if (scaffold?.isDrawerOpen ?? false) {
          scaffold!.closeDrawer();
          return;
        }
        if (Get.find<BottomMenuController>().currentTab != 0) {
          Get.find<BottomMenuController>().setTabIndex(0);
          return;
        } else {
          Get.find<BottomMenuController>().exitApp();
        }
        return;
      },

      child: GetBuilder<BottomMenuController>(builder: (menuController) {
        return SafeArea(
          top: false,
          child: Scaffold(
            key: _scaffoldKey,
            resizeToAvoidBottomInset: false,
            drawer: const AppDrawer(),
            drawerEdgeDragWidth: 28,
            body: Stack(children: [

              // Home stays mounted behind the other tabs: re-mounting it re-ran
              // every home request (about 15) on each switch back to it.
              Offstage(
                offstage: menuController.currentTab != 0,
                child: TickerMode(
                  enabled: menuController.currentTab == 0,
                  child: PageStorage(bucket: bucket, child: item[0].screen),
                ),
              ),
              if (menuController.currentTab != 0)
                PageStorage(bucket: bucket, child: item[menuController.currentTab].screen),

              Positioned(
                left: 0, right: 0, bottom: 0,
                child: ERideNavDock(
                  items: item,
                  currentIndex: menuController.currentTab,
                  onSelect: (index) {
                    if (index == menuController.currentTab) return;
                    HapticFeedback.selectionClick();
                    menuController.setTabIndex(index);
                  },
                  onBookTap: () {
                    HapticFeedback.lightImpact();
                    QuickBookSheet.show();
                  },
                ),
              ),

            ]),

          ),
        );
      }),
    );
  }

}
