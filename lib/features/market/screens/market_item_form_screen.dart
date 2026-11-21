import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_posted_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_order_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_sell_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_service_widgets.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_service_settings_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_tags_field.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Post an item, or edit one. A physical item needs a photo; a digital one needs
/// its kind, 1 to 3 preview pages, and the seller saying they own the rights.
class MarketItemFormScreen extends StatefulWidget {
  final MarketItem? item;
  final bool digital;
  /// "Sell something I own": a person, not a shop (no options, stock or wholesale).
  final bool privateSeller;
  /// A service: booked for a time, or quoted (no condition, stock or delivery).
  final bool service;
  const MarketItemFormScreen({super.key, this.item, this.digital = false, this.privateSeller = false, this.service = false});

  @override
  State<MarketItemFormScreen> createState() => _MarketItemFormScreenState();
}

class _MarketItemFormScreenState extends State<MarketItemFormScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _quantity = TextEditingController(text: '1');
  late bool _digital;
  late bool _service;
  /// Services: fixed | from | hour | quote
  String _priceType = 'from';
  int _duration = 60;
  final Set<String> _where = {'place'};
  final List<_ExtraDraft> _extras = [];
  String _serviceKind = 'other';
  String _condition = 'new';
  String? _category;
  /// Words buyers might search for (MarketTagsField).
  List<String> _tags = [];
  String? _kind;
  /// fixed | offers | auction
  String _saleType = 'fixed';
  /// Used items: like_new | good | fair | parts
  String? _grade;
  final TextEditingController _auctionStart = TextEditingController();
  final TextEditingController _auctionStep = TextEditingController();
  final TextEditingController _auctionReserve = TextEditingController();
  int _auctionDays = 3;
  bool _pickup = true;
  bool _eride = true;
  bool _sellerDelivers = false;
  bool _ownsRights = false;
  final List<XFile> _newPhotos = [];
  final List<XFile> _newPreviews = [];
  final List<MarketPhoto> _photos = [];
  final List<MarketPhoto> _previews = [];
  final List<int> _removed = [];
  // Options: colours (each may show one of the item's photos), sizes, stock per choice; wholesale price.
  final List<_ColourDraft> _colours = [];
  final List<String> _sizes = [];
  final Map<String, int> _stock = {};
  final TextEditingController _wholesalePrice = TextEditingController();
  final TextEditingController _wholesaleMin = TextEditingController();

  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _digital = i?.isDigital ?? widget.digital;
    _service = i?.isService ?? widget.service;
    final sv = i?.service;
    if (sv != null) {
      _priceType = sv.priceType;
      _duration = sv.durationMinutes;
      _where
        ..clear()
        ..addAll(sv.where);
      _serviceKind = sv.kind ?? 'other';
      for (final e in sv.extras) {
        _extras.add(_ExtraDraft(e.name, e.price.round()));
      }
    }
    if (i != null) {
      _title.text = i.title;
      _price.text = i.price == null ? '' : i.price!.round().toString();
      _description.text = i.description ?? '';
      _quantity.text = '${i.quantity}';
      _condition = i.isDigital ? 'new' : i.condition;
      _category = i.category;
      _tags = [...i.tags];
      _kind = i.digitalKind;
      // Items posted before sale types: "negotiable" meant open to offers.
      _saleType = i.saleType == 'fixed' && i.negotiable ? 'offers' : i.saleType;
      _grade = i.usedGrade;
      final a = i.auction;
      if (a != null) {
        _auctionStart.text = a.startPrice.round().toString();
        _auctionStep.text = a.step.round().toString();
        if (a.reservePrice != null) _auctionReserve.text = a.reservePrice!.round().toString();
      }
      _pickup = i.pickup;
      _eride = i.erideDelivery;
      _sellerDelivers = i.sellerDelivers;
      _ownsRights = i.isDigital;
      _photos.addAll(i.photos);
      for (final c in i.colours) {
        _colours.add(_ColourDraft(c.name, photoId: c.photoId));
      }
      _sizes.addAll(i.sizes);
      if (i.stock != null) _stock.addAll(i.stock!);
      if (i.wholesalePrice != null) _wholesalePrice.text = i.wholesalePrice!.round().toString();
      if (i.wholesaleMin != null) _wholesaleMin.text = '${i.wholesaleMin}';
      _previews.addAll(i.previews);
    }
    if (widget.item == null && widget.privateSeller) {
      _condition = 'used';
      _grade = 'good';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<MarketController>().loadMeta());
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _description.dispose();
    _quantity.dispose();
    _wholesalePrice.dispose();
    _wholesaleMin.dispose();
    _auctionStart.dispose();
    _auctionStep.dispose();
    _auctionReserve.dispose();
    for (final e in _extras) {
      e.dispose();
    }
    super.dispose();
  }

  int get _maxPhotos => Get.find<MarketController>().meta?.maxPhotos ?? 6;
  int get _maxPreviews => Get.find<MarketController>().meta?.maxPreviews ?? 3;

  Future<void> _addPhotos({required bool previews}) async {
    final int room = previews ? _maxPreviews - _previews.length - _newPreviews.length : _maxPhotos - _photos.length - _newPhotos.length;
    if (room <= 0) {
      showCustomSnackBar('market_photos_full'.tr);
      return;
    }
    final ImageSource? source = await Get.bottomSheet<ImageSource>(Container(
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text('market_take_photo'.tr), onTap: () => Get.back(result: ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text('market_from_gallery'.tr), onTap: () => Get.back(result: ImageSource.gallery)),
      ])),
    ));
    if (source == null) return;
    final picker = ImagePicker();
    List<XFile> picked;
    if (source == ImageSource.camera) {
      final one = await picker.pickImage(source: ImageSource.camera, imageQuality: 72, maxWidth: 1600);
      picked = one == null ? [] : [one];
    } else {
      picked = await picker.pickMultiImage(imageQuality: 72, maxWidth: 1600, limit: room > 1 ? room : null);
    }
    if (picked.isEmpty) return;
    setState(() => (previews ? _newPreviews : _newPhotos).addAll(picked.take(room)));
  }

  void _removeExisting(MarketPhoto p, {required bool preview}) {
    setState(() {
      (preview ? _previews : _photos).remove(p);
      _removed.add(p.id);
      for (final c in _colours) {
        if (c.photoId == p.id) c.photoId = null;
      }
    });
  }

  void _removeAdded(XFile f) {
    setState(() {
      _newPhotos.remove(f);
      for (final c in _colours) {
        if (c.file == f) c.file = null;
      }
    });
  }

  bool get _hasOptions => _colours.isNotEmpty || _sizes.isNotEmpty;

  /// A person selling something they own (now, or the item being edited).
  bool get _private => widget.privateSeller || (Get.find<MarketController>().myShop?.isPrivate ?? false) || (widget.item?.fromPrivateSeller ?? false);

  bool get _auction => _saleType == 'auction' && !_digital && !_service;

  /// An auction with bids cannot be changed any more.
  bool get _auctionLocked => (widget.item?.auction?.bidCount ?? 0) > 0;

  /// Options, stock and wholesale only for shops selling at a fixed price.
  bool get _shopExtras => !_private && !_auction;

  /// Every colour and size combination, in the order shown.
  List<(String?, String?)> get _choices => [
        for (final String? c in (_colours.isEmpty ? <String?>[null] : <String?>[for (final c in _colours) c.name]))
          for (final String? sz in (_sizes.isEmpty ? <String?>[null] : <String?>[..._sizes])) (c, sz),
      ];

  String _key(String? c, String? sz) => '${c ?? ''}|${sz ?? ''}';

  Future<void> _addColour() async {
    final draft = await Get.dialog<_ColourDraft>(_ColourDialog(photos: _photos, added: _newPhotos));
    if (draft == null) return;
    if (_colours.any((c) => c.name.toLowerCase() == draft.name.toLowerCase())) return showCustomSnackBar('market_colour_exists'.tr);
    setState(() => _colours.add(draft));
  }

  Future<void> _editColour(_ColourDraft colour) async {
    final draft = await Get.dialog<_ColourDraft>(_ColourDialog(photos: _photos, added: _newPhotos, initial: colour));
    if (draft == null) return;
    setState(() {
      final old = colour.name;
      colour
        ..name = draft.name
        ..photoId = draft.photoId
        ..file = draft.file;
      if (old != draft.name) {
        for (final String? sz in (_sizes.isEmpty ? <String?>[null] : <String?>[..._sizes])) {
          final v = _stock.remove(_key(old, sz));
          if (v != null) _stock[_key(draft.name, sz)] = v;
        }
      }
    });
  }

  Future<void> _addSizes() async {
    final added = await Get.dialog<List<String>>(_SizeDialog(existing: _sizes));
    if (added == null || added.isEmpty) return;
    setState(() => _sizes.addAll(added.where((v) => !_sizes.contains(v))));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.length < 3) return showCustomSnackBar('market_title_needed'.tr);
    if (!_digital && _photos.isEmpty && _newPhotos.isEmpty) return showCustomSnackBar('market_photo_needed'.tr);
    if (_digital) {
      if (_kind == null) return showCustomSnackBar('market_kind_needed'.tr);
      if (_previews.isEmpty && _newPreviews.isEmpty) return showCustomSnackBar('market_preview_needed'.tr);
      if (!_ownsRights) return showCustomSnackBar('market_rights_needed'.tr);
    }
    final price = _price.text.replaceAll(RegExp(r'[^0-9]'), '');
    final start = _auctionStart.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (_auction && !_auctionLocked && (int.tryParse(start) ?? 0) <= 0) return showCustomSnackBar('market_start_price_needed'.tr);
    if (_service && _priceType != 'quote' && (int.tryParse(price) ?? 0) <= 0) return showCustomSnackBar('market_service_price_needed'.tr);
    if (_service && _where.isEmpty) return showCustomSnackBar('market_service_where_needed'.tr);
    final market = Get.find<MarketController>();
    final firstService = _service && !_editing && !(market.myShop?.hasServices ?? false);
    if (_private && market.myShop == null && !_editing) {
      // The person's private seller profile is made from their name the first time.
      if (await market.openPrivate() == null) return;
    }
    final fields = _service ? <String, String>{
      'title': title,
      'description': _description.text.trim(),
      'condition': 'service',
      'price_type': _priceType,
      'price': _priceType == 'quote' ? '' : price,
      'duration_minutes': '$_duration',
      'service_where': _where.join(','),
      'service_kind': _serviceKind,
      'tags': _tags.join(','),
      'extras': jsonEncode([
        for (final e in _extras)
          if (e.name.text.trim().isNotEmpty) {'name': e.name.text.trim(), 'price': int.tryParse(e.price.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0},
      ]),
    } : <String, String>{
      'title': title,
      'description': _description.text.trim(),
      'price': _auction ? start : price,
      'negotiable': (!_auction && _saleType == 'offers') ? '1' : '0',
      'sale_type': _digital && _saleType == 'auction' ? 'fixed' : _saleType,
      'condition': _digital ? 'digital' : _condition,
      if (!_digital && _condition == 'used' && _grade != null) 'used_grade': _grade!,
      if (_auction && !_auctionLocked) ...{
        'auction_start': start,
        'auction_step': _auctionStep.text.replaceAll(RegExp(r'[^0-9]'), ''),
        'auction_days': '$_auctionDays',
        'auction_reserve': _auctionReserve.text.replaceAll(RegExp(r'[^0-9]'), ''),
      },
      if (_category != null) 'category': _category!,
      'tags': _tags.join(','),
      if (_digital) ...{'digital_kind': _kind!, 'owns_rights': '1'},
      if (!_digital && !_shopExtras) ...{
        'quantity': '${_auction ? 1 : (int.tryParse(_quantity.text.trim()) ?? 1)}',
        'pickup': _pickup ? '1' : '0',
        'eride_delivery': _eride ? '1' : '0',
        'seller_delivers': _sellerDelivers ? '1' : '0',
      },
      if (!_digital && _shopExtras) ...{
        'quantity': '${_hasOptions ? _choices.fold(0, (n, c) => n + (_stock[_key(c.$1, c.$2)] ?? 0)) : (int.tryParse(_quantity.text.trim()) ?? 1)}',
        'options': jsonEncode({
          'colours': [
            for (final c in _colours)
              {'name': c.name, if (c.file != null && _newPhotos.contains(c.file)) 'photo_index': _newPhotos.indexOf(c.file!) else if (c.photoId != null) 'photo_id': c.photoId},
          ],
          'sizes': _sizes,
        }),
        'stock': jsonEncode({for (final c in _choices) _key(c.$1, c.$2): _stock[_key(c.$1, c.$2)] ?? 0}),
        'wholesale_price': _wholesalePrice.text.trim(),
        'wholesale_min': _wholesaleMin.text.trim(),
        'pickup': _pickup ? '1' : '0',
        'eride_delivery': _eride ? '1' : '0',
        'seller_delivers': _sellerDelivers ? '1' : '0',
      },
    };
    final saved = await market.saveItem(
      code: widget.item?.code, fields: fields, photos: _newPhotos, previews: _newPreviews, removePhotoIds: _removed);
    if (saved == null) return;
    if (_editing) {
      showCustomSnackBar('market_item_saved'.tr, isError: false);
      // Navigator, not Get.back: Get.back would only close the snackbar.
      if (mounted) Navigator.of(context).pop();
    } else if (firstService) {
      // The first service: say when you are free, then share it.
      Get.off(() => MarketServiceSettingsScreen(postedService: saved));
    } else {
      Get.off(() => MarketPostedScreen(item: saved, justPosted: true));
    }
  }

  @override
  Widget build(BuildContext context) => MarketChips(child: Builder(builder: _chipsBuild));

  Widget _chipsBuild(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<MarketController>(builder: (market) {
      final meta = market.meta;
      final categories = meta?.categories ?? const <String>[];
      final kinds = meta?.digitalKinds ?? const <String>[];
      return Scaffold(
        backgroundColor: theme.cardColor,
        appBar: AppBar(
          backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
          title: Text((_service ? (_editing ? 'market_edit_service' : 'market_post_service')
              : _editing ? 'market_edit_item' : (_digital ? 'market_post_digital' : (_private ? 'market_sell_own' : 'market_post_item'))).tr),
        ),
        body: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeLarge), children: [
          if (_private) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: marketPrivateBg, borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
              child: Row(children: [
                const Icon(Icons.person_outline_rounded, size: 18, color: marketPrivateFg),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  market.myShop != null
                      ? (_service ? 'market_independent_banner' : 'market_private_banner').trParams({'name': market.myShop!.name})
                      : (_service ? 'market_independent_banner_new' : 'market_private_banner_new').tr,
                  style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: marketPrivateFg, height: 1.4),
                )),
              ]),
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),
          ],
          if (!_editing) ...[
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'item', icon: const Icon(Icons.inventory_2_outlined, size: 18), label: Text('market_physical'.tr)),
                if (!_private && (meta?.digitalAllowed ?? true))
                  ButtonSegment(value: 'digital', icon: const Icon(Icons.description_outlined, size: 18), label: Text('market_digital'.tr)),
                ButtonSegment(value: 'service', icon: const Icon(Icons.event_available_outlined, size: 18), label: Text('market_service'.tr)),
              ],
              selected: {_service ? 'service' : (_digital ? 'digital' : 'item')},
              onSelectionChanged: (v) => setState(() {
                _digital = v.first == 'digital';
                _service = v.first == 'service';
              }),
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),
          ],
          if (_service) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: marketServiceBg, borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
              child: Text('market_service_intro'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: marketServiceFg, height: 1.4)),
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),
          ],
          if (_digital) ...[
            MarketScamNotice(text: 'market_digital_rules'.tr),
            const SizedBox(height: Dimensions.paddingSizeDefault),
          ],

          _Label(_digital ? 'market_cover_optional'.tr : (_service ? 'market_service_photos'.tr : 'market_photos'.tr)),
          _PhotoStrip(
            existing: _photos,
            added: _newPhotos,
            max: _maxPhotos,
            onAdd: () => _addPhotos(previews: false),
            onRemoveExisting: (p) => _removeExisting(p, preview: false),
            onRemoveAdded: _removeAdded,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: Dimensions.paddingSizeDefault),
            child: Text('market_photos_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
          ),

          if (_digital) ...[
            _Label('market_preview_pages'.tr),
            _PhotoStrip(
              existing: _previews,
              added: _newPreviews,
              max: _maxPreviews,
              onAdd: () => _addPhotos(previews: true),
              onRemoveExisting: (p) => _removeExisting(p, preview: true),
              onRemoveAdded: (f) => setState(() => _newPreviews.remove(f)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: Dimensions.paddingSizeDefault),
              child: Text('market_preview_pages_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
            ),
            _Label('market_digital_kind'.tr),
            DropdownButtonFormField<String>(
              initialValue: kinds.contains(_kind) ? _kind : null,
              items: [for (final k in kinds) DropdownMenuItem(value: k, child: Text('market_kind_$k'.tr))],
              onChanged: (v) => setState(() => _kind = v),
              decoration: _input('market_choose_kind'.tr),
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),
          ],

          _Label('market_item_title'.tr),
          TextField(controller: _title, maxLength: 120, textCapitalization: TextCapitalization.sentences,
              decoration: _input((_digital ? 'market_item_title_hint_digital' : (_service ? 'market_service_title_hint' : 'market_item_title_hint')).tr)),
          if (!_service) ...[
            _Label('market_how_sell'.tr),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'fixed', label: Text('market_sale_fixed'.tr)),
                ButtonSegment(value: 'offers', label: Text('market_sale_offers'.tr)),
                if (!_digital)
                  ButtonSegment(value: 'auction', icon: const Icon(Icons.gavel_rounded, size: 16), label: Text('market_auction'.tr),
                      enabled: meta?.auctionRules.canRun ?? true),
              ],
              selected: {_saleType},
              onSelectionChanged: _auctionLocked ? null : (v) => setState(() => _saleType = v.first),
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),
          ],
          if (_service) ..._serviceSection(theme, meta) else if (_auction) ...[
            if (_auctionLocked)
              Padding(
                padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
                child: MarketScamNotice(text: 'market_auction_locked'.tr),
              )
            else ...[
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Label('market_start_price'.tr),
                  TextField(controller: _auctionStart, keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                      decoration: _input('30000').copyWith(suffixText: 'FCFA')),
                ])),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Label('market_bid_step'.tr),
                  TextField(controller: _auctionStep, keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
                      decoration: _input('500').copyWith(suffixText: 'FCFA')),
                ])),
              ]),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              _Label('market_ends_in'.tr),
              Wrap(spacing: 8, children: [
                for (final d in [1, 3, 7].where((d) => d <= (meta?.auctionRules.maxDays ?? 7)))
                  ChoiceChip(
                    label: Text(d == 1 ? 'market_one_day'.tr : 'market_days'.trParams({'count': '$d'})),
                    selected: _auctionDays == d,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _auctionDays = d),
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: Dimensions.paddingSizeDefault),
                child: Text('market_late_bid_hint'.trParams({'minutes': '${meta?.auctionRules.extendMinutes ?? 2}'}),
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
              ),
              _Label('market_reserve'.tr),
              TextField(controller: _auctionReserve, keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                  decoration: _input('market_reserve_hint'.tr).copyWith(suffixText: 'FCFA')),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: Dimensions.paddingSizeDefault),
                child: Text('market_reserve_explain'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor, height: 1.4)),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
                decoration: BoxDecoration(color: marketPrivateBg, borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
                child: Text('market_auction_how_ends'.trParams({'hours': '${meta?.auctionRules.payHours ?? 24}'}),
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: marketPrivateFg, height: 1.45)),
              ),
            ],
          ] else ...[
            _Label('market_price'.tr),
            TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
              decoration: _input('market_price_hint'.tr).copyWith(suffixText: 'FCFA'),
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),
          ],
          if (!_service) ...[
          _Label('market_category'.tr),
          DropdownButtonFormField<String>(
            initialValue: categories.contains(_category) ? _category : null,
            items: [for (final c in categories) DropdownMenuItem(value: c, child: Text(marketCategory(c)))],
            onChanged: (v) => setState(() => _category = v),
            decoration: _input('market_choose_category'.tr),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          ],

          if (!_digital && !_service) ...[
            _Label('market_condition'.tr),
            RadioGroup<String>(
              groupValue: _condition,
              onChanged: (v) => setState(() => _condition = v ?? 'new'),
              child: Row(children: [
                Expanded(child: RadioListTile<String>(value: 'new', dense: true, contentPadding: EdgeInsets.zero, title: Text('market_condition_new'.tr))),
                Expanded(child: RadioListTile<String>(value: 'used', dense: true, contentPadding: EdgeInsets.zero, title: Text('market_condition_used'.tr))),
              ]),
            ),
            if (_condition == 'used') ...[
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final g in const ['like_new', 'good', 'fair', 'parts'])
                  ChoiceChip(
                    label: Text('market_grade_$g'.tr),
                    selected: _grade == g,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _grade = g),
                  ),
              ]),
              const SizedBox(height: Dimensions.paddingSizeDefault),
            ],
            if (!_shopExtras && !_auction) ...[
              _Label('market_quantity'.tr),
              TextField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: _input('1'),
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
            ],
            if (_shopExtras) ...[
            _Label('market_options'.tr),
            Text('market_options_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
            const SizedBox(height: 8),
            Text('market_colours'.tr, style: textMedium.copyWith(color: textColor)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in _colours)
                InputChip(
                  avatar: c.thumb(_photos) == null ? null : CircleAvatar(backgroundImage: c.thumb(_photos)),
                  label: Text(c.name),
                  onPressed: () => _editColour(c),
                  onDeleted: () => setState(() {
                    _colours.remove(c);
                    _stock.removeWhere((k, _) => k.startsWith('${c.name}|'));
                  }),
                ),
              ActionChip(avatar: const Icon(Icons.add_rounded, size: 18), label: Text('market_add_colour'.tr), onPressed: _addColour),
            ]),
            const SizedBox(height: Dimensions.paddingSizeDefault),
            Text('market_sizes'.tr, style: textMedium.copyWith(color: textColor)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final sz in _sizes)
                InputChip(label: Text(sz), onDeleted: () => setState(() {
                  _sizes.remove(sz);
                  _stock.removeWhere((k, _) => k.endsWith('|$sz'));
                })),
              ActionChip(avatar: const Icon(Icons.add_rounded, size: 18), label: Text('market_add_sizes'.tr), onPressed: _addSizes),
            ]),
            const SizedBox(height: Dimensions.paddingSizeDefault),
            if (_hasOptions) ...[
              _Label('market_stock_per_choice'.tr),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                    border: Border.all(color: theme.hintColor.withValues(alpha: 0.25))),
                child: Column(children: [
                  for (final c in _choices)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Expanded(child: Text([if (c.$1 != null) c.$1!, if (c.$2 != null) c.$2!].join(' · '),
                            style: textRegular.copyWith(color: (_stock[_key(c.$1, c.$2)] ?? 0) == 0 ? theme.hintColor : textColor))),
                        MarketQtyStepper(value: _stock[_key(c.$1, c.$2)] ?? 0, min: 0, max: 100000, small: true,
                            onChanged: (v) => setState(() => _stock[_key(c.$1, c.$2)] = v)),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 4),
              Text('market_stock_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
              const SizedBox(height: Dimensions.paddingSizeDefault),
            ] else ...[
              _Label('market_quantity'.tr),
              TextField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                decoration: _input('1'),
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
            ],
            _Label('market_wholesale_price'.tr),
            Row(children: [
              Expanded(child: TextField(
                controller: _wholesalePrice,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                decoration: _input('market_wholesale_price_hint'.tr).copyWith(suffixText: 'FCFA'),
              )),
              const SizedBox(width: 8),
              SizedBox(width: 140, child: TextField(
                controller: _wholesaleMin,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                decoration: _input('market_wholesale_min_hint'.tr),
              )),
            ]),
            const SizedBox(height: 4),
            Text('market_wholesale_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
            const SizedBox(height: Dimensions.paddingSizeDefault),
            ],
            _Label('market_getting_it'.tr),
            CheckboxListTile(value: _pickup, onChanged: (v) => setState(() => _pickup = v ?? false), contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading, title: Text('market_way_pickup'.tr)),
            CheckboxListTile(value: _eride, onChanged: (v) => setState(() => _eride = v ?? false), contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading, title: Text('market_way_eride'.tr)),
            CheckboxListTile(value: _sellerDelivers, onChanged: (v) => setState(() => _sellerDelivers = v ?? false), contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading, title: Text('market_way_seller_self'.tr)),
          ],

          _Label('market_description'.tr),
          TextField(controller: _description, maxLength: 3000, minLines: 4, maxLines: 10, textCapitalization: TextCapitalization.sentences,
              decoration: _input((_digital ? 'market_description_hint_digital' : (_service ? 'market_service_description_hint' : 'market_description_hint')).tr)),

          // Tags: other words buyers search for. A new category or kind of service brings new suggestions.
          MarketTagsField(
            key: ValueKey('tags|${_service ? _serviceKind : (_category ?? '')}'),
            initial: _tags,
            title: _title,
            category: () => _service ? 'services' : (_digital ? (_category ?? 'digital') : _category),
            serviceKind: () => _service ? _serviceKind : null,
            onChanged: (t) => _tags = t,
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          if (_digital)
            CheckboxListTile(
              value: _ownsRights,
              onChanged: (v) => setState(() => _ownsRights = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('market_owns_rights'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
            ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text('market_post_rules_note'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor, height: 1.4)),
          const SizedBox(height: 80),
        ]),
        bottomNavigationBar: SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 8, Dimensions.paddingSizeLarge, 12),
          child: SizedBox(height: 52, child: FilledButton(
            onPressed: market.saving ? null : _save,
            child: market.saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text((_editing ? 'market_save' : 'market_post_now').tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
          )),
        )),
      );
    });
  }

  /// Services: how it is priced, how long it takes, where, extras, and the kind.
  List<Widget> _serviceSection(ThemeData theme, MarketMeta? meta) {
    final kinds = meta?.serviceRules.kinds ?? const MarketServiceRules().kinds;
    final durations = meta?.serviceRules.durations ?? const MarketServiceRules().durations;
    Widget chip(String label, bool on, VoidCallback onTap, {IconData? icon}) => ChoiceChip(
          label: Text(label),
          avatar: icon == null ? null : Icon(icon, size: 16),
          selected: on,
          showCheckmark: false,
          onSelected: (_) => onTap(),
        );
    return [
      _Label('market_service_kind'.tr),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final k in kinds) chip('market_sk_$k'.tr, _serviceKind == k, () => setState(() => _serviceKind = k), icon: marketServiceKindIcon(k)),
      ]),
      const SizedBox(height: Dimensions.paddingSizeDefault),
      _Label('market_price'.tr),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final t in const ['fixed', 'from', 'hour', 'quote']) chip('market_pt_$t'.tr, _priceType == t, () => setState(() => _priceType = t)),
      ]),
      const SizedBox(height: 8),
      if (_priceType != 'quote')
        TextField(
          controller: _price,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
          decoration: _input('8000').copyWith(suffixText: _priceType == 'hour' ? 'FCFA / h' : 'FCFA'),
        )
      else
        Text('market_quote_explain'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
      const SizedBox(height: Dimensions.paddingSizeDefault),
      _Label('market_takes_about'.tr),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final d in durations) chip(marketDuration(d), _duration == d, () => setState(() => _duration = d)),
      ]),
      const SizedBox(height: Dimensions.paddingSizeDefault),
      _Label('market_service_where'.tr),
      for (final w in const ['place', 'client', 'online'])
        CheckboxListTile(
          value: _where.contains(w),
          onChanged: (on) => setState(() => on == true ? _where.add(w) : _where.remove(w)),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          secondary: Icon(marketWhereIcon(w), color: theme.primaryColor),
          title: Text('market_where_$w'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault)),
          subtitle: Text('market_where_${w}_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ),
      const SizedBox(height: 8),
      _Label('market_extras'.tr),
      Text('market_extras_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
      const SizedBox(height: 8),
      for (final e in _extras)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(flex: 3, child: TextField(controller: e.name, maxLength: 40, textCapitalization: TextCapitalization.sentences,
                decoration: _input('market_extra_name_hint'.tr).copyWith(counterText: ''))),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: TextField(controller: e.price, keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                decoration: _input('+2000').copyWith(suffixText: 'FCFA'))),
            IconButton(onPressed: () => setState(() {
              _extras.remove(e);
              e.dispose();
            }), icon: const Icon(Icons.close_rounded)),
          ]),
        ),
      if (_extras.length < 6)
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: () => setState(() => _extras.add(_ExtraDraft('', null))),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text('market_add_extra'.tr),
        )),
      const SizedBox(height: Dimensions.paddingSizeDefault),
    ];
  }

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: Theme.of(context).textTheme.bodyLarge?.color)),
      );
}

