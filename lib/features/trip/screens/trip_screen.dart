import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/custom_pop_scope_widget.dart';
import 'package:ride_sharing_user_app/features/trip/widgets/trip_item_view.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/features/trip/controllers/trip_controller.dart';
import 'package:ride_sharing_user_app/features/notification/widgets/notification_shimmer.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/no_data_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/paginated_list_widget.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class TripScreen extends StatefulWidget {
  final bool fromProfile;
  const TripScreen({super.key, required this.fromProfile});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> with SingleTickerProviderStateMixin{
  late TabController tabController;
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    tabController = TabController(length: 5, vsync: this);
    Get.find<TripController>().initData();
    Get.find<TripController>().getTripList(1);
    tabController.addListener((){
      if (!tabController.indexIsChanging){
        Get.find<TripController>().setStatusIndex(tabController.index);
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: CustomPopScopeWidget(
        child: Scaffold(
          body: BodyWidget(
            appBar: AppBarWidget(title: 'trip_history'.tr, showBackButton: widget.fromProfile,centerTitle: true,showTripHistoryFilter: true),
            body: Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              child: GetBuilder<TripController>(builder: (tripController) {
                return Column(children: [
                  // Filter pills instead of the underlined tab strip.
                  TabBar(
                    controller: tabController,
                    tabAlignment: TabAlignment.start,
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: Theme.of(context).hintColor,
                    labelStyle: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall),
                    unselectedLabelStyle: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall),
                    labelPadding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
                    indicator: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    dividerHeight: 0,
                    splashBorderRadius: BorderRadius.circular(20),
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    tabs: [
                      Tab(height: 44, text: 'all_trip'.tr),
                      Tab(height: 44, text: 'ongoing'.tr),
                      Tab(height: 44, text: 'cancelled'.tr),
                      Tab(height: 44, text: 'completed'.tr),
                      Tab(height: 44, text: 'returned'.tr)
                    ],
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  Expanded(child: TabBarView(
                      controller: tabController,
                      children: [
                        tabBarBodyWidget(tripController),
                        tabBarBodyWidget(tripController),
                        tabBarBodyWidget(tripController),
                        tabBarBodyWidget(tripController),
                        tabBarBodyWidget(tripController)
                      ]
                  ))

                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget tabBarBodyWidget (TripController tripController){
    return (tripController.tripModel != null && tripController.tripModel!.data != null) ?
    tripController.tripModel!.data!.isNotEmpty ?
    SingleChildScrollView(
      controller: scrollController,
      child: PaginatedListWidget(
        scrollController: scrollController,
        totalSize: tripController.tripModel!.totalSize,
        offset:
        (tripController.tripModel != null && tripController.tripModel!.offset != null) ?
        int.parse(tripController.tripModel!.offset.toString()) :
        null,
        onPaginate: (int? offset) async {
          await tripController.getTripList(offset!);
        },
        itemView: Padding(
          // Clears the floating nav dock.
          padding: const EdgeInsets.only(bottom: 120.0),
          child: ListView.separated(
            itemCount: tripController.tripModel!.data!.length,
            padding: const EdgeInsets.all(0),
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemBuilder: (BuildContext context, int index) {
              return TripItemView(tripDetails: tripController.tripModel!.data![index]);
            },
            separatorBuilder: (BuildContext context, int index) => const SizedBox(height: Dimensions.paddingSizeSmall),
          ),
        ),
      ),
    ) :
    const NoDataWidget(title: 'no_trip_found') :
    const NotificationShimmer();
  }
}
