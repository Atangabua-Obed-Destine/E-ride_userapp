import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_booking_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_posted_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_service_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// "When you are free": the days and hours clients can book, how many at a time, the notice
/// you need, how far ahead, confirming yourself or not, and a pause. Same for all your services.
class MarketServiceSettingsScreen extends StatefulWidget {
  /// Set right after posting the first service: saving goes on to sharing it.
  final MarketItem? postedService;
  const MarketServiceSettingsScreen({super.key, this.postedService});

  @override
  State<MarketServiceSettingsScreen> createState() => _MarketServiceSettingsScreenState();
}

class _MarketServiceSettingsScreenState extends State<MarketServiceSettingsScreen> {
  static const _days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  final Map<String, List<String>?> _hours = {};
  int _capacity = 1;
  int _notice = 120;
  int _ahead = 14;
  bool _confirmMyself = true;
  bool _taking = true;
  final TextEditingController _areas = TextEditingController();
  final TextEditingController _travelFee = TextEditingController();

  @override
  void initState() {
    super.initState();
    final shop = Get.find<MarketController>().myShop;
    for (final d in _days) {
      final h = shop?.serviceHours[d];
      _hours[d] = shop == null || shop.serviceHours.isEmpty ? (d == 'sun' ? null : ['08:00', '18:00']) : (h == null ? null : [...h]);
    }
    if (shop != null) {
      _capacity = shop.serviceCapacity;
      _notice = shop.serviceNoticeMinutes;
      _ahead = shop.serviceAheadDays;
      _confirmMyself = !shop.serviceAutoConfirm;
      _taking = shop.takingBookings;
      _areas.text = shop.serviceAreas ?? '';
      if (shop.travelFee != null) _travelFee.text = shop.travelFee!.round().toString();
    }
  }

  @override
  void dispose() {
    _areas.dispose();
    _travelFee.dispose();
    super.dispose();
  }

  Future<void> _pickTime(String day, int index) async {
    final current = _hours[day]![index].split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(current[0]), minute: int.parse(current[1])),
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null) return;
    final value = '${picked.hour.toString().padLeft(2, '0')}:${(picked.minute >= 30 ? 30 : 0).toString().padLeft(2, '0')}';
    setState(() => _hours[day]![index] = value);
  }

  Future<void> _save() async {
    for (final d in _days) {
      final h = _hours[d];
      if (h != null && h[0].compareTo(h[1]) >= 0) {
        showCustomSnackBar('market_hours_order'.tr);
        return;
      }
    }
    final ok = await Get.find<MarketBookingController>().saveSettings({
      'service_hours': {for (final d in _days) d: _hours[d]},
      'service_capacity': _capacity,
      'service_notice_minutes': _notice,
      'service_ahead_days': _ahead,
      'service_auto_confirm': _confirmMyself ? 0 : 1,
      'taking_bookings': _taking ? 1 : 0,
      'service_areas': _areas.text.trim(),
      'travel_fee': _travelFee.text.trim(),
    }, done: widget.postedService == null ? 'market_settings_saved' : null);
    if (!ok || !mounted) return;
    if (widget.postedService != null) {
      Get.off(() => MarketPostedScreen(item: widget.postedService!, justPosted: true));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => MarketChips(child: Builder(builder: _chipsBuild));

  Widget _chipsBuild(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 4),
          child: Text(t, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
        );
    Widget chips<T>(List<(T, String)> options, T value, ValueChanged<T> onPick) => Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (v, l) in options) ChoiceChip(label: Text(l), selected: v == value, showCheckmark: false, onSelected: (_) => setState(() => onPick(v))),
        ]);
    return Scaffold(
      backgroundColor: theme.cardColor,
      appBar: AppBar(backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent, title: Text('market_when_free'.tr)),
      body: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeLarge), children: [
        if (widget.postedService != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: marketServiceBg, borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
            child: Text('market_when_free_first'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: marketServiceFg, height: 1.45)),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
        ],
        Text('market_when_free_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.45)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.hintColor.withValues(alpha: 0.2))),
          child: Column(children: [
            for (final d in _days)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  SizedBox(width: 46, child: Text('market_wd_${_days.indexOf(d) + 1}'.tr, style: textBold.copyWith(color: textColor))),
                  Expanded(child: _hours[d] == null
                      ? Text('market_closed'.tr, style: textRegular.copyWith(color: theme.hintColor))
                      : Row(children: [
                          TextButton(onPressed: () => _pickTime(d, 0), child: Text(_hours[d]![0])),
                          Text('market_to'.tr, style: textRegular.copyWith(color: theme.hintColor)),
                          TextButton(onPressed: () => _pickTime(d, 1), child: Text(_hours[d]![1])),
                        ])),
                  Switch(
                    value: _hours[d] != null,
                    onChanged: (on) => setState(() => _hours[d] = on ? ['08:00', '18:00'] : null),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        label('market_clients_at_once'.tr),
        Row(children: [
          IconButton.outlined(onPressed: _capacity > 1 ? () => setState(() => _capacity--) : null, icon: const Icon(Icons.remove_rounded)),
          SizedBox(width: 44, child: Text('$_capacity', textAlign: TextAlign.center, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor))),
          IconButton.outlined(onPressed: _capacity < 20 ? () => setState(() => _capacity++) : null, icon: const Icon(Icons.add_rounded)),
          const SizedBox(width: 10),
          Expanded(child: Text('market_clients_at_once_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
        ]),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        label('market_notice'.tr),
        chips<int>([(0, 'market_notice_none'.tr), (60, '1 h'), (120, '2 h'), (240, '4 h'), (1440, 'market_one_day'.tr)], _notice, (v) => _notice = v),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        label('market_ahead'.tr),
        chips<int>([(7, 'market_one_week'.tr), (14, 'market_two_weeks'.tr), (30, 'market_one_month'.tr)], _ahead, (v) => _ahead = v),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        SwitchListTile(
          value: _confirmMyself,
          onChanged: (v) => setState(() => _confirmMyself = v),
          contentPadding: EdgeInsets.zero,
          title: Text('market_confirm_myself'.tr, style: textSemiBold.copyWith(color: textColor)),
          subtitle: Text((_confirmMyself ? 'market_confirm_myself_on' : 'market_confirm_myself_off').tr,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ),
        SwitchListTile(
          value: _taking,
          onChanged: (v) => setState(() => _taking = v),
          contentPadding: EdgeInsets.zero,
          title: Text('market_taking_bookings'.tr, style: textSemiBold.copyWith(color: textColor)),
          subtitle: Text('market_taking_bookings_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ),
        const SizedBox(height: 8),
        label('market_areas'.tr),
        TextField(controller: _areas, maxLength: 300, textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: 'market_areas_hint'.tr, isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)))),
        label('market_travel_fee'.tr),
        TextField(controller: _travelFee, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
            decoration: InputDecoration(hintText: 'market_travel_fee_hint'.tr, suffixText: 'FCFA', isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)))),
        const SizedBox(height: 90),
      ]),
      bottomNavigationBar: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 8, Dimensions.paddingSizeLarge, 12),
        child: GetBuilder<MarketBookingController>(builder: (c) => SizedBox(height: 52, child: FilledButton(
          onPressed: c.acting ? null : _save,
          child: c.acting
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text((widget.postedService != null ? 'market_post_my_service' : 'market_save').tr,
                  style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
        ))),
      )),
    );
  }
}
