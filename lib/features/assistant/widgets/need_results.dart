import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/assistant/controllers/assistant_controller.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/models/assistant_models.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/need_finder.dart';
import 'package:ride_sharing_user_app/features/assistant/screens/assistant_screen.dart';
import 'package:ride_sharing_user_app/features/assistant/widgets/assistant_actions.dart';
import 'package:ride_sharing_user_app/features/bus/controllers/bus_controller.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_results_screen.dart';
import 'package:ride_sharing_user_app/features/explore/controllers/explore_controller.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_model.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_menu_screen.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The smart search: what the customer seems to need, above the address
/// results. "pharmacie" offers the pharmacies near them and a health ride;
/// "bus Douala demain" tomorrow's buses to Douala; "Romz" that restaurant.
/// Ask E-Ride closes the list when it looks like a question or a need.
class NeedResults extends StatelessWidget {
  final String text;
  const NeedResults({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AssistantController>() || text.trim().length < 2) return const SizedBox.shrink();
    final AssistantController assistant = Get.find<AssistantController>();
    final NeedFinder finder = assistant.needFinder();
    final List<NeedHit> hits = finder.find(text);
    final bool ask = assistant.enabled && (hits.isNotEmpty || finder.looksLikeQuestion(text));
    if (hits.isEmpty && !ask) return const SizedBox.shrink();

    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (final NeedHit hit in hits) _NeedRow(hit: hit, text: text),
      if (ask) _AskRow(text: text.trim()),
      Divider(height: 1, thickness: 1, color: Theme.of(context).hintColor.withValues(alpha: 0.12)),
    ]);
  }
}

class _NeedRow extends StatelessWidget {
  final NeedHit hit;
  final String text;
  const _NeedRow({required this.hit, required this.text});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color tint) = assistantActionStyle(hit.type, hit.id);
    final (String title, String subtitle) = _words();
    return _Row(
      icon: Icon(icon, size: 22, color: tint),
      background: tint.withValues(alpha: 0.12),
      title: title,
      subtitle: subtitle,
      onTap: () => _open(hit),
    );
  }

  (String, String) _words() {
    switch (hit.type) {
      case 'explore':
        final String name = Get.find<ExploreController>().categoryOf(hit.id ?? '')?.name ?? 'need_places'.tr;
        return ('need_near_you'.trParams({'name': name}), hit.id == 'pharmacy' ? 'need_pharmacy_sub'.tr : 'need_explore_sub'.tr);
      case 'bus' when hit.city != null:
        final String day = switch (hit.dayOffset) { 1 => 'need_tomorrow'.tr, 2 => 'need_after_tomorrow'.tr, _ => 'need_today'.tr };
        final String fare = hit.fare != null ? ' · ${'need_from_fare'.trParams({'fare': PriceConverter.convertPrice(hit.fare!)})}' : '';
        return ('need_bus_to'.trParams({'city': hit.city!}), '$day$fare');
      case 'store':
        return (hit.title ?? '', hit.open ? 'need_store_open'.tr : 'need_store_closed'.tr);
      case 'market' when hit.query != null:
        return ('need_market_query'.trParams({'q': hit.query!}), 'need_market_sub'.tr);
      case 'jobs' when hit.query != null:
        return ('need_jobs_query'.trParams({'q': hit.query!}), 'need_jobs_sub'.tr);
      default:
        return ('need_${hit.type}'.tr, 'need_${hit.type}_sub'.tr);
    }
  }

  static Future<void> _open(NeedHit hit) async {
    _closeSearch();
    switch (hit.type) {
      case 'bus' when hit.city != null:
        final BusController bus = Get.find<BusController>();
        final DateTime today = DateTime.now();
        bus.setFrom(hit.from);
        bus.setTo(hit.city);
        bus.setDate(today.add(Duration(days: hit.dayOffset ?? 0)));
        Get.to(() => const BusResultsScreen());
      case 'store':
        final StoreModel? store = Get.find<StoreController>().stores?.firstWhereOrNull((s) => s.id == hit.storeId);
        if (store == null) return;
        Get.find<StoreController>().openStore(store);
        Get.to(() => const StoreMenuScreen());
      default:
        await openAssistantAction(AssistantAction(type: hit.type, label: '', id: hit.query ?? hit.id));
    }
  }
}

class _AskRow extends StatelessWidget {
  final String text;
  const _AskRow({required this.text});

  @override
  Widget build(BuildContext context) {
    final Color brand = Theme.of(context).primaryColor;
    return _Row(
      icon: const Icon(Icons.auto_awesome_rounded, size: 20, color: Colors.white),
      background: brand,
      title: 'need_ask'.trParams({'q': text}),
      subtitle: 'need_ask_sub'.tr,
      highlight: brand.withValues(alpha: 0.05),
      onTap: () {
        _closeSearch();
        Get.to(() => AssistantScreen(question: text));
      },
    );
  }
}

class _Row extends StatelessWidget {
  final Widget icon;
  final Color background;
  final String title;
  final String subtitle;
  final Color? highlight;
  final VoidCallback onTap;
  const _Row({required this.icon, required this.background, required this.title, required this.subtitle, required this.onTap, this.highlight});

  @override
  Widget build(BuildContext context) {
    final Color? textColor = Theme.of(context).textTheme.bodyLarge?.color;
    return Material(
      color: highlight ?? Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: 10),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              margin: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
              decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
              child: Center(child: icon),
            ),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
              if (subtitle.isNotEmpty)
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
            ])),
            Icon(Icons.chevron_right_rounded, color: Theme.of(context).hintColor.withValues(alpha: 0.6)),
          ]),
        ),
      ),
    );
  }
}

/// Leaving the trip screen for another service: close the keyboard and the list.
void _closeSearch() {
  FocusManager.instance.primaryFocus?.unfocus();
  Get.find<LocationController>().setSearchResultShowHide(show: false);
}
