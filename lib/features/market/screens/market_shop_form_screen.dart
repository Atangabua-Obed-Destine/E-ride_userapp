import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/location/view/pick_map_screen.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/my_market_shop_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_venue_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_sell_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Open a shop (or edit it): logo, name, what it sells, the area buyers see,
/// a few words, and the private pickup point E-Ride drivers collect from.
class MarketShopFormScreen extends StatefulWidget {
  final MarketShop? shop;
  /// A private seller becomes a shop (a name, what they sell, and the map).
  final bool turnIntoShop;
  /// Opened from a market's page ("List my shop here"): that market is chosen.
  final MarketVenue? startInVenue;
  const MarketShopFormScreen({super.key, this.shop, this.turnIntoShop = false, this.startInVenue});

  @override
  State<MarketShopFormScreen> createState() => _MarketShopFormScreenState();
}

class _MarketShopFormScreenState extends State<MarketShopFormScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _area = TextEditingController();
  final TextEditingController _about = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final List<String> _categories = [];
  bool _onMap = true;
  XFile? _logo;
  double? _lat;
  double? _lng;
  String? _pickupAddress;
  bool _locating = false;
  // In a market: which one, the block and shed, a photo of the shopfront, what it sells.
  String? _venueId;
  final TextEditingController _block = TextEditingController();
  final TextEditingController _building = TextEditingController();
  int? _floor;
  final TextEditingController _shed = TextEditingController();
  final TextEditingController _sellInput = TextEditingController();
  final List<String> _sells = [];
  XFile? _shopfront;

  bool get _editing => widget.shop != null && !widget.turnIntoShop;

  /// Editing a private seller profile: no shop name, categories or map.
  bool get _private => (widget.shop?.isPrivate ?? false) && !widget.turnIntoShop;

  @override
  void initState() {
    super.initState();
    final s = widget.shop;
    if (s != null) {
      _name.text = s.name;
      _area.text = s.area ?? '';
      _about.text = s.about ?? '';
      _categories.addAll(s.categories);
      _lat = s.pickupLat;
      _lng = s.pickupLng;
      _pickupAddress = s.pickupAddress;
      _note.text = s.addressNote ?? '';
      _onMap = s.isPrivate ? true : s.mapVisible;
      // A private seller's name is made from their own; the shop gets a real name.
      if (widget.turnIntoShop) _name.clear();
      _venueId = s.venue?.id;
      _block.text = s.venue?.shedBlock ?? '';
      _building.text = s.venue?.shedBuilding ?? '';
      _floor = s.venue?.shedFloor;
      _shed.text = s.venue?.shedNumber ?? '';
      _sells.addAll(s.sells);
    }
    if (widget.startInVenue != null) _venueId = widget.startInVenue!.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<MarketController>().loadMeta();
      Get.find<MarketController>().loadVenues();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _about.dispose();
    _note.dispose();
    _block.dispose();
    _building.dispose();
    _shed.dispose();
    _sellInput.dispose();
    super.dispose();
  }

  Future<void> _pickShopfront() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75, maxWidth: 1400);
    if (photo != null) setState(() => _shopfront = photo);
  }

  void _addSell([String? value]) {
    for (final part in (value ?? _sellInput.text).split(',')) {
      final t = part.trim().toLowerCase();
      if (t.length >= 2 && t.length <= 24 && !_sells.contains(t) && _sells.length < 12) _sells.add(t);
    }
    _sellInput.clear();
    setState(() {});
  }

  /// Fine-tune the shed's pin on the map.
  void _adjustOnMap() {
    Get.to(() => PickMapScreen(
      type: LocationType.location,
      onLocationPicked: (position, address) {
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
          _pickupAddress = address;
        });
      },
    ));
  }

  Future<void> _pickLogo() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 800);
    if (photo != null) setState(() => _logo = photo);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final location = Get.find<LocationController>();
    final latLng = await location.getCurrentPosition();
    if (latLng != null) {
      final address = await location.getAddressFromGeocode(latLng);
      _lat = latLng.latitude;
      _lng = latLng.longitude;
      _pickupAddress = address;
    } else {
      showCustomSnackBar('market_location_failed'.tr);
    }
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (!_private && name.length < 3) {
      showCustomSnackBar('market_shop_name_needed'.tr);
      return;
    }
    final market = Get.find<MarketController>();
    final fields = <String, String>{
      if (_private) 'kind': 'private',
      if (!_private) ...{
        'name': name,
        'categories': _categories.join(','),
        'map_visible': (_onMap || _venueId != null) ? '1' : '0',
        'address_note': _note.text.trim(),
        'venue_id': _venueId ?? '',
        if (_venueId != null) ...{
          'shed_block': _block.text.trim(),
          'shed_number': _shed.text.trim(),
          'shed_building': _building.text.trim(),
          'shed_floor': _building.text.trim().isEmpty ? '' : '${_floor ?? 0}',
        },
        'sells': _sells.join(','),
      },
      'area_label': _area.text.trim(),
      'about': _about.text.trim(),
      if (_lat != null && _lng != null) ...{'pickup_lat': '$_lat', 'pickup_lng': '$_lng', 'pickup_address': _pickupAddress ?? ''},
      if (widget.shop == null) 'agree_rules': '1',
    };
    if (_venueId != null && _shed.text.trim().isEmpty) {
      showCustomSnackBar('venue_form_shed_needed'.tr);
      return;
    }
    final saved = widget.turnIntoShop
        ? await market.turnIntoShop(fields, _logo, shopfront: _shopfront)
        : await market.saveShop(fields, _logo, shopfront: _shopfront);
    if (saved == null) return;
    if (widget.turnIntoShop) {
      showCustomSnackBar('market_now_a_shop'.tr, isError: false);
      if (mounted) Navigator.of(context).pop();
    } else if (_editing) {
      showCustomSnackBar('market_shop_saved'.tr, isError: false);
      if (mounted) Navigator.of(context).pop();
    } else {
      showCustomSnackBar('market_shop_opened'.tr, isError: false);
      Get.off(() => const MyMarketShopScreen(justOpened: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<MarketController>(builder: (market) {
      final categories = market.meta?.categories ?? const <String>[];
      return Scaffold(
        backgroundColor: theme.cardColor,
        appBar: AppBar(
          backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
          title: Text((widget.turnIntoShop ? 'market_turn_into_shop' : _private ? 'market_edit_profile' : _editing ? 'market_edit_shop' : 'market_open_shop').tr),
        ),
        body: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeLarge), children: [
          Center(child: GestureDetector(
            onTap: _pickLogo,
            child: Stack(clipBehavior: Clip.none, children: [
              _logo != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.file(File(_logo!.path), width: 88, height: 88, fit: BoxFit.cover))
                  : MarketShopAvatar(name: _name.text.trim(), logo: widget.shop?.logo, size: 88),
              Positioned(right: -4, bottom: -4, child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle, border: Border.all(color: theme.cardColor, width: 2)),
                child: const Icon(Icons.photo_camera_outlined, size: 16, color: Colors.white),
              )),
            ]),
          )),
          const SizedBox(height: 6),
          Center(child: Text('market_logo_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
          const SizedBox(height: Dimensions.paddingSizeLarge),
          if (_private) ...[
            Center(child: Text(widget.shop!.name, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor))),
            const SizedBox(height: 4),
            const Center(child: MarketPrivateTag()),
            const SizedBox(height: 6),
            Center(child: Text('market_private_name_hint'.tr, textAlign: TextAlign.center,
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
            const SizedBox(height: Dimensions.paddingSizeLarge),
          ] else ...[
          if (widget.turnIntoShop) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
              decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
              child: Text('market_turn_into_shop_body'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor, height: 1.45)),
            ),
          ],
          _Label('market_shop_name'.tr),
          TextField(
            controller: _name,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: _input(context, 'market_shop_name_hint'.tr),
          ),
          _Label('market_what_you_sell'.tr),
          Text('market_what_you_sell_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in categories)
              FilterChip(
                label: Text(marketCategory(c)),
                selected: _categories.contains(c),
                onSelected: (on) => setState(() => on ? _categories.add(c) : _categories.remove(c)),
                selectedColor: theme.primaryColor.withValues(alpha: 0.12),
                checkmarkColor: theme.primaryColor,
                labelStyle: textMedium.copyWith(color: _categories.contains(c) ? theme.primaryColor : textColor),
                side: BorderSide(color: _categories.contains(c) ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.3)),
              ),
          ]),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          ],
          _Label('market_area'.tr),
          TextField(controller: _area, maxLength: 80, textCapitalization: TextCapitalization.words,
              decoration: _input(context, 'market_area_hint'.tr)),
          _Label((_private ? 'market_about_me' : 'market_about_shop').tr),
          TextField(controller: _about, maxLength: 600, minLines: 3, maxLines: 6, textCapitalization: TextCapitalization.sentences,
              decoration: _input(context, (_private ? 'market_about_me_hint' : 'market_about_shop_hint').tr)),
          if (!_private) _VenueSection(
            venues: market.venues ?? const [],
            venueId: _venueId,
            onVenue: (id) => setState(() => _venueId = id),
            block: _block,
            shed: _shed,
            building: _building,
            floor: _floor,
            onFloor: (f) => setState(() => _floor = f),
            onBuilding: () => setState(() {}),
            sells: _sells,
            sellInput: _sellInput,
            onAddSell: _addSell,
            onRemoveSell: (s) => setState(() => _sells.remove(s)),
            shopfront: _shopfront,
            shopfrontUrl: widget.shop?.venue?.shopfront,
            onShopfront: _pickShopfront,
            verified: widget.shop?.verified ?? false,
          ),
          _Label((_venueId != null ? 'venue_form_pin' : (_private || !_onMap ? 'market_pickup_point' : 'market_shop_location')).tr),
          Text((_venueId != null ? 'venue_form_pin_hint' : (_private || !_onMap ? 'market_pickup_point_hint' : 'market_shop_location_hint')).tr,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Dimensions.radiusDefault), border: Border.all(color: theme.hintColor.withValues(alpha: 0.25))),
            child: Row(children: [
              Icon(Icons.location_on_outlined, color: _lat != null ? theme.primaryColor : theme.hintColor),
              const SizedBox(width: 8),
              Expanded(child: Text(_lat != null ? (_pickupAddress ?? 'market_pickup_set'.tr) : 'market_pickup_not_set'.tr,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: _lat != null ? textColor : theme.hintColor))),
              _locating
                  ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                  : TextButton(onPressed: _useCurrentLocation, child: Text('market_use_here'.tr)),
            ]),
          ),
          if (!_private)
            Align(alignment: Alignment.centerRight, child: TextButton.icon(
              onPressed: _adjustOnMap,
              icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              label: Text('venue_form_adjust_pin'.tr),
            )),
          const SizedBox(height: 4),
          if (_venueId == null && (_private || !_onMap))
            Text('market_pickup_private'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
          if (!_private && _venueId != null) ...[
            const SizedBox(height: 8),
            _Label('venue_form_directions'.tr),
            TextField(controller: _note, maxLength: 160, minLines: 2, maxLines: 3, textCapitalization: TextCapitalization.sentences,
                decoration: _input(context, 'venue_form_directions_hint'.tr)),
          ],
          if (!_private && _venueId == null) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              value: _onMap,
              onChanged: (v) => setState(() => _onMap = v),
              contentPadding: EdgeInsets.zero,
              secondary: Icon(Icons.map_outlined, color: theme.primaryColor),
              title: Text('market_show_on_map'.tr, style: textSemiBold.copyWith(color: textColor)),
              subtitle: Text('market_show_on_map_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ),
            if (_onMap) ...[
              _Label('market_how_to_find'.tr),
              TextField(controller: _note, maxLength: 160, minLines: 1, maxLines: 3, textCapitalization: TextCapitalization.sentences,
                  decoration: _input(context, 'market_how_to_find_hint'.tr)),
            ],
          ],
          const SizedBox(height: 80),
        ]),
        bottomNavigationBar: SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 8, Dimensions.paddingSizeLarge, 12),
          child: SizedBox(height: 52, child: FilledButton(
            onPressed: market.saving ? null : _save,
            child: market.saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text((widget.turnIntoShop ? 'market_turn_into_shop' : (_editing ? 'market_save' : 'market_open_my_shop')).tr,
                    style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
          )),
        )),
      );
    });
  }
}

