import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/no_data_widget.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/parcel_item.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';

class ParcelListViewScreen extends StatefulWidget {
  final String title;
  /// Parcels the customer still has to pay for (finished or not), instead of the ongoing ones.
  final bool unpaid;
  const ParcelListViewScreen({super.key, required this.title, this.unpaid = false});

  @override
  State<ParcelListViewScreen> createState() => _ParcelListViewScreenState();
}

class _ParcelListViewScreenState extends State<ParcelListViewScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        body: BodyWidget(
          appBar: AppBarWidget(title: widget.title.tr),
          body: GetBuilder<ParcelController>(builder: (parcelController){
            final list = widget.unpaid ? parcelController.unpaidParcelListModel : parcelController.parcelListModel;
            return list == null || (list.data ?? []).isEmpty ?
            const NoDataWidget(title: 'no_trip_found') :
              ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: list.data!.length,
                itemBuilder: (context, index){
                  return ParcelItem(rideRequest: list.data![index],index: index);
                }
            );
          }),
        ),
      ),
    );
  }
}
