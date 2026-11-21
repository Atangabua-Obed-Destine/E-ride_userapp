import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/bus/controllers/bus_controller.dart';
import 'package:ride_sharing_user_app/features/bus/domain/models/bus_models.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_booking_screen.dart';
import 'package:ride_sharing_user_app/features/bus/widgets/bus_widgets.dart';
import 'package:ride_sharing_user_app/features/id_verification/controllers/id_verification_controller.dart';
import 'package:ride_sharing_user_app/features/id_verification/domain/models/id_verification_model.dart';
import 'package:ride_sharing_user_app/features/id_verification/screens/id_verification_screen.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Who sits where: a name for each seat (and bags), where they get off. Only the person booking gives an ID,
/// even for others, as the agency asks: E-Ride ID Verified, an ID sent to E-Ride, or just the number.
/// People travelled with before are one tap away. Then the request goes to the agency.
class BusTravellersScreen extends StatefulWidget {
  final String departureId;
  const BusTravellersScreen({super.key, required this.departureId});

  @override
  State<BusTravellersScreen> createState() => _BusTravellersScreenState();
}

class _Traveller {
  final TextEditingController name = TextEditingController();
  final TextEditingController phone = TextEditingController();
  int? bags;

  void fill(Map<String, dynamic> p) {
    name.text = '${p['name'] ?? ''}';
    phone.text = '${p['phone'] ?? ''}';
  }

  Map<String, dynamic> toJson() => {
        'name': name.text.trim(),
        if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
      };

  void dispose() {
    name.dispose();
    phone.dispose();
  }
}

class _BusTravellersScreenState extends State<BusTravellersScreen> {
  static const String _recentKey = 'bus_recent_travellers';
  BusController get _c => Get.find<BusController>();
  final _form = GlobalKey<FormState>();
  final Map<String, _Traveller> _people = {};
  final TextEditingController _bookerId = TextEditingController();
  List<Map<String, dynamic>> _recent = [];
  String? _drop;