InputDecoration _input(BuildContext context, String hint) => InputDecoration(
      hintText: hint,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
    );

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: Theme.of(context).textTheme.bodyLarge?.color)),
      );
}


/// "Is your shop in a market?": the market, block, shed, a photo of the
/// shopfront and what the shop sells, in buyers' words.
class _VenueSection extends StatelessWidget {
  final List<MarketVenue> venues;
  final String? venueId;
  final ValueChanged<String?> onVenue;
  final TextEditingController block;
  final TextEditingController shed;
  final TextEditingController building;
  final int? floor;
  final ValueChanged<int?> onFloor;
  final VoidCallback onBuilding;
  final List<String> sells;
  final TextEditingController sellInput;
  final void Function([String? value]) onAddSell;
  final ValueChanged<String> onRemoveSell;
  final XFile? shopfront;
  final String? shopfrontUrl;
  final VoidCallback onShopfront;
  final bool verified;
  const _VenueSection({required this.venues, required this.venueId, required this.onVenue, required this.block, required this.shed,
      required this.building, required this.floor, required this.onFloor, required this.onBuilding,
      required this.sells, required this.sellInput, required this.onAddSell, required this.onRemoveSell, required this.shopfront,
      required this.shopfrontUrl, required this.onShopfront, required this.verified});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color? text = theme.textTheme.bodyLarge?.color;
    final MarketVenue? venue = venues.firstWhereOrNull((v) => v.id == venueId);
    return Container(
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFB45309).withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.location_city_rounded, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(child: Text('venue_form_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: text))),
        ]),
        const SizedBox(height: 4),
        Text('venue_form_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.35)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(label: Text('venue_form_not_in_market'.tr), selected: venueId == null, selectedColor: const Color(0xFFB45309), labelStyle: TextStyle(color: (venueId == null) ? Colors.white : null), checkmarkColor: Colors.white, showCheckmark: false, onSelected: (_) => onVenue(null)),
          for (final v in venues)
            ChoiceChip(label: Text(v.name), selected: venueId == v.id, selectedColor: const Color(0xFFB45309), labelStyle: TextStyle(color: (venueId == v.id) ? Colors.white : null), checkmarkColor: Colors.white, showCheckmark: false, onSelected: (_) => onVenue(v.id)),
        ]),
        if (venueId != null) ...[
          // A building and its floor, when the market has buildings (or the owner names one).
          const SizedBox(height: 12),
          Text('venue_form_building'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: text)),
          const SizedBox(height: 6),
          if (venue != null && venue.buildings.isNotEmpty)
            Wrap(spacing: 6, runSpacing: 6, children: [
              ChoiceChip(label: Text('venue_form_open_air'.tr), selected: building.text.isEmpty, selectedColor: const Color(0xFFB45309), labelStyle: TextStyle(color: (building.text.isEmpty) ? Colors.white : null), checkmarkColor: Colors.white, showCheckmark: false, onSelected: (_) {
                building.clear();
                onFloor(null);
                onBuilding();
              }),
              for (final b in venue.buildings)
                ChoiceChip(
                  avatar: const Icon(Icons.apartment_rounded, size: 16),
                  label: Text(b.name),
                  selected: building.text == b.name, selectedColor: const Color(0xFFB45309), labelStyle: TextStyle(color: (building.text == b.name) ? Colors.white : null), checkmarkColor: Colors.white,
                  showCheckmark: false,
                  onSelected: (_) {
                    building.text = b.name;
                    if (floor == null || floor! >= b.floors) onFloor(0);
                    onBuilding();
                  },
                ),
            ])
          else
            TextField(controller: building, maxLength: 60, textCapitalization: TextCapitalization.words, onChanged: (_) => onBuilding(),
                decoration: _input(context, 'venue_form_building_hint'.tr).copyWith(counterText: '')),
          if (building.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('venue_form_floor'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: text)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (int f = -1; f < (venue?.buildings.firstWhereOrNull((b) => b.name == building.text)?.floors ?? 5); f++)
                ChoiceChip(label: Text(floorName(f)), selected: (floor ?? 0) == f, selectedColor: const Color(0xFFB45309), labelStyle: TextStyle(color: ((floor ?? 0) == f) ? Colors.white : null), checkmarkColor: Colors.white, showCheckmark: false, onSelected: (_) => onFloor(f)),
            ]),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: block, maxLength: 40, textCapitalization: TextCapitalization.words,
                decoration: _input(context, 'venue_form_block_hint'.tr).copyWith(labelText: 'venue_form_block'.tr, counterText: ''))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: shed, maxLength: 30, textCapitalization: TextCapitalization.characters,
                decoration: _input(context, '112').copyWith(labelText: 'venue_form_shed'.tr, counterText: ''))),
          ]),
          if (venue != null && venue.blocks.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final b in venue.blocks)
                ActionChip(label: Text(b), onPressed: () => block.text = b, visualDensity: VisualDensity.compact),
            ]),
          ],
          const SizedBox(height: 12),
          Text('venue_form_shopfront'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: text)),
          Text('venue_form_shopfront_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          const SizedBox(height: 6),
          InkWell(
            onTap: onShopfront,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: theme.hintColor.withValues(alpha: 0.3))),
              clipBehavior: Clip.antiAlias,
              child: shopfront != null
                  ? Image.file(File(shopfront!.path), fit: BoxFit.cover)
                  : shopfrontUrl != null
                      ? Image.network(shopfrontUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.storefront_outlined))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_a_photo_outlined, color: theme.hintColor),
                          const SizedBox(height: 4),
                          Text('venue_form_take_photo'.tr, style: textRegular.copyWith(color: theme.hintColor)),
                        ]),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text('venue_form_sells'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: text)),
        Text('venue_form_sells_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        const SizedBox(height: 6),
        if (sells.isNotEmpty)
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in sells) InputChip(label: Text(s), onDeleted: () => onRemoveSell(s), visualDensity: VisualDensity.compact),
          ]),
        if (sells.length < 12)
          TextField(
            controller: sellInput,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => onAddSell(v),
            decoration: _input(context, 'venue_form_sells_example'.tr).copyWith(
              suffixIcon: IconButton(icon: const Icon(Icons.add_rounded), tooltip: 'add'.tr, onPressed: () => onAddSell()),
            ),
          ),
        if (venueId != null && verified) ...[
          const SizedBox(height: 8),
          Text('venue_form_verified_warning'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.colorScheme.error)),
        ],
      ]),
    );
  }
}
