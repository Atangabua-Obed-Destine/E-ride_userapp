import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_booking_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_point_sheet.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_service_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// book: the client books a time. reschedule: the client moves a booking. suggest: the provider proposes another time.
enum MarketBookMode { book, reschedule, suggest }

/// Choose a day and a free start time (and for a new booking: extras, where, a note). Returns the booking.
Future<MarketBooking?> showMarketBookSheet({required String itemCode, required String title, MarketServiceInfo? service, double? price,
    MarketBookMode mode = MarketBookMode.book, MarketBooking? booking}) {
  return Get.bottomSheet<MarketBooking>(
    _BookSheet(itemCode: itemCode, title: title, service: service, price: price, mode: mode, booking: booking),
    isScrollControlled: true,
    ignoreSafeArea: false,
    backgroundColor: Get.theme.cardColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
  );
}

class _BookSheet extends StatefulWidget {
  final String itemCode;
  final String title;
  final MarketServiceInfo? service;
  final double? price;
  final MarketBookMode mode;
  final MarketBooking? booking;
  const _BookSheet({required this.itemCode, required this.title, this.service, this.price, required this.mode, this.booking});

  @override
  State<_BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends State<_BookSheet> {
  String? _date;
  String? _time;
  final Set<String> _extras = {};
  late String _location;
  Address? _place;
  final TextEditingController _note = TextEditingController();

  MarketBookingController get _c => Get.find<MarketBookingController>();

  @override
  void initState() {
    super.initState();
    _location = widget.service?.where.first ?? 'place';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final start = widget.booking?.startsAt?.toLocal();
      final s = await _c.loadSlots(widget.itemCode, ignore: widget.booking?.id,
          date: start != null && start.isAfter(DateTime.now()) ? marketApiDate(start) : null);
      if (mounted && s != null) setState(() => _date = s.date);
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDay(String date) async {
    setState(() {
      _date = date;
      _time = null;
    });
    await _c.loadSlots(widget.itemCode, date: date, ignore: widget.booking?.id);
  }

  Future<void> _pickPlace() async {
    final a = await pickMarketPoint(title: 'market_where_should_come'.tr, hint: 'market_where_should_come_hint'.tr);
    if (a != null && mounted) setState(() => _place = a);
  }

  double? get _total {
    if (widget.price == null) return null;
    final extras = (widget.service?.extras ?? const <MarketExtra>[]).where((e) => _extras.contains(e.name)).fold<double>(0, (t, e) => t + e.price);
    return widget.price! + extras;
  }

  Future<void> _send() async {
    if (_date == null || _time == null) return showCustomSnackBar('market_pick_time'.tr);
    final startsAt = '$_date $_time';
    MarketBooking? result;
    switch (widget.mode) {
      case MarketBookMode.book:
        if (_location == 'client' && _place == null) return showCustomSnackBar('market_where_should_come'.tr);
        result = await _c.book(widget.itemCode, {
          'starts_at': startsAt,
          if (_extras.isNotEmpty) 'extras': _extras.join(','),
          'location': _location,
          if (_location == 'client' && _place != null) ...{'lat': _place!.latitude, 'lng': _place!.longitude, 'address': _place!.address ?? ''},
          if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
        });
      case MarketBookMode.reschedule:
        result = await _c.act(widget.booking!.id, 'reschedule', body: {'starts_at': startsAt}, done: 'market_booking_moved');
      case MarketBookMode.suggest:
        result = await _c.act(widget.booking!.id, 'suggest', body: {'starts_at': startsAt}, done: 'market_suggest_sent');
    }
    if (result != null && mounted) Navigator.of(context).pop(result);
  }

  Widget _chip({required Widget label, required bool selected, ValueChanged<bool>? onSelected, Widget? avatar, bool strike = false}) => ChoiceChip(
        avatar: avatar,
        label: strike ? DefaultTextStyle.merge(style: const TextStyle(decoration: TextDecoration.lineThrough), child: label) : label,
        selected: selected,
        showCheckmark: false,
        onSelected: onSelected,
      );

  @override
  Widget build(BuildContext context) => MarketChips(child: Builder(builder: _chipsBuild));

  Widget _chipsBuild(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final rules = Get.find<MarketController>().meta?.serviceRules;
    final book = widget.mode == MarketBookMode.book;
    final service = widget.service;
    return GetBuilder<MarketBookingController>(builder: (c) {
      final slots = c.slots;
      final dayFree = slots?.slots.where((s) => s.free).length ?? 0;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 10),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 12, Dimensions.paddingSizeLarge, 4),
              child: Text(switch (widget.mode) {
                MarketBookMode.book => 'market_book_title'.trParams({'service': widget.title}),
                MarketBookMode.reschedule => 'market_change_time'.tr,
                MarketBookMode.suggest => 'market_suggest_time'.tr,
              }, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
              child: Text(widget.mode == MarketBookMode.suggest ? 'market_suggest_hint'.tr : 'market_takes_about_x'.trParams({'time': marketDuration(slots?.durationMinutes ?? service?.durationMinutes ?? 60)}),
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ),
            Flexible(child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 12, Dimensions.paddingSizeLarge, 8), children: [
              if (book && rules?.cannotBookReason != null) ...[
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(10)),
                    child: Text(rules!.cannotBookReason!, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: const Color(0xFF7F1D1D)))),
                const SizedBox(height: 10),
              ],
              Text('market_day'.tr, style: textSemiBold.copyWith(color: textColor)),
              const SizedBox(height: 6),
              SizedBox(height: 72, child: slots == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: slots.days.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final d = slots.days[i];
                        final on = d.date == _date;
                        final usable = d.open && d.free > 0;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: usable ? () => _pickDay(d.date) : null,
                          child: Container(
                            width: 58,
                            decoration: BoxDecoration(
                              color: on ? textColor : (usable ? null : theme.hintColor.withValues(alpha: 0.06)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: on ? Colors.transparent : theme.hintColor.withValues(alpha: 0.25)),
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text('market_wd_${d.day.weekday}'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall,
                                  color: on ? theme.cardColor : (usable ? theme.hintColor : theme.hintColor.withValues(alpha: 0.5)))),
                              Text('${d.day.day}', style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge,
                                  color: on ? theme.cardColor : (usable ? textColor : theme.hintColor.withValues(alpha: 0.5)))),
                              Text(!d.open ? 'market_closed'.tr : (d.free == 0 ? 'market_full'.tr : (i == 0 ? 'market_today_cap'.tr : '')),
                                  style: textRegular.copyWith(fontSize: 9, color: on ? theme.cardColor : theme.hintColor)),
                            ]),
                          ),
                        );
                      },
                    )),
              const SizedBox(height: 12),
              Row(children: [
                Text('market_start_time'.tr, style: textSemiBold.copyWith(color: textColor)),
                const SizedBox(width: 6),
                Expanded(child: Text('market_crossed_taken'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor))),
              ]),
              const SizedBox(height: 6),
              if (c.slotsLoading && slots != null)
                const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
              else if (slots != null && slots.slots.isEmpty)
                Text('market_no_times'.tr, style: textRegular.copyWith(color: theme.hintColor))
              else if (slots != null)
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in slots.slots)
                    _chip(
                      label: Text(s.time),
                      strike: !s.free,
                      selected: _time == s.time,
                      onSelected: s.free ? (_) => setState(() => _time = s.time) : null,
                    ),
                ]),
              if (slots != null && dayFree == 0 && slots.slots.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text('market_day_full'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
              if (book && (service?.extras.isNotEmpty ?? false)) ...[
                const SizedBox(height: 14),
                Text('market_extras'.tr, style: textSemiBold.copyWith(color: textColor)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in service!.extras)
                    _chip(
                      avatar: _extras.contains(e.name) ? const Icon(Icons.check_rounded) : null,
                      label: Text(e.price > 0 ? '${e.name} +${PriceConverter.convertPrice(e.price)}' : e.name),
                      selected: _extras.contains(e.name),
                      onSelected: (on) => setState(() => on ? _extras.add(e.name) : _extras.remove(e.name)),
                    ),
                ]),
              ],
              if (book && (service?.where.length ?? 1) > 1) ...[
                const SizedBox(height: 14),
                Text('market_where'.tr, style: textSemiBold.copyWith(color: textColor)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final w in service!.where)
                    _chip(
                      avatar: Icon(marketWhereIcon(w)),
                      label: Text('market_where_${w}_short'.tr),
                      selected: _location == w,
                      onSelected: (_) => setState(() => _location = w),
                    ),
                ]),
              ],
              if (book && _location == 'client') ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickPlace,
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(Dimensions.radiusDefault), border: Border.all(color: theme.hintColor.withValues(alpha: 0.3))),
                    child: Row(children: [
                      Icon(Icons.home_outlined, color: theme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_place?.address ?? 'market_where_should_come'.tr,
                          style: textRegular.copyWith(color: _place == null ? theme.hintColor : textColor))),
                      Text((_place == null ? 'market_choose' : 'market_change').tr, style: textSemiBold.copyWith(color: theme.primaryColor)),
                    ]),
                  ),
                ),
                const SizedBox(height: 4),
                Text('market_place_private_until'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
              ],
              if (book) ...[
                const SizedBox(height: 12),
                TextField(controller: _note, maxLength: 600, minLines: 1, maxLines: 3, textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(hintText: 'market_booking_note_hint'.tr, isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)))),
              ],
            ])),
            Container(
              padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 8, Dimensions.paddingSizeLarge, 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (book && _time != null && _date != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(child: Text('${marketDayLabel(DateTime.parse(_date!))} $_time', style: textSemiBold.copyWith(color: textColor))),
                      Text(marketServicePrice(_total, service?.priceType ?? 'fixed'), style: textBold.copyWith(color: theme.primaryColor)),
                    ]),
                  ),
                if (book)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('market_pay_after_job'.trParams({'hours': '${rules?.cancelHours ?? 3}'}),
                        style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
                  ),
                SizedBox(width: double.infinity, height: 52, child: FilledButton(
                  onPressed: c.sending || c.acting || _time == null || (book && rules?.cannotBookReason != null) ? null : _send,
                  child: c.sending || c.acting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(switch (widget.mode) {
                          MarketBookMode.book => 'market_send_booking',
                          MarketBookMode.reschedule => 'market_move_booking',
                          MarketBookMode.suggest => 'market_send_suggestion',
                        }.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
                )),
              ]),
            ),
          ]),
        ),
      );
    });
  }
}
