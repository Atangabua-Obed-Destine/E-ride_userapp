import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_booking_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_booking_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_point_sheet.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_service_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// "Ask for a quote": what needs doing (and photos), where, when suits. The provider answers
/// with a price and a time; nothing is booked until the client accepts.
class MarketQuoteScreen extends StatefulWidget {
  final MarketItem item;
  const MarketQuoteScreen({super.key, required this.item});

  @override
  State<MarketQuoteScreen> createState() => _MarketQuoteScreenState();
}

class _MarketQuoteScreenState extends State<MarketQuoteScreen> {
  final TextEditingController _note = TextEditingController();
  final List<XFile> _photos = [];
  late String _location;
  Address? _place;
  String _day = 'tomorrow';
  String _part = 'morning';

  @override
  void initState() {
    super.initState();
    _location = widget.item.service?.where.first ?? 'client';
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 3) return;
    final picked = await ImagePicker().pickMultiImage(imageQuality: 70, maxWidth: 1400, limit: 3 - _photos.length > 1 ? 3 - _photos.length : null);
    if (picked.isNotEmpty) setState(() => _photos.addAll(picked.take(3 - _photos.length)));
  }

  Future<void> _pickPlace() async {
    final a = await pickMarketPoint(title: 'market_where_should_come'.tr, hint: 'market_where_should_come_hint'.tr);
    if (a != null && mounted) setState(() => _place = a);
  }

  Future<void> _send() async {
    final note = _note.text.trim();
    if (note.length < 5) return showCustomSnackBar('market_quote_note_needed'.tr);
    if (_location == 'client' && _place == null) return showCustomSnackBar('market_where_should_come'.tr);
    final when = '${'market_when_$_day'.tr}, ${'market_part_$_part'.tr}';
    final b = await Get.find<MarketBookingController>().requestQuote(widget.item.code, {
      'note': note,
      'when_text': when,
      'location': _location,
      if (_location == 'client' && _place != null) ...{'lat': '${_place!.latitude}', 'lng': '${_place!.longitude}', 'address': _place!.address ?? ''},
    }, _photos);
    if (b != null) Get.off(() => MarketBookingScreen(bookingId: b.id, justSent: true));
  }

  @override
  Widget build(BuildContext context) => MarketChips(child: Builder(builder: _chipsBuild));

  Widget _chipsBuild(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final item = widget.item;
    final where = item.service?.where ?? const ['client'];
    final rules = Get.find<MarketController>().meta?.serviceRules;
    Widget label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6, top: 6),
        child: Text(t, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)));
    Widget chips(List<String> keys, String value, ValueChanged<String> onPick, String prefix) => Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in keys) ChoiceChip(label: Text('$prefix$k'.tr), selected: value == k, showCheckmark: false, onSelected: (_) => setState(() => onPick(k))),
        ]);
    return Scaffold(
      backgroundColor: theme.cardColor,
      appBar: AppBar(backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
          title: Text('market_ask_quote_from'.trParams({'name': item.shop?.name ?? ''}), maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeLarge), children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.hintColor.withValues(alpha: 0.2))),
          child: Row(children: [
            MarketShopAvatar(name: item.shop?.name ?? '', logo: item.cover ?? item.shop?.logo, size: 44),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: textSemiBold.copyWith(color: textColor)),
              Text(item.shop?.name ?? '', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ])),
          ]),
        ),
        const SizedBox(height: 8),
        label('market_what_needs_doing'.tr),
        TextField(controller: _note, maxLength: 600, minLines: 3, maxLines: 6, textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: 'market_what_needs_doing_hint'.tr, isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)))),
        Row(children: [
          for (final f in _photos)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(f.path), width: 64, height: 64, fit: BoxFit.cover)),
                Positioned(right: 0, top: 0, child: InkWell(onTap: () => setState(() => _photos.remove(f)),
                    child: Container(decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: Colors.white)))),
              ]),
            ),
          if (_photos.length < 3)
            InkWell(
              onTap: _addPhoto,
              borderRadius: BorderRadius.circular(10),
              child: Container(width: 64, height: 64,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.primaryColor.withValues(alpha: 0.5))),
                  child: Icon(Icons.add_a_photo_outlined, color: theme.primaryColor)),
            ),
          const SizedBox(width: 10),
          Expanded(child: Text('market_quote_photos_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
        ]),
        const SizedBox(height: 8),
        if (where.length > 1) ...[
          label('market_where'.tr),
          Wrap(spacing: 8, children: [
            for (final w in where)
              ChoiceChip(avatar: Icon(marketWhereIcon(w), size: 16), label: Text('market_where_${w}_short'.tr), selected: _location == w, showCheckmark: false,
                  onSelected: (_) => setState(() => _location = w)),
          ]),
        ],
        if (_location == 'client') ...[
          label('market_where_should_come'.tr),
          InkWell(
            onTap: _pickPlace,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(Dimensions.radiusDefault), border: Border.all(color: theme.hintColor.withValues(alpha: 0.3))),
              child: Row(children: [
                Icon(Icons.home_outlined, color: theme.primaryColor),
                const SizedBox(width: 8),
                Expanded(child: Text(_place?.address ?? 'market_choose_place'.tr, style: textRegular.copyWith(color: _place == null ? theme.hintColor : textColor))),
                Text((_place == null ? 'market_choose' : 'market_change').tr, style: textSemiBold.copyWith(color: theme.primaryColor)),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          Text('market_place_private_until_quote'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
        ],
        label('market_when_suits'.tr),
        chips(const ['today', 'tomorrow', 'week', 'flexible'], _day, (v) => _day = v, 'market_when_'),
        const SizedBox(height: 8),
        chips(const ['morning', 'afternoon', 'evening'], _part, (v) => _part = v, 'market_part_'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: marketServiceBg, borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
          child: Text('market_quote_free'.trParams({'hours': '${rules?.quoteHours ?? 24}'}),
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: marketServiceFg, height: 1.45)),
        ),
        const SizedBox(height: 90),
      ]),
      bottomNavigationBar: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 8, Dimensions.paddingSizeLarge, 12),
        child: GetBuilder<MarketBookingController>(builder: (c) => SizedBox(height: 52, child: FilledButton.icon(
          onPressed: c.sending ? null : _send,
          icon: c.sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.request_quote_outlined),
          label: Text('market_ask_quote'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
        ))),
      )),
    );
  }
}
