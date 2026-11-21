import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/address/controllers/address_controller.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/address/screens/add_new_address.dart';
import 'package:ride_sharing_user_app/features/home/widgets/address_shimmer.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/set_destination/screens/set_destination_screen.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// One-tap shortcuts to the customer's saved addresses, directly under the
/// "Where to?" pill. Each chip does what AddressItemCard does: confirm the
/// address is inside a service zone, then open the destination screen with
/// it pre-filled. With no saved addresses it offers "Add home" / "Add work".
class HomeSavedPlaces extends StatelessWidget {
  const HomeSavedPlaces({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AddressController>(builder: (addressController) {
      final List<Address>? list = addressController.addressList;
      if (list == null) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
          child: AddressShimmer(),
        );
      }

      return SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
          children: list.isEmpty
              ? [
                  _PlaceChip(icon: Icons.home_rounded, title: 'add_home'.tr, dashed: true, onTap: _addAddress),
                  _PlaceChip(icon: Icons.work_rounded, title: 'add_work'.tr, dashed: true, onTap: _addAddress),
                ]
              : [
                  for (final Address a in list)
                    _PlaceChip(
                      icon: _iconFor(a.addressLabel),
                      title: (a.addressLabel ?? 'other').tr,
                      subtitle: a.address,
                      onTap: () => _open(a),
                    ),
                  _PlaceChip(icon: Icons.add_rounded, title: 'add_address'.tr, dashed: true, onTap: _addAddress),
                ],
        ),
      );
    });
  }

  static IconData _iconFor(String? label) {
    switch (label) {
      case 'home':
        return Icons.home_rounded;
      case 'office':
        return Icons.work_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  static void _addAddress() => Get.to(() => const AddNewAddress(address: null));

  static void _open(Address address) {
    Get.find<LocationController>()
        .getZone(address.latitude.toString(), address.longitude.toString())
        .then((value) {
      if (value.isSuccess) {
        Get.to(() => SetDestinationScreen(address: address));
      } else {
        showCustomSnackBar('service_not_available_in_this_area'.tr);
      }
    });
  }
}

class _PlaceChip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool dashed;
  final VoidCallback onTap;

  const _PlaceChip({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color text = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final Color hint = Theme.of(context).hintColor;
    final bool dark = Get.isDarkMode;

    return Padding(
      padding: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
      child: Material(
        color: dashed ? Colors.transparent : hint.withValues(alpha: dark ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(23),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(23),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              border: dashed ? Border.all(color: hint.withValues(alpha: 0.45)) : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: dashed ? hint : Theme.of(context).primaryColor),
              const SizedBox(width: 8),

              Flexible(
                child: subtitle == null
                    ? Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: dashed ? hint : text),
                      )
                    : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: text),
                        ),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: hint),
                        ),
                      ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