class _PhotoStrip extends StatelessWidget {
  final List<MarketPhoto> existing;
  final List<XFile> added;
  final int max;
  final VoidCallback onAdd;
  final ValueChanged<MarketPhoto> onRemoveExisting;
  final ValueChanged<XFile> onRemoveAdded;
  const _PhotoStrip({required this.existing, required this.added, required this.max, required this.onAdd,
      required this.onRemoveExisting, required this.onRemoveAdded});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = existing.length + added.length;
    return SizedBox(
      height: 92,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        if (count < max)
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 92, height: 92,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.primaryColor.withValues(alpha: 0.5)),
                color: theme.primaryColor.withValues(alpha: 0.05),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_a_photo_outlined, color: theme.primaryColor),
                const SizedBox(height: 4),
                Text('$count/$max', style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
              ]),
            ),
          ),
        for (final p in existing)
          _Thumb(onRemove: () => onRemoveExisting(p), child: ImageWidget(image: p.url, width: 92, height: 92, fit: BoxFit.cover)),
        for (final f in added)
          _Thumb(onRemove: () => onRemoveAdded(f), child: Image.file(File(f.path), width: 92, height: 92, fit: BoxFit.cover)),
      ]),
    );
  }
}

class _Thumb extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  const _Thumb({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Stack(children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
          Positioned(top: 4, right: 4, child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
            ),
          )),
        ]),
      );
}

