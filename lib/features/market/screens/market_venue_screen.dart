import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/domain/services/market_service_interface.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_shed_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_shop_form_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_shop_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_map_card.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_venue_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// One market (Bamenda Main Market...): search what you need, see the shops
/// that have it with their shed, as a list or on the map, and walk there.
class MarketVenueScreen extends StatefulWidget {
  final MarketVenue? venue;
  final String? slug;
  final String? query;
  const MarketVenueScreen({super.key, this.venue, this.slug, this.query}) : assert(venue != null || slug != null);

  @override
  State<MarketVenueScreen> createState() => _MarketVenueScreenState();
}

class _MarketVenueScreenState extends State<MarketVenueScreen> {
  late final TextEditingController _search = TextEditingController(text: widget.query ?? '');
  Timer? _debounce;
  MarketVenue? _venue;
  List<MarketShop>? _shops;
  bool _searched = false;
  bool _loading = true;
  bool _verifiedOnly = false;
  String? _block;
  String? _building;
  bool _map = false;
  ({double lat, double lng})? _me;
  int _seq = 0;

  String get _slug => widget.venue?.slug ?? widget.slug!;

  @override
  void initState() {
    super.initState();
    _venue = widget.venue;
    final address = Get.find<LocationController>().getUserAddress();
    if (address?.latitude != null) _me = (lat: address!.latitude!, lng: address.longitude!);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final int seq = ++_seq;
    setState(() => _loading = true);
    final Response r = await Get.find<MarketServiceInterface>()
        .getVenue(_slug, query: _search.text.trim(), verifiedOnly: _verifiedOnly, block: _block, building: _building);
    if (!mounted || seq != _seq) return;
    setState(() {
      _loading = false;
      if (r.statusCode == 200 && r.body['data'] is Map) {
        final Map data = r.body['data'];
        _venue = MarketVenue.fromJson(Map<String, dynamic>.from(data['venue']));
        _searched = data['searched'] == true;
        _shops = [for (final s in (data['shops'] as List? ?? [])) if (s is Map) MarketShop.fromJson(Map<String, dynamic>.from(s))];
      } else {
        _shops ??= [];
      }
    });
  }

  void _changed(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  double? _metres(MarketShop s) =>
      _me == null || s.map == null ? null : venueMetres(_me!.lat, _me!.lng, s.map!.lat, s.map!.lng);

  Future<void> _listMine() async {
    final market = Get.find<MarketController>();
    final meta = await market.loadMeta(force: true);
    if (meta?.myShop != null) await market.loadMyShop();
    final MarketShop? mine = meta?.myShop != null ? market.myShop : null;
    // "My shop is here": straight to the shop form with this market chosen
    // (a private seller turns into a shop; someone new opens one).
    if (mine != null && !mine.isPrivate) {
      Get.to(() => MarketShopFormScreen(shop: mine, startInVenue: _venue));
    } else if (mine != null) {
      Get.to(() => MarketShopFormScreen(shop: mine, turnIntoShop: true, startInVenue: _venue));
    } else {
      Get.to(() => MarketShopFormScreen(startInVenue: _venue));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color? text = theme.textTheme.bodyLarge?.color;
    final venue = _venue;
    final blocks = <String>{...?venue?.blocks, for (final s in _shops ?? const <MarketShop>[]) if (s.venue?.shedBlock != null) s.venue!.shedBlock!}.toList()..sort();
    return Scaffold(
      backgroundColor: theme.cardColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        title: Text(venue?.name ?? '', style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: text)),
        actions: [
          IconButton(
            tooltip: (_map ? 'venue_show_list' : 'venue_show_map').tr,
            onPressed: () => setState(() => _map = !_map),
            icon: Icon(_map ? Icons.view_list_rounded : Icons.map_outlined),
          ),
        ],
      ),
      body: venue == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault, 8),
                child: TextField(
                  controller: _search,
                  onChanged: _changed,
                  onSubmitted: (_) => _load(),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'venue_search_hint'.tr,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'clear'.tr, onPressed: () {
                      _search.clear();
                      _load();
                    }),
                    isDense: true,
                    filled: true,
                    fillColor: theme.hintColor.withValues(alpha: 0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                  children: [
                    Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(
                      avatar: Icon(Icons.verified_rounded, size: 16, color: _verifiedOnly ? marketVerified : theme.hintColor),
                      label: Text('venue_verified_only'.tr),
                      selected: _verifiedOnly,
                      showCheckmark: false,
                      onSelected: (v) {
                        setState(() => _verifiedOnly = v);
                        _load();
                      },
                    )),
                    for (final b in venue.buildings)
                      Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
                        avatar: Icon(Icons.apartment_rounded, size: 16, color: _building == b.name ? marketVenueColor : null),
                        label: Text(b.name),
                        selected: _building == b.name, selectedColor: const Color(0xFFB45309), labelStyle: TextStyle(color: (_building == b.name) ? Colors.white : null), checkmarkColor: Colors.white,
                        showCheckmark: false,
                        onSelected: (on) {
                          setState(() => _building = on ? b.name : null);
                          _load();
                        },
                      )),
                    for (final b in blocks)
                      Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
                        label: Text(b),
                        selected: _block == b, selectedColor: const Color(0xFFB45309), labelStyle: TextStyle(color: (_block == b) ? Colors.white : null), checkmarkColor: Colors.white,
                        showCheckmark: false,
                        onSelected: (on) {
                          setState(() => _block = on ? b : null);
                          _load();
                        },
                      )),
                  ],
                ),
              ),
              if (_loading) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
              Expanded(child: _map ? _VenueMap(venue: venue, shops: _shops ?? const []) : _list(context, venue)),
            ]),
    );
  }

  Widget _list(BuildContext context, MarketVenue venue) {
    final theme = Theme.of(context);
    final shops = _shops;
    if (shops == null) return const SizedBox.shrink();
    final double? toMarket = _me == null ? null : venueMetres(_me!.lat, _me!.lng, venue.lat, venue.lng);
    return ListView(padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 8, Dimensions.paddingSizeDefault, 40), children: [
      if (!_searched) _VenueHeader(venue: venue, metresAway: toMarket),
      if (shops.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(children: [
            const Icon(Icons.storefront_outlined, size: 44, color: marketVenueColor),
            const SizedBox(height: 10),
            Text(
              _searched ? 'venue_nothing_for'.trParams({'q': _search.text.trim(), 'market': venue.name}) : 'venue_no_shops'.tr,
              textAlign: TextAlign.center,
              style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _listMine, icon: const Icon(Icons.add_business_outlined), label: Text('venue_list_my_shop'.tr)),
          ]),
        )
      else ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            _searched
                ? (shops.length == 1 ? 'venue_found_one' : 'venue_found').trParams({'n': '${shops.length}', 'q': _search.text.trim()})
                : (shops.length == 1 ? 'venue_all_shops_one'.tr : 'venue_all_shops'.trParams({'n': '${shops.length}'})),
            style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color),
          ),
        ),
        for (final s in shops) _ShedRow(shop: s, metres: _metres(s)),
        const SizedBox(height: 12),
        Center(child: TextButton.icon(onPressed: _listMine, icon: const Icon(Icons.add_business_outlined), label: Text('venue_list_my_shop'.tr))),
      ],
    ]);
  }
}

