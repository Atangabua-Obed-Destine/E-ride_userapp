import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/call_options_sheet.dart';
import 'package:ride_sharing_user_app/features/hotel/controllers/hotel_controller.dart';
import 'package:ride_sharing_user_app/features/hotel/domain/models/hotel_models.dart';
import 'package:ride_sharing_user_app/features/hotel/screens/hotel_chat_screen.dart';
import 'package:ride_sharing_user_app/features/hotel/widgets/hotel_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_map_card.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// A partner hotel: photos, what is free for your dates per room type, and "Ask the reception".
/// [id] is the hotel's id or its verified place's id.
class HotelScreen extends StatefulWidget {
  final String id;
  final String? name;
  const HotelScreen({super.key, required this.id, this.name});

  @override
  State<HotelScreen> createState() => _HotelScreenState();
}

class _HotelScreenState extends State<HotelScreen> {
  HotelController get _c => Get.find<HotelController>();
  final PageController _photos = PageController();
  int _photo = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _c.loadHotel(widget.id));
  }

  @override
  void dispose() {
    _photos.dispose();
    super.dispose();
  }

  Future<void> _ask(HotelDetail h, {HotelRoomType? type}) async {
    if (h.openInquiryId != null && type == null) {
      await Get.to(() => HotelChatScreen(inquiryId: h.openInquiryId!));
      _c.loadHotel(widget.id);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => HotelAskSheet(hotel: h, initial: type),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
      body: GetBuilder<HotelController>(builder: (c) {
        final h = c.detail != null && (c.detail!.id == widget.id || c.detail!.placeId == widget.id) ? c.detail : null;
        if (h == null) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.name ?? ''), backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent),
            body: Center(child: c.loadingDetail ? const CircularProgressIndicator() : Text('hotel_not_available'.tr, style: textRegular.copyWith(color: theme.hintColor))),
          );
        }
        final answer = hotelAnswerText(h.partner.answerMinutes);
        return Stack(children: [
          RefreshIndicator(
            onRefresh: () => c.loadHotel(widget.id),
            child: CustomScrollView(slivers: [
              SliverAppBar(
                expandedHeight: 230,
                pinned: true,
                backgroundColor: theme.cardColor,
                foregroundColor: textColor,
                surfaceTintColor: Colors.transparent,
                automaticallyImplyLeading: false,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => Get.back(),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: h.photos.isEmpty
                      ? const HotelPhoto()
                      : Stack(fit: StackFit.expand, children: [
                          PageView.builder(
                            controller: _photos,
                            itemCount: h.photos.length,
                            onPageChanged: (i) => setState(() => _photo = i),
                            itemBuilder: (_, i) => HotelPhoto(url: h.photos[i]),
                          ),
                          if (h.photos.length > 1)
                            Positioned(
                              right: 12, bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(12)),
                                child: Text('${_photo + 1} / ${h.photos.length}', style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white)),
                              ),
                            ),
                        ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                sliver: SliverList(delegate: SliverChildListDelegate([
                  Row(children: [
                    Expanded(child: Text(h.name, style: textBold.copyWith(fontSize: 20, color: textColor))),
                    HotelChip(text: 'verified_by_eride'.tr, color: hotelGreen, icon: Icons.verified_rounded),
                  ]),
                  const SizedBox(height: 4),
                  Text(h.address, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (answer != null) HotelChip(text: answer, color: textColor ?? Colors.black87, background: theme.hintColor.withValues(alpha: 0.10)),
                    HotelChip(text: 'hotel_check_in_from'.trParams({'time': h.partner.checkInFrom}), color: textColor ?? Colors.black87, background: theme.hintColor.withValues(alpha: 0.10)),
                    HotelChip(text: 'hotel_check_out_by'.trParams({'time': h.partner.checkOutBy}), color: textColor ?? Colors.black87, background: theme.hintColor.withValues(alpha: 0.10)),
                  ]),
                  if (!h.partner.answersNow) ...[
                    const SizedBox(height: 8),
                    Text('hotel_answers_later'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: hotelAmber)),
                  ],
                  if (h.description != null) ...[
                    const SizedBox(height: 10),
                    Text(h.description!, style: textRegular.copyWith(color: textColor)),
                  ],
                  const SizedBox(height: 18),
                  Text('hotel_rooms_for_dates'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
                  const SizedBox(height: 8),
                  HotelDatesBar(onChanged: () => c.loadHotel(widget.id), maxNights: h.maxNights, daysAhead: h.daysAhead),
                  if (!h.partner.fresh) ...[
                    const SizedBox(height: 8),
                    Text('hotel_counts_not_fresh'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                  ],
                  const SizedBox(height: 12),
                  if (c.loadingDetail) const LinearProgressIndicator(minHeight: 2),
                  for (final t in h.roomTypes) _RoomTypeCard(type: t, onAsk: () => _ask(h, type: t)),
                  if (h.roomTypes.isEmpty)
                    Padding(padding: const EdgeInsets.all(24), child: Text('hotel_no_rooms_yet'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(color: theme.hintColor))),
                ])),
              ),
            ]),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(color: theme.cardColor, border: Border(top: BorderSide(color: theme.hintColor.withValues(alpha: 0.2)))),
              child: Row(children: [
                if (h.partner.receptionPhone != null) ...[
                  SizedBox(
                    width: 52, height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => CallOptionsSheet.show(phone: h.partner.receptionPhone, name: h.name),
                      child: Icon(Icons.call_rounded, color: textColor, semanticLabel: 'hotel_call_reception'.tr),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (h.hasLocation) ...[
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => marketRideThere(h.latitude!, h.longitude!, '${h.name}, ${h.address}'),
                      child: Text('ride_there'.tr, style: textBold.copyWith(color: textColor)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: h.roomTypes.isEmpty ? null : () => _ask(h),
                      child: Text(h.openInquiryId != null ? 'hotel_open_chat'.tr : 'hotel_ask_reception_btn'.tr, style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeLarge)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]);
      }),
    );
  }
}

class _RoomTypeCard extends StatelessWidget {
  final HotelRoomType type;
  final VoidCallback onAsk;
  const _RoomTypeCard({required this.type, required this.onAsk});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final full = type.free == 0;
    final details = [
      if (type.beds != null) type.beds!,
      'hotel_up_to_guests'.trParams({'n': '${type.maxGuests}'}),
      ...type.amenities.take(3).map((a) => 'hotel_am_$a'.tr),
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.hintColor.withValues(alpha: 0.18))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          HotelPhoto(url: type.photos.isEmpty ? null : type.photos.first, width: 84, height: 70, radius: BorderRadius.circular(10)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(type.name, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: full ? theme.hintColor : textColor))),
              HotelFreeChip(free: type.free, perType: true),
            ]),
            const SizedBox(height: 3),
            Text(details, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            const SizedBox(height: 4),
            Text.rich(TextSpan(children: [
              TextSpan(text: '${'hotel_from'.tr} ', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              TextSpan(text: hotelMoney(type.priceFrom), style: textBold.copyWith(color: theme.primaryColor)),
              TextSpan(text: ' ${'hotel_per_night'.tr}', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ])),
          ])),
        ]),
        if (!full) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity, height: 44,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(side: BorderSide(color: theme.primaryColor, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: onAsk,
              child: Text('hotel_ask_about_room'.tr, style: textBold.copyWith(color: theme.primaryColor)),
            ),
          ),
        ],
      ]),
    );
  }
}

