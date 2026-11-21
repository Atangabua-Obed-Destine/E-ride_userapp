import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/features/listing/controllers/listing_controller.dart';
import 'package:ride_sharing_user_app/features/listing/domain/models/listing_model.dart';
import 'package:ride_sharing_user_app/features/listing/screens/listing_detail_screen.dart';
import 'package:ride_sharing_user_app/features/listing/screens/listing_form_screen.dart';
import 'package:ride_sharing_user_app/features/listing/screens/my_listings_screen.dart';
import 'package:ride_sharing_user_app/features/listing/screens/my_visits_screen.dart';
import 'package:ride_sharing_user_app/features/listing/widgets/listing_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Homes & spaces (Explore Bamenda): places to rent, verified and recently
/// confirmed first. Entry to listing one's own place, My listings and My visits.
class ListingHomeScreen extends StatefulWidget {
  final String? title;
  const ListingHomeScreen({super.key, this.title});

  @override
  State<ListingHomeScreen> createState() => _ListingHomeScreenState();
}

class _ListingHomeScreenState extends State<ListingHomeScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ListingController c = Get.find<ListingController>();
      c.loadMeta(force: true);
      c.search();
      c.loadVisits();
    });
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) Get.find<ListingController>().loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _listPlace() async {
    final ListingController c = Get.find<ListingController>();
    final ListingMeta? meta = await c.loadMeta(force: true);
    if (meta == null) return;
    if (meta.cannotListReason != null) {
      showCustomSnackBar(meta.cannotListReason!);
      return;
    }
    Get.to(() => const ListingFormScreen());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: GetBuilder<ListingController>(builder: (c) {
        return BodyWidget(
          appBar: AppBarWidget(title: widget.title ?? 'homes_and_spaces'.tr, showBackButton: true),
          body: RefreshIndicator(
            color: theme.primaryColor,
            onRefresh: () async {
              await c.search();
              c.loadVisits();
            },
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('listing_home_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
                    const SizedBox(height: 4),
                    Text('listing_home_subtitle'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                    const SizedBox(height: Dimensions.paddingSizeDefault),
                    Row(children: [
                      Expanded(child: _Action(icon: Icons.add_home_rounded, label: 'listing_list_your_place'.tr, primary: true, onTap: _listPlace)),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Expanded(child: _Action(icon: Icons.home_work_outlined, label: 'listing_my_listings'.tr,
                          badge: c.meta?.ownerAttention ?? 0,
                          onTap: () async {
                            await Get.to(() => const MyListingsScreen());
                            c.loadMeta(force: true);
                          })),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Expanded(child: _Action(icon: Icons.event_available_rounded, label: 'listing_my_visits'.tr,
                          badge: c.meta?.seekerAttention ?? c.myVisits.where((v) => v.status == 'proposed' || v.canRate).length,
                          onTap: () async {
                            await Get.to(() => const MyVisitsScreen());
                            c.loadMeta(force: true);
                          })),
                    ]),
                    const SizedBox(height: Dimensions.paddingSizeDefault),
                    _SafetyNote(),
                  ]),
                )),
                SliverToBoxAdapter(child: _FilterBar(controller: c)),

                if (c.loading && c.items.isEmpty)
                  const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())))
                else if (c.failed && c.items.isEmpty)
                  SliverFillRemaining(hasScrollBody: false, child: _Empty(
                    icon: Icons.wifi_off_rounded, title: 'listing_load_failed'.tr, action: 'try_again'.tr, onAction: c.search))
                else if (c.items.isEmpty)
                  SliverFillRemaining(hasScrollBody: false, child: _Empty(
                    icon: Icons.home_outlined,
                    title: c.filters.isEmpty ? 'listing_none_yet'.tr : 'listing_none_for_filters'.tr,
                    body: 'listing_alert_hint'.tr,
                    action: 'listing_alert_me'.tr,
                    onAction: c.saving ? null : c.alertForFilters,
                  ))
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                    sliver: SliverList.separated(
                      itemCount: c.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: Dimensions.paddingSizeDefault),
                      itemBuilder: (_, i) => ListingCard(
                        listing: c.items[i],
                        onTap: () => Get.to(() => ListingDetailScreen(listingId: c.items[i].id, initial: c.items[i])),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                    child: c.loadingMore
                        ? const Center(child: CircularProgressIndicator())
                        : TextButton.icon(
                            onPressed: c.saving ? null : c.alertForFilters,
                            icon: const Icon(Icons.notifications_active_outlined),
                            label: Text('listing_alert_me_more'.tr),
                          ),
                  )),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final int badge;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap, this.primary = false, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color fg = primary ? Colors.white : theme.textTheme.bodyLarge!.color!;
    return Material(
      color: primary ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(children: [
            Badge(isLabelVisible: badge > 0, label: Text('$badge'), child: Icon(icon, color: fg)),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: fg)),
          ]),
        ),
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSize),
      decoration: BoxDecoration(color: listingVerifiedGreen.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.shield_outlined, color: listingVerifiedGreen, size: 20),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Expanded(child: Text('listing_never_pay_before_visit'.tr,
            style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color))),
      ]),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final ListingController controller;
  const _FilterBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ListingFilters f = controller.filters;
    final List<String> active = [
      if (f.type != null) ListingText.type(f.type!),
      if (f.neighbourhood != null) f.neighbourhood!,
      if (f.maxRent != null) '≤ ${f.maxRent!.round()}',
      if (f.verifiedOnly) 'listing_badge_verified'.tr,
      if (f.water) 'listing_has_water'.tr,
      if (f.backupPower) 'listing_has_backup_power'.tr,
      for (final a in f.amenities) ListingAmenity.label(a),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSize, Dimensions.paddingSizeDefault, Dimensions.paddingSize),
      child: Row(children: [
        Expanded(child: Text(
          active.isEmpty ? (controller.total == 1 ? 'listing_count_one'.tr : 'listing_count'.trParams({'count': '${controller.total}'})) : active.join(' · '),
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color),
        )),
        TextButton.icon(
          onPressed: () => ListingSheet.show(const ListingFilterSheet()),
          icon: Badge(isLabelVisible: active.isNotEmpty, smallSize: 8, child: const Icon(Icons.tune_rounded, size: 18)),
          label: Text('listing_filters'.tr),
        ),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String action;
  final VoidCallback? onAction;
  const _Empty({required this.icon, required this.title, required this.action, required this.onAction, this.body});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 56, color: theme.hintColor),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Text(title, textAlign: TextAlign.center, style: textMedium.copyWith(color: theme.textTheme.bodyMedium?.color)),
        if (body != null) ...[
          const SizedBox(height: 4),
          Text(body!, textAlign: TextAlign.center, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ],
        TextButton(onPressed: onAction, child: Text(action, style: textMedium.copyWith(color: theme.primaryColor))),
      ]),
    );
  }
}