  @override
  void initState() {
    super.initState();
    for (final s in _c.picked) {
      _people[s] = _Traveller();
    }
    final prefs = Get.find<SharedPreferences>();
    try {
      _recent = (jsonDecode(prefs.getString(_recentKey) ?? '[]') as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
    // The first seat is usually the person booking.
    final me = _me();
    if (me != null && _people.isNotEmpty) _people.values.first.fill(me);
    final d = _c.departure(widget.departureId);
    _drop = d?.dropPoints.isNotEmpty == true ? d!.dropPoints.last.id : null;
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<IdVerificationController>().load());
  }

  Map<String, dynamic>? _me() {
    final p = Get.find<ProfileController>().profileModel?.data;
    if (p == null) return null;
    final name = '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
    return name.isEmpty ? null : {'name': name, 'phone': p.phone};
  }

  @override
  void dispose() {
    for (final t in _people.values) {
      t.dispose();
    }
    _bookerId.dispose();
    super.dispose();
  }

  Future<void> _remember(List<Map<String, dynamic>> sent) async {
    final meName = _me()?['name'];
    final merged = <Map<String, dynamic>>[
      for (final p in sent) {...p, if (p['name'] == meName) 'me': true},
      ..._recent.where((r) => !sent.any((p) => '${p['name']}'.toLowerCase() == '${r['name']}'.toLowerCase())),
    ];
    await Get.find<SharedPreferences>().setString(_recentKey, jsonEncode(merged.take(8).toList()));
  }

  double _total(BusDeparture d) {
    final fare = d.dropPoints.where((p) => p.id == _drop).firstOrNull?.fare ?? d.fromFare ?? 0;
    final r = d.rules;
    return _people.values.fold(0.0, (sum, t) => sum + fare + ((t.bags ?? r.freeBags) - r.freeBags).clamp(0, 9) * r.extraBagFee);
  }

  /// Can the request go: the agency's ID rule is met.
  bool _idReady(BusRules rules, IdVerificationStatus? id) {
    if (rules.idCheck == 'number') return id?.usable == true || _bookerId.text.trim().length >= 5;
    return id?.usable == true;
  }

  Future<void> _send(BusDeparture d) async {
    if (!_form.currentState!.validate() || _drop == null) return;
    final id = Get.find<IdVerificationController>().status;
    final passengers = _c.picked.map((s) => {..._people[s]!.toJson(), 'bags': _people[s]!.bags ?? d.rules.freeBags}).toList();
    final b = await _c.requestSeats(d.id, {
      'seats': _c.picked.toList(),
      'drop_point_id': _drop,
      'passengers': passengers,
      if (d.rules.idCheck == 'number' && id?.usable != true) 'booker_id_number': _bookerId.text.trim(),
    });
    if (b != null) {
      await _remember(passengers.map((p) => Map<String, dynamic>.from(p)..remove('bags')).toList());
      Get.until((route) => route.isFirst || route.settings.name == '/BusHomeScreen');
      Get.to(() => BusBookingScreen(bookingId: b.id));
    }
  }

  Future<void> _addId() async {
    await Get.to(() => const IdVerificationScreen());
    await Get.find<IdVerificationController>().load();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final d = _c.departure(widget.departureId);
    if (d == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final agency = d.agency?.name ?? '';
    final seats = _c.picked.join(', ');
    final free = d.rules.freeCancelHours;
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('bus_who_travels'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
          Text('$agency · ${busWhen(d.leavesAt)}', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ]),
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
          for (final s in _c.picked) _seatCard(context, d, s),
          GetBuilder<IdVerificationController>(builder: (ids) => _BookerIdCard(rules: d.rules, agency: agency, id: ids.status, loading: ids.loading,
              typed: _bookerId, onAdd: _addId, onTyped: () => setState(() {}))),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _drop,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'bus_get_off_at'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            items: d.dropPoints.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} · ${busMoney(p.fare)}', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _drop = v),
            validator: (v) => v == null ? 'bus_choose_drop'.tr : null,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('bus_seats_picked'.trParams({'seats': seats}), style: textMedium.copyWith(color: textColor))),
                Text(busMoney(_total(d)), style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
              ]),
              const SizedBox(height: 8),
              Text(d.instant ? 'bus_instant_explain'.trParams({'n': '${_c.meta?.payMinutes ?? 15}'})
                  : 'bus_ask_explain'.trParams({'agency': agency, 'n': '${_c.meta?.payMinutes ?? 15}'}),
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              if (d.rules.tickets == 'collect')
                Text('bus_collect_explain'.trParams({'agency': agency}), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              if (free != null && free > 0)
                Text('bus_free_cancel_until_long'.trParams({'h': '$free'}), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ]),
          ),
          const SizedBox(height: 90),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: GetBuilder<IdVerificationController>(builder: (ids) => GetBuilder<BusController>(builder: (c) {
            final ready = _idReady(d.rules, ids.status);
            return SizedBox(height: 52, child: ElevatedButton(
              onPressed: c.sending || !ready ? null : () => _send(d),
              style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: c.sending
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(!ready ? 'bus_id_first'.tr : d.instant ? 'bus_hold_seats'.tr : 'bus_ask_agency'.trParams({'agency': agency, 'seats': seats}),
                      textAlign: TextAlign.center, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault)),
            ));
          })),
        ),
      ),
    );
  }

  Widget _seatCard(BuildContext context, BusDeparture d, String seat) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final t = _people[seat]!;
    final rules = d.rules;
    final cell = d.seatMap?.seat(seat);
    final me = _me();
    final suggestions = [if (me != null) {...me, 'me': true}, ..._recent.where((r) => r['me'] != true)]
        .where((p) => !_people.values.any((o) => o != t && o.name.text.trim().toLowerCase() == '${p['name']}'.toLowerCase())).take(4).toList();
    InputDecoration deco(String label) => InputDecoration(labelText: label, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));
    final bags = t.bags ?? rules.freeBags;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 38, alignment: Alignment.center,
              decoration: BoxDecoration(color: busSeatMine, borderRadius: BorderRadius.circular(9)),
              child: Text(seat, style: textBold.copyWith(color: Colors.white))),
          const SizedBox(width: 10),
          Text('${'bus_seat'.tr} $seat${cell?.window == true ? ' · ${'bus_window'.tr}' : ''}', style: textBold.copyWith(color: textColor)),
        ]),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in suggestions)
              ActionChip(
                label: Text(p['me'] == true ? 'bus_me'.tr : '${p['name']}'),
                avatar: Icon(p['me'] == true ? Icons.person_rounded : Icons.history_rounded, size: 16),
                onPressed: () => setState(() => t.fill(p)),
              ),
          ]),
        ],
        const SizedBox(height: 10),
        TextFormField(controller: t.name, decoration: deco('bus_full_name_short'.tr), textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next,
            validator: (v) => (v ?? '').trim().length < 2 ? 'bus_name_needed'.tr : null),
        const SizedBox(height: 10),
        TextFormField(controller: t.phone, decoration: deco('bus_phone_optional'.tr), keyboardType: TextInputType.phone, textInputAction: TextInputAction.next),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('bus_bags'.tr, style: textSemiBold.copyWith(color: textColor)),
            Text(rules.extraBagFee > 0
                ? 'bus_bags_rule'.trParams({'n': '${rules.freeBags}', 'kg': '${rules.bagKg}', 'fee': busMoney(rules.extraBagFee)})
                : 'bus_bags_rule_free'.trParams({'n': '${rules.freeBags}', 'kg': '${rules.bagKg}'}),
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ])),
          IconButton(tooltip: 'bus_less_bags'.tr, onPressed: bags > 0 ? () => setState(() => t.bags = bags - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
          Text('$bags', style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
          IconButton(tooltip: 'bus_more_bags'.tr, onPressed: bags < 5 ? () => setState(() => t.bags = bags + 1) : null, icon: const Icon(Icons.add_circle_outline)),
        ]),
      ]),
    );
  }
}

