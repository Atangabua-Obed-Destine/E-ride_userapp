import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_shop_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_map_card.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_venue_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:share_plus/share_plus.dart';

/// Walk to a shed: E-Ride's own map with you (the blue dot turns with the
/// phone), the shed and the gates; the distance, the way to turn and the time
/// on foot as you walk; "You are there" with the shopfront to look for; and a
/// ride to the nearest gate when you are still far.
class MarketShedScreen extends StatefulWidget {
  final MarketShop shop;
  const MarketShedScreen({super.key, required this.shop});

  @override
  State<MarketShedScreen> createState() => _MarketShedScreenState();
}

class _MarketShedScreenState extends State<MarketShedScreen> {
  GoogleMapController? _map;
  StreamSubscription<Position>? _sub;
  Position? _me;
  bool _follow = false;
  bool _arrived = false;
  bool _noLocation = false;
  bool _fitted = false;

  MarketShop get shop => widget.shop;
  LatLng get _shed => LatLng(shop.map!.lat, shop.map!.lng);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever || !await Geolocator.isLocationServiceEnabled()) {
      if (mounted) setState(() => _noLocation = true);
      return;
    }
    _sub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 2))
        .listen(_moved, onError: (_) {
      if (mounted) setState(() => _noLocation = true);
    });
  }

  void _moved(Position p) {
    if (!mounted) return;
    final double d = venueMetres(p.latitude, p.longitude, _shed.latitude, _shed.longitude);
    // There: within 15 m, or within what the GPS can tell under the roofs.
    final bool there = d <= math.max(15, math.min(p.accuracy, 30));
    if (there && !_arrived) HapticFeedback.heavyImpact();
    setState(() {
      _me = p;
      _noLocation = false;
      _arrived = there;
    });
    if (!_fitted) {
      _fitted = true;
      _fit();
    } else if (_follow) {
      _map?.animateCamera(CameraUpdate.newLatLng(LatLng(p.latitude, p.longitude)));
    }
  }

  void _fit() {
    final me = _me;
    if (_map == null) return;
    if (me == null || venueMetres(me.latitude, me.longitude, _shed.latitude, _shed.longitude) > 3000) {
      _map!.animateCamera(CameraUpdate.newLatLngZoom(_shed, 18));
      return;
    }
    final double s = math.min(me.latitude, _shed.latitude), n = math.max(me.latitude, _shed.latitude);
    final double w = math.min(me.longitude, _shed.longitude), e = math.max(me.longitude, _shed.longitude);
    _map!.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(s - 0.0002, w - 0.0002), northeast: LatLng(n + 0.0002, e + 0.0002)), 60));
  }

  /// Degrees from north, from a to b.
  double _bearing(double lat1, double lng1, double lat2, double lng2) {
    final double p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180, dl = (lng2 - lng1) * math.pi / 180;
    final double y = math.sin(dl) * math.cos(p2);
    final double x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// "Head north-east", or, while walking, "Straight ahead" / "On your left"...
  String _way(Position me) {
    final double b = _bearing(me.latitude, me.longitude, _shed.latitude, _shed.longitude);
    if (me.speed > 0.6 && me.heading >= 0) {
      final double rel = (b - me.heading + 540) % 360 - 180;
      if (rel.abs() <= 30) return 'shed_way_ahead'.tr;
      if (rel.abs() >= 150) return 'shed_way_behind'.tr;
      return (rel > 0 ? (rel < 90 ? 'shed_way_ahead_right' : 'shed_way_right') : (rel > -90 ? 'shed_way_ahead_left' : 'shed_way_left')).tr;
    }
    const List<String> dirs = ['north', 'north_east', 'east', 'south_east', 'south', 'south_west', 'west', 'north_west'];
    return 'shed_way_head'.trParams({'dir': 'dir_${dirs[((b + 22.5) % 360 ~/ 45)]}'.tr});
  }

  MarketEntrance get _gate {
    final v = shop.venue;
    final me = _me;
    final gates = v?.entrances ?? const <MarketEntrance>[];
    return nearestEntrance(gates, me?.latitude ?? _shed.latitude, me?.longitude ?? _shed.longitude, fallbackLat: _shed.latitude, fallbackLng: _shed.longitude);
  }

  Future<void> _share() async {
    final v = shop.venue;
    final String where = [v?.name, v?.label].whereType<String>().join(', ');
    await SharePlus.instance.share(ShareParams(text: 'shed_share_text'.trParams({'shop': shop.name, 'where': where, 'link': shop.link})));
  }

  void _photo(String url) => Get.dialog(Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: InteractiveViewer(child: ImageWidget(image: url, fit: BoxFit.contain)),
      ));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color? text = theme.textTheme.bodyLarge?.color;
    final v = shop.venue;
    final me = _me;
    final double? d = me == null ? null : venueMetres(me.latitude, me.longitude, _shed.latitude, _shed.longitude);
    final bool far = d != null && d > 1500;
    final gate = _gate;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('shed'),
        position: _shed,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: shop.name, snippet: v?.label),
      ),
      for (final g in v?.entrances ?? const <MarketEntrance>[])
        if (g.name.isNotEmpty)
          Marker(markerId: MarkerId('gate-${g.name}'), position: LatLng(g.lat, g.lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), infoWindow: InfoWindow(title: g.name)),
    };
    final lines = <Polyline>{
      if (me != null && !far)
        Polyline(
          polylineId: const PolylineId('way'),
          points: [LatLng(me.latitude, me.longitude), _shed],
          color: marketVenueColor,
          width: 4,
          patterns: [PatternItem.dash(18), PatternItem.gap(10)],
        ),
    };

    return Scaffold(
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _shed, zoom: 18),
          onMapCreated: (c) {
            _map = c;
            if (_me != null) _fit();
          },
          markers: markers,
          polylines: lines,
          myLocationEnabled: !_noLocation,
          myLocationButtonEnabled: false,
          compassEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onCameraMoveStarted: () {},
          padding: const EdgeInsets.only(bottom: 280, top: 80),
        ),
        // Back, and the map's own buttons.
        SafeArea(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            _RoundButton(icon: Icons.arrow_back_rounded, tooltip: 'back'.tr, onTap: () => Navigator.of(context).maybePop()),
            const Spacer(),
            _RoundButton(icon: Icons.share_rounded, tooltip: 'shed_share'.tr, onTap: _share),
            const SizedBox(width: 8),
            _RoundButton(icon: Icons.storefront_rounded, tooltip: 'shed_center_shed'.tr,
                onTap: () => _map?.animateCamera(CameraUpdate.newLatLngZoom(_shed, 19))),
            const SizedBox(width: 8),
            _RoundButton(
              icon: _follow ? Icons.navigation_rounded : Icons.my_location_rounded,
              tooltip: 'shed_follow_me'.tr,
              active: _follow,
              onTap: () {
                setState(() => _follow = !_follow);
                if (_follow && me != null) _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(me.latitude, me.longitude), 19));
              },
            ),
          ]),
        )),
        // The panel: where, how far, which way, what to look for.
        Align(alignment: Alignment.bottomCenter, child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12)],
          ),
          child: SafeArea(top: false, child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_arrived)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF12A150).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Row(children: [
                    const Icon(Icons.flag_rounded, color: Color(0xFF12A150)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                        (v?.shedFloor != null && v!.shedFloor != 0)
                            ? (v.shedFloor! > 0 ? 'shed_there_go_up' : 'shed_there_go_down').trParams({
                                'floor': floorName(v.shedFloor!),
                                'building': v.shedBuilding ?? v.name,
                                'shed': v.shedNumber != null ? 'venue_shed_n'.trParams({'n': v.shedNumber!}) : shop.name,
                              })
                            : 'shed_you_are_there'.trParams({'shed': v != null ? shedWords(v) : shop.name}),
                        style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: const Color(0xFF12A150)))),
                  ]),
                ),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (v?.shopfront != null)
                  GestureDetector(
                    onTap: () => _photo(v.shopfront!),
                    child: ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 84, height: 84, child: ImageWidget(image: v!.shopfront!, fit: BoxFit.cover))),
                  )
                else
                  MarketShopAvatar(name: shop.name, logo: shop.logo, size: 64),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(shop.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: text)),
                  const SizedBox(height: 4),
                  if (v != null) ShedPill(venue: v, large: true),
                  const SizedBox(height: 4),
                  if (v != null) Text(v.name, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                  ShedCheckTag(checked: v?.checked ?? false),
                ])),
              ]),
              if (v?.shopfront != null)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text('shed_look_for'.tr,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor))),
              const SizedBox(height: 12),
              // Live: how far, which way, how long.
              if (_noLocation)
                Text('shed_no_location'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.colorScheme.error))
              else if (me == null)
                Row(children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text('shed_finding_you'.tr, style: textRegular.copyWith(color: theme.hintColor)),
                ])
              else if (!_arrived) ...[
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(venueDistance(d!), style: textBold.copyWith(fontSize: 28, color: marketVenueColor, height: 1)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    far ? 'shed_far'.tr : '${_way(me)}  ·  ${'shed_walk_min'.trParams({'n': '${math.max(1, (d / 1.2 / 60).round())}'})}',
                    style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: text),
                  )),
                ]),
                const SizedBox(height: 4),
                Text(
                  me.accuracy > 25 ? 'shed_gps_weak'.trParams({'m': '${me.accuracy.round()}'}) : 'shed_gps_ok'.trParams({'m': '${me.accuracy.round()}'}),
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: me.accuracy > 25 ? marketWarnFg : theme.hintColor),
                ),
              ],
              // The map cannot show floors: say it in words.
              if (v?.shedBuilding != null || (v?.shedFloor ?? 0) != 0) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: marketVenueColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                  child: Row(children: [
                    Icon((v?.shedFloor ?? 0) != 0 ? Icons.stairs_rounded : Icons.apartment_rounded, color: marketVenueColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      [
                        if (v?.shedBuilding != null) 'shed_in_building'.trParams({'building': v!.shedBuilding!}),
                        if (v?.shedFloor != null) floorName(v!.shedFloor!),
                      ].join('  ·  '),
                      style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: text),
                    )),
                  ]),
                ),
              ],
              if (shop.mapNote != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.signpost_outlined, size: 18, color: theme.hintColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(shop.mapNote!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: text, height: 1.35))),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => Get.to(() => MarketShopScreen(slug: shop.slug)),
                  icon: const Icon(Icons.storefront_outlined, size: 18),
                  label: Text('shed_see_shop'.tr, maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                )),
                if (me == null || (d ?? 0) > 400) ...[
                  const SizedBox(width: 8),
                  Expanded(child: FilledButton.icon(
                    onPressed: () => marketRideThere(gate.lat, gate.lng,
                        [v?.name, if (gate.name.isNotEmpty) gate.name].whereType<String>().join(', ')),
                    icon: const Icon(Icons.local_taxi_rounded, size: 18),
                    label: Text(gate.name.isNotEmpty ? 'shed_ride_to_gate'.trParams({'gate': gate.name}) : 'venue_ride_to_market'.tr,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    style: FilledButton.styleFrom(backgroundColor: marketVenueColor, minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                  )),
                ],
              ]),
            ]),
          )),
        )),
      ]),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: active ? marketVenueColor : theme.cardColor,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icon, color: active ? Colors.white : theme.textTheme.bodyLarge?.color)),
    );
  }
}
