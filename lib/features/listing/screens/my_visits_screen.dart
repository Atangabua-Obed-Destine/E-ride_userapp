import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/call_options_sheet.dart';
import 'package:ride_sharing_user_app/features/listing/controllers/listing_controller.dart';
import 'package:ride_sharing_user_app/features/listing/domain/models/listing_model.dart';
import 'package:ride_sharing_user_app/features/listing/screens/listing_detail_screen.dart';
import 'package:ride_sharing_user_app/features/listing/widgets/listing_widgets.dart';
import 'package:ride_sharing_user_app/features/listing/widgets/reservation_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The seeker's visits: waiting, a new time to accept, the owner's number once
/// accepted, Ride there, how it went, and "I'm taking it".
class MyVisitsScreen extends StatefulWidget {
  const MyVisitsScreen({super.key});

  @override
  State<MyVisitsScreen> createState() => _MyVisitsScreenState();
}

class _MyVisitsScreenState extends State<MyVisitsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<ListingController>().loadVisits());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: GetBuilder<ListingController>(builder: (c) {
        final List<ListingVisit> visits = c.myVisits;
        return BodyWidget(
          appBar: AppBarWidget(title: 'listing_my_visits'.tr, showBackButton: true),
          body: RefreshIndicator(
            onRefresh: c.loadVisits,
            child: c.visitsLoading
                ? const Center(child: CircularProgressIndicator())
                : visits.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 80),
                        Icon(Icons.event_note_rounded, size: 56, color: theme.hintColor),
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                        Text('listing_no_visits'.tr, textAlign: TextAlign.center, style: textMedium.copyWith(color: theme.hintColor)),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                        itemCount: visits.length,
                        separatorBuilder: (_, __) => const SizedBox(height: Dimensions.paddingSize),
                        itemBuilder: (_, i) => _VisitCard(visit: visits[i], controller: c),
                      ),
          ),
        );
      }),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final ListingVisit visit;
  final ListingController controller;
  const _VisitCard({required this.visit, required this.controller});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ListingVisit v = visit;
    final ListingVisitPlace? place = v.listing;
    return Container(
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          onTap: place == null ? null : () => Get.to(() => ListingDetailScreen(listingId: place.id)),
          child: Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSize),
            child: Row(children: [
              SizedBox(width: 64, height: 64, child: ListingPhotoBox(url: place?.cover)),
              const SizedBox(width: Dimensions.paddingSize),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(place?.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: textBold.copyWith(color: theme.textTheme.bodyLarge?.color)),
                Text('${ListingText.day(v.date)}, ${ListingText.window(v.window)} · ${place?.neighbourhood ?? ''}',
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                const SizedBox(height: 4),
                v.taking && place?.status == 'rented'
                    ? Text('listing_its_yours'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: listingVerifiedGreen))
                    : Text(ListingText.visitStatus(v.status), style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: _statusColor(theme))),
              ])),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Dimensions.paddingSize, 0, Dimensions.paddingSize, Dimensions.paddingSize),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (v.status == 'proposed')
              Padding(
                padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                child: Text('listing_visit_proposed_to_you'.trParams({'when': '${ListingText.day(v.proposedDate)}, ${ListingText.window(v.proposedWindow ?? '')}'}),
                    style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
              ),
            if (v.otherPhone != null && (v.status == 'accepted' || v.status == 'done'))
              Padding(
                padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                child: Text('${v.otherName} · ${v.otherPhone}', style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
              ),
            if (v.reservation != null) ...[
              ReservationPanel(visit: v),
              const SizedBox(height: Dimensions.paddingSizeSmall),
            ],
            if (v.outcome != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                child: Text('${'listing_you_said'.tr}: ${'listing_outcome_${v.outcome}'.tr}',
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              ),
            Wrap(spacing: Dimensions.paddingSizeSmall, runSpacing: Dimensions.paddingSizeSmall, children: [
              if (v.status == 'proposed')
                FilledButton(onPressed: controller.saving ? null : () => controller.seekerRespond(v.id, 'accept_proposal'), child: Text('listing_accept_new_time'.tr)),
              if (v.status == 'accepted' && place != null)
                FilledButton.icon(
                  onPressed: controller.openingId != null ? null : () => controller.rideThere(
                    id: place.id, latitude: place.latitude, longitude: place.longitude, label: '${place.title}, ${place.neighbourhood}'),
                  icon: const Icon(Icons.local_taxi_rounded, size: 18),
                  label: Text('listing_ride_there'.tr),
                ),
              if (v.otherPhone != null && (v.status == 'accepted' || v.status == 'done'))
                OutlinedButton.icon(onPressed: () => CallOptionsSheet.show(phone: v.otherPhone, name: v.otherName),
                    icon: const Icon(Icons.call_rounded, size: 18), label: Text('listing_call'.tr)),
              if (v.canRate)
                OutlinedButton(onPressed: () => ListingSheet.show(VisitOutcomeSheet(visit: v)), child: Text('listing_how_was_visit'.tr)),
              if (v.canReserve && v.outcome != 'taken' && v.outcome != 'not_as_described')
                FilledButton.icon(
                  onPressed: () => ListingSheet.show(ReserveSheet(visitId: v.id)),
                  icon: const Icon(Icons.shield_rounded, size: 18),
                  label: Text('listing_reserve_with_eride'.tr),
                ),
              if ((v.status == 'accepted' || v.status == 'done') && !v.taking && place?.status == 'live' && v.outcome != 'taken' && v.outcome != 'not_as_described'
                  && place?.reservationAmount == null && (v.reservation == null || v.reservation!.isRefunded))
                OutlinedButton(
                  onPressed: controller.saving ? null : () async {
                    if (await listingConfirm('listing_taking_q'.tr, 'listing_taking_body'.tr, 'listing_im_taking_it'.tr)) {
                      controller.taking(v.id);
                    }
                  },
                  child: Text('listing_im_taking_it'.tr),
                ),
              if (v.taking && place?.status == 'live')
                Text('listing_waiting_owner_confirm'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: listingVerifiedGreen)),
              if (v.isOpen && !(v.taking && place?.status == 'rented') && (v.reservation == null || v.reservation!.isRefunded))
                TextButton(
                  onPressed: controller.saving ? null : () async {
                    if (await listingConfirm('listing_cancel_visit_q'.tr, 'listing_cancel_visit_body'.tr, 'listing_cancel_visit'.tr)) {
                      controller.seekerRespond(v.id, 'cancel');
                    }
                  },
                  child: Text('listing_cancel_visit'.tr),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Color _statusColor(ThemeData theme) => switch (visit.status) {
        'accepted' || 'done' => listingVerifiedGreen,
        'requested' || 'proposed' => listingAmber,
        _ => theme.hintColor,
      };
}