/// The booker's ID, as this agency wants it.
class _BookerIdCard extends StatelessWidget {
  final BusRules rules;
  final String agency;
  final IdVerificationStatus? id;
  final bool loading;
  final TextEditingController typed;
  final VoidCallback onAdd;
  final VoidCallback onTyped;
  const _BookerIdCard({required this.rules, required this.agency, required this.id, required this.loading, required this.typed, required this.onAdd, required this.onTyped});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    const green = Color(0xFF15803D);
    final orange = Colors.orange.shade800;
    final docLabel = id?.docType == 'passport' ? 'id_passport'.tr : 'id_card'.tr;

    late final Color color;
    late final IconData icon;
    late final String title;
    late final String body;
    Widget? action;
    if (loading && id == null) {
      return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
    } else if (id?.verified == true) {
      color = green;
      icon = Icons.verified_rounded;
      title = 'bus_id_verified'.tr;
      body = '$docLabel ${id!.maskedNumber ?? ''}. ${rules.idCheck == 'agents' ? 'bus_id_agents_look'.trParams({'agency': agency}) : 'bus_id_trusted'.tr}';
    } else if (id?.pending == true) {
      color = orange;
      icon = Icons.hourglass_bottom_rounded;
      title = 'bus_id_pending'.tr;
      body = rules.idCheck == 'number' ? '$docLabel ${id!.maskedNumber ?? ''}.' : 'bus_id_pending_body'.trParams({'agency': agency});
    } else if (rules.idCheck == 'number') {
      color = theme.primaryColor;
      icon = Icons.badge_outlined;
      title = 'bus_id_number_title'.tr;
      body = 'bus_id_number_body'.tr;
      action = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 10),
        TextFormField(
          controller: typed,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => onTyped(),
          decoration: InputDecoration(labelText: 'bus_your_id_number'.tr, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          validator: (v) => (v ?? '').trim().length < 5 ? 'id_number_needed'.tr : null,
        ),
        TextButton(onPressed: onAdd, child: Text('bus_id_verify_instead'.tr)),
      ]);
    } else {
      color = Colors.red.shade700;
      icon = Icons.badge_outlined;
      title = id?.refused == true ? 'id_refused_title'.tr : 'bus_id_needed_title'.tr;
      body = id?.refused == true ? (id!.refuseReason ?? '') : 'bus_id_needed_body'.trParams({'agency': agency});
      action = Padding(padding: const EdgeInsets.only(top: 10), child: ElevatedButton.icon(
        onPressed: onAdd, icon: const Icon(Icons.add_a_photo_outlined, size: 18), label: Text('bus_id_add'.tr),
        style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white),
      ));
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('bus_your_id'.tr.toUpperCase(), style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: textBold.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(body, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor)),
          ])),
        ]),
        if (action != null) action,
        const SizedBox(height: 6),
        Text('bus_id_only_booker'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
      ]),
    );
  }
}
