import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/call_options_sheet.dart';
import 'package:ride_sharing_user_app/features/listing/controllers/listing_controller.dart';
import 'package:ride_sharing_user_app/features/listing/domain/models/listing_model.dart';
import 'package:ride_sharing_user_app/features/listing/screens/listing_detail_screen.dart';
import 'package:ride_sharing_user_app/features/listing/screens/listing_form_screen.dart';
import 'package:ride_sharing_user_app/features/listing/widgets/listing_widgets.dart';
import 'package:ride_sharing_user_app/features/listing/widgets/reservation_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The owner's side: each listing with its status and the one-tap answers the
/// policy asks for (still available, rented), and the visits seekers asked for.
class MyListingsScreen extends StatefulWidget {
  final int initialTab;
  const MyListingsScreen({super.key, this.initialTab = 0});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final ListingController c = Get.find<ListingController>();
    c.loadMeta();
    await Future.wait([c.loadMine(), c.loadVisits()]);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        body: GetBuilder<ListingController>(builder: (c) {
          final int pending = c.visitsToMyPlaces.where((v) => v.status == 'requested' || (v.taking && v.listing?.status == 'live') || (v.reservation?.isHeld ?? false)).length;
          return BodyWidget(
            appBar: AppBarWidget(title: 'listing_my_listings'.tr, showBackButton: true),
            body: Column(children: [
              TabBar(tabs: [
                Tab(text: 'listing_my_places'.tr),
                Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: Text('listing_visit_requests'.tr, overflow: TextOverflow.ellipsis)),
                  if (pending > 0) ...[const SizedBox(width: 6), Badge(label: Text('$pending'))],
                ])),
              ]),
              Expanded(child: TabBarView(children: [
                RefreshIndicator(onRefresh: _refresh, child: _Places(controller: c)),
                RefreshIndicator(onRefresh: _refresh, child: _Requests(controller: c)),
              ])),
            ]),
          );
        }),
      ),
    );
  }
}

class _Places extends StatelessWidget {
  final ListingController controller;
  const _Places({required this.controller});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (controller.mineLoading) return const Center(child: CircularProgressIndicator());
    if (controller.mine.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 80),
        Icon(Icons.home_work_outlined, size: 56, color: theme.hintColor),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Text('listing_no_places_yet'.tr, textAlign: TextAlign.center, style: textMedium.copyWith(color: theme.hintColor)),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      itemCount: controller.mine.length,
      separatorBuilder: (_, __) => const SizedBox(height: Dimensions.paddingSizeDefault),
      itemBuilder: (_, i) => _PlaceCard(listing: controller.mine[i], controller: controller),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final Listing listing;
  final ListingController controller;
  const _PlaceCard({required this.listing, required this.controller});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Listing l = listing;
    final bool busy = controller.busyId == l.id;
    final Color statusColor = switch (l.status) {
      'live' => listingVerifiedGreen,
      'pending' || 'changes' => listingAmber,
      'paused' || 'refused' || 'removed' => theme.colorScheme.error,
      _ => theme.hintColor,
    };
    return Container(
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          onTap: () => Get.to(() => ListingDetailScreen(listingId: l.id, initial: l)),
          child: Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSize),
            child: Row(children: [
              SizedBox(width: 72, height: 72, child: ListingPhotoBox(url: l.cover)),
              const SizedBox(width: Dimensions.paddingSize),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: textBold.copyWith(color: theme.textTheme.bodyLarge?.color)),
                Text('${ListingText.type(l.type)} · ${l.neighbourhood}', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(ListingText.status(l.status), style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: statusColor)),
                  ),
                  if (l.isLive) ListingBadge(listing: l, compact: true),
                ]),
              ])),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Dimensions.paddingSize, 0, Dimensions.paddingSize, Dimensions.paddingSize),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((l.reviewNote ?? '').isNotEmpty && l.status != 'live' && l.status != 'pending')
              _Note(color: listingAmber, text: '${'listing_eride_says'.tr}: ${l.reviewNote}'),
            if (l.status == 'pending') _Note(color: theme.hintColor, text: 'listing_pending_note'.tr),
            if (l.takenCheckUntil != null) _Note(color: theme.colorScheme.error, text: 'listing_taken_check_note'.tr),
            if (l.status == 'paused') _Note(color: theme.colorScheme.error, text: 'listing_paused_note'.tr),
            if (l.isLive && l.confirmDueAt != null)
              _Note(color: l.notConfirmedRecently ? listingAmber : theme.hintColor,
                  text: 'listing_next_confirm'.trParams({'date': ListingText.day(l.confirmDueAt)})),
            if (l.verificationStatus != null)
              _Note(color: listingVerifiedGreen, text: l.verificationScheduledFor != null
                  ? 'listing_visit_booked_on'.trParams({'date': ListingText.day(l.verificationScheduledFor)})
                  : 'listing_visit_requested_note'.tr),
            if (l.isLive)
              Padding(
                padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                child: Text('listing_stats'.trParams({'views': '${l.views}', 'visits': '${l.visitsCount}'}),
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
              ),
            if (busy) const LinearProgressIndicator(minHeight: 2),
            Wrap(spacing: Dimensions.paddingSizeSmall, runSpacing: Dimensions.paddingSizeSmall, children: [
              if (l.isOpen)
                FilledButton.icon(
                  onPressed: busy ? null : () => controller.confirm(l.id),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text('listing_still_available'.tr),
                ),
              if (l.isOpen)
                OutlinedButton(
                  onPressed: busy ? null : () async {
                    if (await listingConfirm('listing_mark_rented_q'.tr, 'listing_mark_rented_body'.tr, 'listing_its_rented'.tr)) {
                      controller.markRented(l.id);
                    }
                  },
                  child: Text('listing_its_rented'.tr),
                ),
              if (!['rented', 'removed'].contains(l.status))
                OutlinedButton(onPressed: () => Get.to(() => ListingFormScreen(listing: l)), child: Text('listing_edit'.tr)),
              if (l.isLive && !l.verified && l.verificationStatus == null)
                OutlinedButton.icon(
                  onPressed: busy ? null : () => controller.requestVerification(l.id),
                  icon: const Icon(Icons.verified_outlined, size: 18, color: listingVerifiedGreen),
                  label: Text('listing_get_verified'.tr),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Note extends StatelessWidget {
  final Color color;
  final String text;
  const _Note({required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: color))),
        ]),
      );
}