/// A colour being edited: its name and the photo that shows it (one already on the item, or one being added).
class _ColourDraft {
  String name;
  int? photoId;
  XFile? file;
  _ColourDraft(this.name, {this.photoId, this.file});

  ImageProvider? thumb(List<MarketPhoto> photos) {
    if (file != null) return FileImage(File(file!.path));
    final p = photos.where((p) => p.id == photoId).firstOrNull;
    return p == null ? null : NetworkImage(p.url);
  }
}

class _ColourDialog extends StatefulWidget {
  final List<MarketPhoto> photos;
  final List<XFile> added;
  final _ColourDraft? initial;
  const _ColourDialog({required this.photos, required this.added, this.initial});

  @override
  State<_ColourDialog> createState() => _ColourDialogState();
}

class _ColourDialogState extends State<_ColourDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.initial?.name ?? '');
  late int? _photoId = widget.initial?.photoId;
  late XFile? _file = widget.initial?.file;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget pick({required Widget image, required bool selected, required VoidCallback onTap}) => GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? theme.primaryColor : Colors.transparent, width: 3)),
            child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 64, height: 64, child: image)),
          ),
        );
    return AlertDialog(
      title: Text((widget.initial == null ? 'market_add_colour' : 'market_edit_colour').tr),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: _name, maxLength: 40, textCapitalization: TextCapitalization.words, autofocus: widget.initial == null,
            decoration: InputDecoration(hintText: 'market_colour_name_hint'.tr, border: const OutlineInputBorder())),
        Text('market_colour_photo'.tr, style: textMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in widget.photos)
            pick(image: Image.network(p.url, fit: BoxFit.cover), selected: _file == null && _photoId == p.id, onTap: () => setState(() {
              _photoId = p.id;
              _file = null;
            })),
          for (final f in widget.added)
            pick(image: Image.file(File(f.path), fit: BoxFit.cover), selected: _file == f, onTap: () => setState(() {
              _file = f;
              _photoId = null;
            })),
        ]),
        if (widget.photos.isEmpty && widget.added.isEmpty)
          Text('market_colour_add_photos_first'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
      ])),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
        TextButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Get.back(result: _ColourDraft(name, photoId: _photoId, file: _file));
          },
          child: Text('market_save'.tr),
        ),
      ],
    );
  }
}

