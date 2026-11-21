import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/features/listing/controllers/listing_controller.dart';
import 'package:ride_sharing_user_app/features/listing/domain/models/listing_model.dart';
import 'package:ride_sharing_user_app/features/listing/widgets/listing_widgets.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// List your place, in five steps: what, where, price and terms, living
/// conditions, photos and the policy. Photos come from the camera, so they are
/// real and recent. Editing uses the same steps.
class ListingFormScreen extends StatefulWidget {
  final Listing? listing;
  const ListingFormScreen({super.key, this.listing});

  @override
  State<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends State<ListingFormScreen> {
  final PageController _pages = PageController();
  int _step = 0;
  static const int _steps = 5;

  // What
  String? type;
  final TextEditingController title = TextEditingController();
  int units = 1;
  bool furnished = false;
  // Where
  String? neighbourhood;
  final TextEditingController address = TextEditingController();
  LatLng? pin;
  GoogleMapController? _map;
  // Price and terms
  final TextEditingController rent = TextEditingController();
  String rentPeriod = 'year';
  final TextEditingController advance = TextEditingController();
  final TextEditingController caution = TextEditingController();
  DateTime? availableFrom;
  // Reservation money
  bool reservationsOn = false;
  final TextEditingController reservationAmount = TextEditingController();
  final TextEditingController payoutPhone = TextEditingController();
  final TextEditingController payoutName = TextEditingController();
  // Conditions
  String? water;
  String? power;
  bool backupPower = false;
  String? toilet;
  String? kitchen;
  bool fenced = false;
  bool security = false;
  List<String> amenities = [];
  final TextEditingController description = TextEditingController();
  // Photos and policy
  final List<XFile> newPhotos = [];
  final List<int> removePhotoIds = [];
  String ownerRole = 'owner';
  bool acceptPolicy = false;

  bool get editing => widget.listing != null;

  @override
  void initState() {
    super.initState();
    final Listing? l = widget.listing;
    if (l != null) {
      type = l.type;
      title.text = l.title;
      units = l.unitsAvailable < 1 ? 1 : l.unitsAvailable;
      furnished = l.furnished;
      neighbourhood = l.neighbourhood;
      address.text = l.address ?? '';
      pin = LatLng(l.latitude, l.longitude);
      rent.text = l.rent.round().toString();
      rentPeriod = l.rentPeriod;
      advance.text = l.advanceMonths?.toString() ?? '';
      caution.text = l.caution?.round().toString() ?? '';
      availableFrom = l.availableFrom;
      reservationsOn = l.reservationsOn;
      reservationAmount.text = l.reservationAmount?.round().toString() ?? '';
      payoutPhone.text = l.payoutPhone ?? '';
      payoutName.text = l.payoutName ?? '';
      water = l.water;
      power = l.power;
      backupPower = l.backupPower;
      toilet = l.toilet;
      kitchen = l.kitchen;
      fenced = l.fenced;
      security = l.security;
      amenities = [...l.amenities];
      description.text = l.description ?? '';
      ownerRole = l.ownerRole;
      acceptPolicy = true;
    } else {
      final saved = Get.find<LocationController>().getUserAddress();
      if (saved?.latitude != null && saved?.longitude != null) pin = LatLng(saved!.latitude!, saved.longitude!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<ListingController>().loadMeta());
  }

  @override
  void dispose() {
    _pages.dispose();
    for (final c in [title, address, rent, advance, caution, description, reservationAmount, payoutPhone, payoutName]) {
      c.dispose();
    }
    super.dispose();
  }

  List<ListingPhoto> get keptPhotos =>
      (widget.listing?.photos ?? const []).where((p) => !p.byEride && !removePhotoIds.contains(p.id)).toList();

  int get photoCount => keptPhotos.length + newPhotos.length + (widget.listing?.photos.where((p) => p.byEride).length ?? 0);

  /// Null when the step is complete, else what is missing.
  String? _problem(int step, ListingMeta meta) {
    switch (step) {
      case 0:
        if (type == null) return 'listing_pick_type'.tr;
        if (title.text.trim().length < 5) return 'listing_need_title'.tr;
        return null;
      case 1:
        if (neighbourhood == null) return 'listing_pick_area'.tr;
        if (pin == null) return 'listing_need_pin'.tr;
        return null;
      case 2:
        if ((double.tryParse(rent.text.trim()) ?? 0) <= 0) return 'listing_need_rent'.tr;
        final ListingReservationRules? rules = meta.reservations;
        if (reservationsOn && rules != null) {
          final double amount = double.tryParse(reservationAmount.text.trim()) ?? 0;
          final double yearRent = (double.tryParse(rent.text.trim()) ?? 0) * (rentPeriod == 'year' ? 1 : 12);
          final double max = rules.max < yearRent ? rules.max : yearRent;
          if (amount < rules.min || amount > max) {
            return 'listing_reservation_range'.trParams({'min': PriceConverter.convertPrice(rules.min), 'max': PriceConverter.convertPrice(max)});
          }
          if (payoutPhone.text.replaceAll(RegExp(r'\D'), '').length < 9) return 'listing_need_payout_phone'.tr;
        }
        return null;
      case 3:
        return null;
      default:
        if (photoCount < meta.minPhotos) return 'listing_need_photos'.trParams({'count': '${meta.minPhotos}'});
        if (!acceptPolicy) return 'listing_need_policy'.tr;
        return null;
    }
  }

  void _next(ListingMeta meta) {
    final String? problem = _problem(_step, meta);
    if (problem != null) {
      showCustomSnackBar(problem);
      return;
    }
    if (_step < _steps - 1) {
      FocusScope.of(context).unfocus();
      _pages.animateToPage(_step + 1, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step == 0) {
      Get.back();
    } else {
      _pages.animateToPage(_step - 1, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _submit() async {
    final Map<String, String> fields = {
      'type': type!,
      'title': title.text.trim(),
      'description': description.text.trim(),
      'neighbourhood': neighbourhood!,
      'address': address.text.trim(),
      'latitude': pin!.latitude.toStringAsFixed(7),
      'longitude': pin!.longitude.toStringAsFixed(7),
      'units_available': '$units',
      'furnished': furnished ? '1' : '0',
      'rent': rent.text.trim(),
      'rent_period': rentPeriod,
      if (advance.text.trim().isNotEmpty) 'advance_months': advance.text.trim(),
      if (caution.text.trim().isNotEmpty) 'caution': caution.text.trim(),
      if (availableFrom != null) 'available_from': '${availableFrom!.year}-${availableFrom!.month.toString().padLeft(2, '0')}-${availableFrom!.day.toString().padLeft(2, '0')}',
      if (water != null) 'water': water!,
      if (power != null) 'power': power!,
      'backup_power': backupPower ? '1' : '0',
      if (toilet != null) 'toilet': toilet!,
      if (kitchen != null) 'kitchen': kitchen!,
      'fenced': fenced ? '1' : '0',
      'security': security ? '1' : '0',
      // Only sent while E-Ride offers reservations, so an older setting is never wiped by mistake.
      if (Get.find<ListingController>().meta?.reservations != null) ...{
        'reservations_on': reservationsOn ? '1' : '0',
        if (reservationsOn) 'reservation_amount': reservationAmount.text.trim(),
        if (reservationsOn) 'payout_phone': payoutPhone.text.trim(),
        if (reservationsOn) 'payout_name': payoutName.text.trim(),
      },
      // Always sent, empty clears them.
      'amenities': amenities.join(','),
      'owner_role': ownerRole,
      'accept_policy': acceptPolicy ? '1' : '0',
    };
    final Listing? saved = await Get.find<ListingController>().save(
      id: widget.listing?.id, fields: fields, photos: newPhotos, removePhotoIds: removePhotoIds);
    if (saved == null) return;
    Get.back();
    showCustomSnackBar(editing ? 'listing_saved'.tr : 'listing_submitted'.tr, isError: false, seconds: 5);
  }

  Future<void> _takePhoto(ListingMeta meta) async {
    if (photoCount >= meta.maxPhotos) {
      showCustomSnackBar('listing_photos_max'.trParams({'count': '${meta.maxPhotos}'}));
      return;
    }
    try {
      final XFile? photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
      if (photo != null) setState(() => newPhotos.add(photo));
    } on PlatformException {
      showCustomSnackBar('listing_camera_unavailable'.tr);
    }
  }

  Future<void> _useMyLocation() async {
    final LatLng? here = await Get.find<LocationController>().getCurrentPosition();
    if (here == null) return;
    setState(() => pin = here);
    _map?.animateCamera(CameraUpdate.newLatLngZoom(here, 17));
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ListingController>(builder: (c) {
      final ListingMeta? meta = c.meta;
      return PopScope(
        canPop: _step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          body: BodyWidget(
            appBar: AppBarWidget(title: editing ? 'listing_edit_place'.tr : 'listing_list_your_place'.tr, showBackButton: true, onBackPressed: _back),
            body: meta == null
                ? const Center(child: CircularProgressIndicator())
                : Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, 0),
                      child: Row(children: [
                        for (int i = 0; i < _steps; i++)
                          Expanded(child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: i <= _step ? Theme.of(context).primaryColor : Theme.of(context).hintColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )),
                      ]),
                    ),
                    Expanded(child: PageView(
                      controller: _pages,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() => _step = i),
                      children: [_what(meta), _where(meta), _price(), _conditions(meta), _photos(meta)],
                    )),
                    SafeArea(top: false, child: Padding(
                      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                      child: ButtonWidget(
                        buttonText: _step < _steps - 1 ? 'listing_next'.tr : (editing ? 'listing_save_changes'.tr : 'listing_submit'.tr),
                        onPressed: c.saving ? null : () => _next(meta),
                      ),
                    )),
                  ]),
          ),
        ),
      );
    });
  }

  Widget _page(String heading, List<Widget> children) => ListView(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        children: [
          Text(heading, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: Theme.of(context).textTheme.bodyLarge?.color)),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          ...children,
        ],
      );

  Widget _what(ListingMeta meta) => _page('listing_step_what'.tr, [
        ListingChoice(values: meta.types, selected: type, label: ListingText.type, onChanged: (v) => setState(() => type = v)),
        const SizedBox(height: Dimensions.paddingSizeLarge),
        TextField(controller: title, maxLength: 80, textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'listing_title_label'.tr, hintText: 'listing_title_hint'.tr, border: const OutlineInputBorder())),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Row(children: [
          Expanded(child: Text('listing_units_free'.tr, style: textMedium)),
          IconButton(onPressed: units > 1 ? () => setState(() => units--) : null, icon: const Icon(Icons.remove_circle_outline)),
          Text('$units', style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
          IconButton(onPressed: units < 500 ? () => setState(() => units++) : null, icon: const Icon(Icons.add_circle_outline)),
        ]),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: furnished, title: Text('listing_furnished'.tr), onChanged: (v) => setState(() => furnished = v)),
      ]);

  Widget _where(ListingMeta meta) => _page('listing_step_where'.tr, [
        ListingChoice(values: meta.neighbourhoods, selected: neighbourhood, label: (v) => v, onChanged: (v) => setState(() => neighbourhood = v)),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        Text('listing_pin_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 260,
            child: Stack(alignment: Alignment.center, children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(target: pin ?? const LatLng(5.9631, 10.1591), zoom: pin == null ? 13 : 16),
                onMapCreated: (m) => _map = m,
                onCameraMove: (p) => pin = p.target,
                onCameraIdle: () => setState(() {}),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                // Inside a scrolling page: the map takes the drag, so the pin can be moved.
                gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
              ),
              Padding(padding: const EdgeInsets.only(bottom: 36), child: Icon(Icons.location_on_rounded, size: 44, color: Theme.of(context).primaryColor)),
              Positioned(right: 10, bottom: 10, child: FloatingActionButton.small(
                heroTag: 'listing-my-location', onPressed: _useMyLocation, child: const Icon(Icons.my_location_rounded))),
            ]),
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        TextField(controller: address, maxLength: 191,
            decoration: InputDecoration(labelText: 'listing_address_label'.tr, hintText: 'listing_address_hint'.tr, border: const OutlineInputBorder())),
      ]);

  Widget _price() => _page('listing_step_price'.tr, [
        ListingChoice(values: const ['month', 'year'], selected: rentPeriod,
            label: (v) => v == 'year' ? 'listing_rent_per_year'.tr : 'listing_rent_per_month'.tr, onChanged: (v) => setState(() => rentPeriod = v ?? rentPeriod)),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        TextField(controller: rent, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: rentPeriod == 'year' ? 'listing_rent_per_year'.tr : 'listing_rent_per_month'.tr, border: const OutlineInputBorder())),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        TextField(controller: advance, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'listing_advance_months'.tr, border: const OutlineInputBorder())),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        TextField(controller: caution, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'listing_caution_amount'.tr, border: const OutlineInputBorder())),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_rounded),
          title: Text('listing_free_from'.tr),
          subtitle: Text(availableFrom == null ? 'listing_now'.tr : ListingText.day(availableFrom)),
          onTap: () async {
            final DateTime now = DateTime.now();
            final DateTime? d = await showDatePicker(context: context, initialDate: availableFrom ?? now, firstDate: now, lastDate: now.add(const Duration(days: 365)));
            if (d != null) setState(() => availableFrom = d);
          },
        ),
        if (Get.find<ListingController>().meta?.reservations != null) ..._reservationFields(Get.find<ListingController>().meta!.reservations!),
      ]);

  /// Reservation money, only while E-Ride offers it: the owner opts in, sets the amount and the payout number.
  List<Widget> _reservationFields(ListingReservationRules rules) {
    final ThemeData theme = Theme.of(context);
    return [
      const SizedBox(height: Dimensions.paddingSizeSmall),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: reservationsOn,
        title: Text('listing_let_seekers_reserve'.tr),
        subtitle: Text('listing_let_seekers_reserve_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        onChanged: (v) => setState(() => reservationsOn = v),
      ),
      if (reservationsOn) ...[
        const SizedBox(height: Dimensions.paddingSizeSmall),
        TextField(controller: reservationAmount, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'listing_reservation_amount'.tr,
                helperText: 'listing_reservation_amount_hint'.trParams({'min': PriceConverter.convertPrice(rules.min)}), border: const OutlineInputBorder())),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        TextField(controller: payoutPhone, keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: 'listing_payout_phone'.tr, border: const OutlineInputBorder())),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        TextField(controller: payoutName, maxLength: 80, textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'listing_payout_name'.tr, border: const OutlineInputBorder())),
        Container(
          padding: const EdgeInsets.all(Dimensions.paddingSize),
          decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
          child: Text('listing_reservation_terms'.trParams({'fee': rules.feePercent.toStringAsFixed(rules.feePercent % 1 == 0 ? 0 : 1),
            'hours': '${rules.acceptHours}', 'days': '${rules.releaseDays}'}), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
        ),
      ],
    ];
  }

  Widget _conditions(ListingMeta meta) => _page('listing_step_conditions'.tr, [
        Text('listing_water'.tr, style: textMedium),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        ListingChoice(values: meta.water, selected: water, label: (v) => 'listing_water_$v'.tr, allowNone: true, onChanged: (v) => setState(() => water = v)),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        Text('listing_light'.tr, style: textMedium),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        ListingChoice(values: meta.power, selected: power, label: (v) => 'listing_power_$v'.tr, allowNone: true, onChanged: (v) => setState(() => power = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: backupPower, title: Text('listing_has_backup_power'.tr), onChanged: (v) => setState(() => backupPower = v)),
        Text('listing_toilet'.tr, style: textMedium),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        ListingChoice(values: const ['private', 'shared'], selected: toilet, label: (v) => 'listing_toilet_$v'.tr, allowNone: true, onChanged: (v) => setState(() => toilet = v)),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        Text('listing_kitchen'.tr, style: textMedium),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        ListingChoice(values: const ['private', 'shared', 'none'], selected: kitchen, label: (v) => 'listing_kitchen_$v'.tr, allowNone: true, onChanged: (v) => setState(() => kitchen = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: fenced, title: Text('listing_fenced'.tr), onChanged: (v) => setState(() => fenced = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: security, title: Text('listing_security'.tr), onChanged: (v) => setState(() => security = v)),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Text('listing_extras'.tr, style: textMedium),
        const SizedBox(height: 2),
        Text('listing_extras_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        ListingAmenityPicker(values: ListingAmenity.all(meta), selected: amenities, onChanged: (v) => setState(() => amenities = v)),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        TextField(controller: description, maxLines: 4, maxLength: 1000, textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'listing_description'.tr, hintText: 'listing_description_hint'.tr, border: const OutlineInputBorder())),
      ]);

  Widget _photos(ListingMeta meta) {
    final ThemeData theme = Theme.of(context);
    final List<ListingPhoto> eride = widget.listing?.photos.where((p) => p.byEride).toList() ?? const [];
    return _page('listing_step_photos'.tr, [
      Text('listing_photos_hint'.trParams({'count': '${meta.minPhotos}'}), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
      const SizedBox(height: Dimensions.paddingSizeDefault),
      GridView.count(
        crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: EdgeInsets.zero,
        mainAxisSpacing: 8, crossAxisSpacing: 8,
        children: [
          for (final p in eride) ListingPhotoBox(url: p.url),
          for (final p in keptPhotos)
            _Thumb(child: ListingPhotoBox(url: p.url), onRemove: () => setState(() => removePhotoIds.add(p.id))),
          for (final x in newPhotos)
            _Thumb(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(x.path), fit: BoxFit.cover)),
                onRemove: () => setState(() => newPhotos.remove(x))),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _takePhoto(meta),
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: theme.primaryColor), borderRadius: BorderRadius.circular(12)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.photo_camera_rounded, color: theme.primaryColor),
                const SizedBox(height: 4),
                Text('listing_take_photo'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
              ]),
            ),
          ),
        ],
      ),
      const SizedBox(height: Dimensions.paddingSizeLarge),
      Text('listing_you_are'.tr, style: textMedium),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      ListingChoice(values: const ['owner', 'caretaker'], selected: ownerRole, label: (v) => 'listing_role_$v'.tr, onChanged: (v) => setState(() => ownerRole = v ?? ownerRole)),
      const SizedBox(height: Dimensions.paddingSizeDefault),
      Container(
        padding: const EdgeInsets.all(Dimensions.paddingSize),
        decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
        child: Text('listing_policy_text'.trParams({
          'short': '${meta.confirmDaysShort}', 'long': '${meta.confirmDaysLong}', 'strikes': '${meta.strikeLimit}', 'days': '${meta.banDays}',
        }), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, height: 1.45)),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: acceptPolicy,
        title: Text('listing_accept_policy'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
        onChanged: (v) => setState(() => acceptPolicy = v ?? false),
      ),
    ]);
  }
}

class _Thumb extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  const _Thumb({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        child,
        Positioned(right: 2, top: 2, child: InkWell(
          onTap: onRemove,
          child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close_rounded, size: 16, color: Colors.white)),
        )),
      ]);
}