/// Visits seekers asked for, newest first: accept, propose, decline, or it is rented.
class _Requests extends StatelessWidget {
  final ListingController controller;
  const _Requests({required this.controller});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ListingVisit> visits = controller.visitsToMyPlaces;
    if (controller.visitsLoading) return const Center(child: CircularProgressIndicator());
    if (visits.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 80),
        Icon(Icons.event_busy_rounded, size: 56, color: theme.hintColor),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Text('listing_no_requests'.tr, textAlign: TextAlign.center, style: textMedium.copyWith(color: theme.hintColor)),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      itemCount: visits.length,
      separatorBuilder: (_, __) => const SizedBox(height: Dimensions.paddingSize),
      itemBuilder: (_, i) {
        final ListingVisit v = visits[i];
        final Listing? place = controller.mine.firstWhereOrNull((l) => l.id == v.listing?.id);
        // Only a place still on offer can be marked rented; once rented, the taker's visit says so.
        final bool onOffer = v.listing?.status == 'live' || v.listing?.status == 'paused';
        final bool rentedToThem = v.taking && v.listing?.status == 'rented';
        return Container(
          padding: const EdgeInsets.all(Dimensions.paddingSize),
          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.listing?.title ?? '', style: textBold.copyWith(color: theme.textTheme.bodyLarge?.color)),
            const SizedBox(height: 2),
            Text('${v.otherName} · ${ListingText.day(v.date)}, ${ListingText.window(v.window)}',
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            const SizedBox(height: 4),
            Text(rentedToThem ? 'listing_rented_to'.trParams({'name': v.otherName})
                : v.taking && onOffer ? 'listing_wants_to_take_it'.trParams({'name': v.otherName}) : ListingText.visitStatus(v.status),
                style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall,
                    color: rentedToThem || (v.taking && onOffer) ? listingVerifiedGreen : theme.textTheme.bodyMedium?.color)),
            if (v.status == 'proposed')
              Text('listing_you_proposed'.trParams({'when': '${ListingText.day(v.proposedDate)}, ${ListingText.window(v.proposedWindow ?? '')}'}),
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            if (v.reservation != null) ReservationPanel(visit: v),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Wrap(spacing: Dimensions.paddingSizeSmall, runSpacing: Dimensions.paddingSizeSmall, children: [
              if (v.status == 'requested') ...[
                FilledButton(onPressed: controller.saving ? null : () => controller.ownerRespond(v.id, 'accept'), child: Text('listing_accept'.tr)),
                OutlinedButton(
                  onPressed: place == null ? null : () => ListingSheet.show(BookVisitSheet(listing: place, propose: true, visitId: v.id)),
                  child: Text('listing_other_time'.tr),
                ),
                TextButton(onPressed: controller.saving ? null : () => controller.ownerRespond(v.id, 'decline'), child: Text('listing_decline'.tr)),
              ],
              if (v.otherPhone != null && (v.status == 'accepted' || v.status == 'done'))
                OutlinedButton.icon(onPressed: () => CallOptionsSheet.show(phone: v.otherPhone, name: v.otherName),
                    icon: const Icon(Icons.call_rounded, size: 18), label: Text('listing_call'.tr)),
              if (onOffer && (v.isOpen || v.taking) && (v.reservation == null || v.reservation!.isRefunded))
                TextButton(
                  onPressed: controller.saving ? null : () async {
                    if (await listingConfirm('listing_mark_rented_q'.tr, 'listing_mark_rented_body'.tr, 'listing_its_rented'.tr)) {
                      controller.ownerRespond(v.id, 'rented');
                    }
                  },
                  child: Text(v.taking ? 'listing_confirm_rented'.tr : 'listing_its_rented'.tr),
                ),
            ]),
          ]),
        );
      },
    );
  }
}
