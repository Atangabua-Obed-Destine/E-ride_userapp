import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/bus/controllers/bus_controller.dart';
import 'package:ride_sharing_user_app/features/bus/domain/models/bus_models.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_results_screen.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_seats_screen.dart';
import 'package:ride_sharing_user_app/features/bus/widgets/bus_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_map_card.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:url_launcher/url_launcher.dart';

/// A bus agency verified by E-Ride: who they are, their rules (bags, refunds), where they go and for how
/// much, and the next departures.
class BusAgencyScreen extends StatefulWidget {
  final String agencyId;
  const BusAgencyScreen({super.key, required this.agencyId});

  @override
  State<BusAgencyScreen> createState() => _BusAgencyScreenState();
}

class _BusAgencyScreenState extends State<BusAgencyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<BusController>().loadAgency(widget.agencyId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<BusController>(builder: (c) {
      final page = c.agencyPage(widget.agencyId);
      final agency = page == null ? null : BusAgency.fromJson(page);
      final departures = page == null ? <BusDeparture>[] : ((page['departures'] as List?) ?? []).map((e) => BusDeparture.fromJson(Map<String, dynamic>.from(e))).toList();
      final destinations = page == null ? <Map>[] : ((page['destinations'] as List?) ?? []).whereType<Map>().toList();
      return Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
        appBar: AppBar(backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent, title: Text(agency?.name ?? '')),
        body: agency == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => c.loadAgency(widget.agencyId),
                child: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
                  Row(children: [
                    BusAgencyLogo(agency: agency, size: 60),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(agency.name, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor)),
                      const SizedBox(height: 4),
                      BusTag('bus_verified_by_eride'.tr, color: const Color(0xFF15803D), icon: Icons.verified_rounded),
                      if (agency.answerMinutes != null) ...[
                        const SizedBox(height: 4),
                        Text('bus_usually_answers'.trParams({'n': '${agency.answerMinutes}'}), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                      ],
                    ])),
                  ]),
                  if (agency.about != null) ...[
                    const SizedBox(height: 12),
                    Text(agency.about!, style: textRegular.copyWith(color: textColor)),
                  ],
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (agency.hasLocation)
                      ElevatedButton.icon(
                        onPressed: () => marketRideThere(agency.lat!, agency.lng!, [agency.name, if (agency.address != null) agency.address!].join(', ')),
                        icon: const Icon(Icons.local_taxi_outlined, size: 18), label: Text('bus_ride_to_agency'.tr),
                        style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white),
                      ),
                    if (agency.phone != null)
                      OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse('tel:${agency.phone}')), icon: const Icon(Icons.call_outlined, size: 18), label: Text('bus_call'.tr)),
                  ]),
                  if (agency.address != null) Padding(padding: const EdgeInsets.only(top: 6),
                      child: Text(agency.address!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
                  const SizedBox(height: 20),
                  if (departures.isNotEmpty) ...[
                    Text('bus_next_departures'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
                    const SizedBox(height: 10),
                    ...departures.take(6).map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: BusDepartureCard(departure: d, onTap: () => Get.to(() => BusSeatsScreen(departureId: d.id))),
                        )),
                  ],
                  if (destinations.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('bus_where_they_go'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
                    const SizedBox(height: 8),
                    ...destinations.map((d) => _Destination(data: Map<String, dynamic>.from(d), onSearch: () {
                          c.setFrom(agency.originCity);
                          c.setTo('${d['city']}');
                          Get.to(() => const BusResultsScreen());
                        })),
                  ],
                  if (agency.rules != null) ...[
                    const SizedBox(height: 14),
                    _Rules(rules: agency.rules!, agency: agency.name),
                  ],
                ]),
              ),
      );
    });
  }
}

class _Destination extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onSearch;
  const _Destination({required this.data, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = ((data['drop_points'] as List?) ?? []).whereType<Map>().toList();
    return Card(
      elevation: 0,
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        shape: const Border(),
        title: Text('${data['city']}', style: textBold.copyWith(color: theme.textTheme.bodyLarge?.color)),
        subtitle: data['duration_minutes'] != null ? Text(busDuration(int.tryParse('${data['duration_minutes']}'))) : null,
        children: [
          for (final p in points)
            ListTile(
              dense: true,
              title: Text('${p['name']}'),
              trailing: Text(((p['fares'] as Map?) ?? {}).entries.map((e) => '${'bus_class_${e.key}'.tr} ${busMoney(double.tryParse('${e.value}'))}').join('\n'),
                  textAlign: TextAlign.right, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall)),
            ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Align(alignment: Alignment.centerRight, child: TextButton(onPressed: onSearch, child: Text('bus_see_departures'.tr)))),
        ],
      ),
    );
  }
}

class _Rules extends StatelessWidget {
  final BusRules rules;
  final String agency;
  const _Rules({required this.rules, required this.agency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = theme.hintColor;
    final tiers = rules.cancelTiers;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('bus_rules_title'.tr, style: textBold.copyWith(color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 8),
        Text(rules.extraBagFee > 0
            ? 'bus_bags_rule'.trParams({'n': '${rules.freeBags}', 'kg': '${rules.bagKg}', 'fee': busMoney(rules.extraBagFee)})
            : 'bus_bags_rule_free'.trParams({'n': '${rules.freeBags}', 'kg': '${rules.bagKg}'}), style: textRegular.copyWith(color: hint)),
        const SizedBox(height: 6),
        for (final t in tiers)
          Text(t[0] > 0 ? 'bus_tier'.trParams({'h': '${t[0]}', 'pct': '${t[1]}'}) : 'bus_tier_last'.trParams({'pct': '${t[1]}'}), style: textRegular.copyWith(color: hint)),
        const SizedBox(height: 6),
        Text('bus_refund_by_agency'.trParams({'agency': agency}), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: hint)),
        if (rules.requireId) Text('bus_id_required'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: hint)),
      ]),
    );
  }
}