/// Sizes one by one, or a common set at once.
class _SizeDialog extends StatefulWidget {
  final List<String> existing;
  const _SizeDialog({required this.existing});

  @override
  State<_SizeDialog> createState() => _SizeDialogState();
}

class _SizeDialogState extends State<_SizeDialog> {
  final TextEditingController _size = TextEditingController();
  final List<String> _picked = [];

  static const Map<String, List<String>> _sets = {
    'market_sizes_clothes': ['S', 'M', 'L', 'XL', 'XXL'],
    'market_sizes_shoes': ['38', '39', '40', '41', '42', '43', '44', '45'],
    'market_sizes_kids': ['2Y', '4Y', '6Y', '8Y', '10Y', '12Y'],
  };

  @override
  void dispose() {
    _size.dispose();
    super.dispose();
  }

  void _add(String v) {
    v = v.trim();
    if (v.isEmpty || _picked.contains(v) || widget.existing.contains(v)) return;
    setState(() => _picked.add(v));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('market_add_sizes'.tr),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in _sets.entries)
            ActionChip(label: Text(e.key.tr), onPressed: () {
              for (final v in e.value) {
                _add(v);
              }
            }),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _size, maxLength: 20, onSubmitted: (v) {
            _add(v);
            _size.clear();
          }, decoration: InputDecoration(hintText: 'market_size_hint'.tr, counterText: '', border: const OutlineInputBorder()))),
          IconButton(tooltip: 'market_add'.tr, onPressed: () {
            _add(_size.text);
            _size.clear();
          }, icon: const Icon(Icons.add_circle_outline_rounded)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final v in _picked) InputChip(label: Text(v), onDeleted: () => setState(() => _picked.remove(v))),
        ]),
      ])),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
        TextButton(onPressed: () => Get.back(result: _picked), child: Text('market_add'.tr)),
      ],
    );
  }
}


/// A priced extra being edited ("Long" +2 000).
class _ExtraDraft {
  final TextEditingController name;
  final TextEditingController price;
  _ExtraDraft(String n, int? p)
      : name = TextEditingController(text: n),
        price = TextEditingController(text: p == null || p == 0 ? '' : '$p');
  void dispose() {
    name.dispose();
    price.dispose();
  }
}
