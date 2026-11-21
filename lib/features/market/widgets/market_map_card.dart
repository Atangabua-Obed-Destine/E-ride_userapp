import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/set_destination/screens/set_destination_screen.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens Google Maps with the way to a point.
Future<void> marketDirections(double lat, double lng) async {
  final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) showCustomSnackBar('could_not_open_link'.tr);
  } catch (_) {
    showCustomSnackBar('could_not_open_link'.tr);
  }
}

/// Books an E-Ride to a point (checks that E-Ride serves it first).
Future<void> marketRideThere(double lat, double lng, String label) async {
  final zone = await Get.find<LocationController>().getZone(lat.toString(), lng.toString());
  if (!zone.isSuccess) return showCustomSnackBar('service_not_available_in_this_area'.tr);
  Get.to(() => SetDestinationScreen(address: Address(latitude: lat, longitude: lng, address: label, addressLabel: 'others')));
}

/// Where a shop is: a small map, the address, how to find it, Directions and "Ride there".
/// Only shops that chose to show it (never private sellers).
class MarketMapCard extends StatefulWidget {
  final String shopName;
  final MarketPoint point;
  final String? note;
  const MarketMapCard({super.key, required this.shopName, required this.point, this.note});

  @override
  State<MarketMapCard> createState() => _MarketMapCardState();
}

class _MarketMapCardState extends State<MarketMapCard> {
  bool _opening = false;

  Future<void> _directions() => marketDirections(widget.point.lat, widget.point.lng);

  Future<void> _rideThere() async {
    if (_opening) return;
    setState(() => _opening = true);
    await marketRideThere(widget.point.lat, widget.point.lng, widget.point.address ?? widget.shopName);
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final at = LatLng(widget.point.lat, widget.point.lng);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.hintColor.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 140, child: GoogleMap(
          initialCameraPosition: CameraPosition(target: at, zoom: 16),
          liteModeEnabled: true,
          markers: {Marker(markerId: const MarkerId('shop'), position: at)},
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          onTap: (_) => _directions(),
        )),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.location_on_outlined, size: 18, color: theme.primaryColor),
              const SizedBox(width: 6),
              Expanded(child: Text(widget.point.address ?? 'market_shop_location'.tr,
                  style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor))),
            ]),
            if (widget.note != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Text(widget.note!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
              ),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _directions,
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: Text('directions'.tr),
              )),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.icon(
                onPressed: _opening ? null : _rideThere,
                icon: _opening
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.local_taxi_outlined, size: 18),
                label: Text('market_ride_there'.tr),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }
}