/// The question: room type, dates, guests, rooms, when you arrive, an optional question.
class HotelAskSheet extends StatefulWidget {
  final HotelDetail hotel;
  final HotelRoomType? initial;
  const HotelAskSheet({super.key, required this.hotel, this.initial});

  @override
  State<HotelAskSheet> createState() => _HotelAskSheetState();
}

class _HotelAskSheetState extends State<HotelAskSheet> {
  late HotelRoomType _type;
  int _guests = 2;
  int _rooms = 1;
  String? _arrival = 'evening';
  final TextEditingController _question = TextEditingController();

  @override
  void initState() {
    super.initState();
    _type = widget.initial ?? widget.hotel.roomTypes.firstWhere((t) => t.free != 0, orElse: () => widget.hotel.roomTypes.first);
    _guests = _type.maxGuests.clamp(1, 2);
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Widget _stepper(String label, int value, int min, int max, ValueChanged<int> set) {
    final theme = Theme.of(context);
    return Row(children: [
      Expanded(child: Text(label, style: textSemiBold.copyWith(color: theme.textTheme.bodyLarge?.color))),
      IconButton.outlined(onPressed: value > min ? () => set(value - 1) : null, icon: const Icon(Icons.remove), tooltip: '-'),
      SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.center, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge))),
      IconButton.outlined(onPressed: value < max ? () => set(value + 1) : null, icon: const Icon(Icons.add), tooltip: '+'),
    ]);
  }

  Future<void> _send() async {
    final c = Get.find<HotelController>();
    final id = await c.ask(widget.hotel.id, roomTypeId: _type.id, guests: _guests, rooms: _rooms, arrival: _arrival, question: _question.text);
    if (id == null || !mounted) return;
    final String hotelId = widget.hotel.id;
    Navigator.of(context).pop();
    await Get.to(() => HotelChatScreen(inquiryId: id));
    c.loadHotel(hotelId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final h = widget.hotel;
    final answer = hotelAnswerText(h.partner.answerMinutes);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Text('hotel_ask_reception_btn'.tr, style: textBold.copyWith(fontSize: 18, color: textColor)),
            Text([h.name, if (answer != null) answer].join(' · '), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _type.id,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'hotel_room_type'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: [
                for (final t in h.roomTypes)
                  DropdownMenuItem(value: t.id, child: Text('${t.name} · ${'hotel_from'.tr} ${hotelMoney(t.priceFrom)}', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (id) => setState(() {
                _type = h.roomTypes.firstWhere((t) => t.id == id);
                _guests = _guests.clamp(1, _type.maxGuests * _rooms);
              }),
            ),
            const SizedBox(height: 12),
            HotelDatesBar(maxNights: h.maxNights, daysAhead: h.daysAhead),
            const SizedBox(height: 8),
            _stepper('hotel_guests'.tr, _guests, 1, _type.maxGuests * _rooms, (v) => setState(() => _guests = v)),
            _stepper('hotel_rooms'.tr, _rooms, 1, h.maxRooms, (v) => setState(() {
              _rooms = v;
              _guests = _guests.clamp(1, _type.maxGuests * _rooms);
            })),
            const SizedBox(height: 8),
            Text('hotel_ill_arrive'.tr, style: textSemiBold.copyWith(color: textColor)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in const ['afternoon', 'evening', 'late'])
                ChoiceChip(
                  label: Text('hotel_when_$a'.tr),
                  selected: _arrival == a,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _arrival = a),
                  selectedColor: theme.primaryColor.withValues(alpha: 0.12),
                  labelStyle: textSemiBold.copyWith(color: _arrival == a ? theme.primaryColor : textColor),
                  side: BorderSide(color: _arrival == a ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.3)),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _question,
              maxLength: 500,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(labelText: 'hotel_question_optional'.tr, hintText: 'hotel_question_hint'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in const ['hotel_q_breakfast', 'hotel_q_parking', 'hotel_q_price'])
                ActionChip(label: Text(s.tr), onPressed: () => setState(() => _question.text = s.tr)),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Text('hotel_nothing_to_pay'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor)),
            ),
            const SizedBox(height: 14),
            GetBuilder<HotelController>(builder: (c) => SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: c.asking ? null : _send,
                    child: c.asking
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text('hotel_send_to_reception'.tr, style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeLarge)),
                  ),
                )),
          ]),
        ),
      ),
    );
  }
}