class _VenueHeader extends StatelessWidget {
  final MarketVenue venue;
  final double? metresAway;
  const _VenueHeader({required this.venue, this.metresAway});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: marketVenueColor.withValues(alpha: Get.isDarkMode ? 0.18 : 0.07), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (venue.about != null)
          Text(venue.about!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color, height: 1.35)),
        const SizedBox(height: 6),
        Text(
          [
            'venue_counts'.trParams({'n': '${venue.shopsCount}', 'v': '${venue.verifiedCount}'}),
            if (metresAway != null) 'venue_from_you'.trParams({'d': venueDistance(metresAway!)}),
          ].join('  ·  '),
          style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: marketVenueColor),
        ),
        if (metresAway == null || metresAway! > 600) ...[
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: () {
              final gate = venue.entrances.isNotEmpty ? venue.entrances.first : MarketEntrance(name: '', lat: venue.lat, lng: venue.lng);
              marketRideThere(gate.lat, gate.lng, [venue.name, if (gate.name.isNotEmpty) gate.name].join(', '));
            },
            icon: const Icon(Icons.local_taxi_rounded, size: 18),
            label: Text('venue_ride_to_market'.tr),
            style: FilledButton.styleFrom(backgroundColor: marketVenueColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
          )),
        ],
      ]),
    );
  }
}

class _ShedRow extends StatelessWidget {
  final MarketShop shop;
  final double? metres;
  const _ShedRow({required this.shop, this.metres});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = shop.venue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Get.to(() => MarketShopScreen(slug: shop.slug)),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.hintColor.withValues(alpha: 0.18))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(width: 72, height: 72, child: v?.shopfront != null
                    ? ImageWidget(image: v!.shopfront!, fit: BoxFit.cover)
                    : MarketShopAvatar(name: shop.name, logo: shop.logo, size: 72)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(shop.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color))),
                  if (shop.verified) ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, size: 16, color: marketVerified)],
                ]),
                const SizedBox(height: 3),
                if (v != null) Row(children: [
                  Flexible(child: ShedPill(venue: v)),
                  if (metres != null) ...[
                    const SizedBox(width: 6),
                    Text(venueDistance(metres!), style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
                  ],
                ]),
                const SizedBox(height: 4),
                if (shop.matchedItems.isNotEmpty)
                  Text('venue_has'.trParams({'items': shop.matchedItems.join(', ')}), maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor))
                else
                  SellsChips(sells: shop.sells),
                if (!shop.verified)
                  Padding(padding: const EdgeInsets.only(top: 4), child: ShedCheckTag(checked: false)),
              ])),
              if (shop.map != null)
                IconButton(
                  tooltip: 'venue_walk_there'.tr,
                  onPressed: () => Get.to(() => MarketShedScreen(shop: shop)),
                  icon: const Icon(Icons.directions_walk_rounded, color: marketVenueColor),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Every shed of the market on the map; a verified one is blue, the others orange.
class _VenueMap extends StatelessWidget {
  final MarketVenue venue;
  final List<MarketShop> shops;
  const _VenueMap({required this.venue, required this.shops});

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      for (final s in shops)
        if (s.map != null)
          Marker(
            markerId: MarkerId(s.id),
            position: LatLng(s.map!.lat, s.map!.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(s.verified ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: s.name,
              snippet: '${s.venue?.label ?? ''}  ·  ${'venue_walk_there'.tr}',
              onTap: () => Get.to(() => MarketShedScreen(shop: s)),
            ),
          ),
      for (final g in venue.entrances)
        if (g.name.isNotEmpty)
          Marker(
            markerId: MarkerId('gate-${g.name}'),
            position: LatLng(g.lat, g.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: g.name),
          ),
    };
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: LatLng(venue.lat, venue.lng), zoom: 18),
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
    );
  }
}
