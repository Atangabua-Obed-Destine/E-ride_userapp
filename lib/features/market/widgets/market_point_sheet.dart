import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/address/controllers/address_controller.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/location/view/pick_map_screen.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Where to deliver: here, a saved place, or a point on the map. Null when the person backs out.
Future<Address?> pickMarketPoint({String? title, String? hint}) async {
  final dynamic choice = await Get.bottomSheet(_PointSheet(title: title, hint: hint), isScrollControlled: true);
  if (choice is Address) return choice;
  if (choice != 'map') return null;
  Address? picked;
  await Get.to(() => PickMapScreen(
        type: LocationType.location,
        onLocationPicked: (Position position, String address) {
          picked = Address(latitude: position.latitude, longitude: position.longitude, address: address);
        },
      ));
  return picked;
}

class _PointSheet extends StatefulWidget {
  final String? title;
  final String? hint;
  const _PointSheet({this.title, this.hint});

  @override
  State<_PointSheet> createState() => _PointSheetState();
}

class _PointSheetState extends State<_PointSheet> {
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final addresses = Get.find<AddressController>();
    if (addresses.addressList == null) addresses.getAddressList(1);
  }

  Future<void> _here() async {
    setState(() => _locating = true);
    final location = Get.find<LocationController>();
    final latLng = await location.getCurrentPosition();
    if (latLng == null) {
      if (mounted) setState(() => _locating = false);
      showCustomSnackBar('market_location_failed'.tr);
      return;
    }
    final address = await location.getAddressFromGeocode(latLng);
    if (mounted) setState(() => _locating = false);
    Get.back(result: Address(latitude: latLng.latitude, longitude: latLng.longitude, address: address));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, Dimensions.paddingSizeLarge, Dimensions.paddingSizeLarge, 4),
          child: Text(widget.title ?? 'market_ask_delivery'.tr,
              style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
        ),
        if (widget.hint != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
            child: Text(widget.hint!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
          ),
        const SizedBox(height: 8),
        ListTile(
          leading: _locating
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.my_location_rounded, color: theme.primaryColor),
          title: Text('market_point_here'.tr),
          onTap: _locating ? null : _here,
        ),
        ListTile(
          leading: Icon(Icons.map_outlined, color: theme.primaryColor),
          title: Text('market_point_map'.tr),
          onTap: () => Get.back(result: 'map'),
        ),
        Flexible(child: GetBuilder<AddressController>(builder: (addresses) {
          final list = addresses.addressList ?? const <Address>[];
          return ListView(shrinkWrap: true, children: [
            for (final a in list.where((a) => a.latitude != null && a.longitude != null))
              ListTile(
                leading: Icon(Icons.bookmark_border_rounded, color: theme.hintColor),
                title: Text((a.addressLabel ?? '').tr, maxLines: 1),
                subtitle: Text(a.address ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => Get.back(result: a),
              ),
          ]);
        })),
        const SizedBox(height: 8),
      ])),
    );
  }
}
