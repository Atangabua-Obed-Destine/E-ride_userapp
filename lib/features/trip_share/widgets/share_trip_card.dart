import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/trip_details_model.dart';
import 'package:ride_sharing_user_app/features/trip_checkin/controllers/trip_checkin_controller.dart';
import 'package:ride_sharing_user_app/features/trip_share/controllers/trip_share_controller.dart';
import 'package:ride_sharing_user_app/features/trip_share/domain/models/trusted_contact_model.dart';
import 'package:ride_sharing_user_app/features/trip_share/screens/trusted_contacts_screen.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// "Share your trip" in the trip sheet: one tap per trusted contact (WhatsApp),
/// any other app, or the link. For a parcel: let the receiver follow it.
class ShareTripCard extends StatefulWidget {
  final EdgeInsets margin;
  const ShareTripCard({super.key, this.margin = const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeSmall)});

  @override
  State<ShareTripCard> createState() => _ShareTripCardState();
}

class _ShareTripCardState extends State<ShareTripCard> {
  @override
  void initState() {
    super.initState();
    // After the first frame: the loads notify GetBuilders, which cannot rebuild mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final TripDetails? trip = Get.find<RideController>().tripDetails;
      if (!mounted || !TripShareController.canShare(trip)) return;
      final TripShareController share = Get.find<TripShareController>();
      share.getContacts();
      share.prepare(trip!);
      // Night hours, for the "it is night" nudge (fetched each time: night can start mid-ride).
      Get.find<TripCheckinController>().loadInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideController>(builder: (rideController) {
      final TripDetails? trip = rideController.tripDetails;
      if (!TripShareController.canShare(trip)) return const SizedBox();
      return GetBuilder<TripShareController>(builder: (share) {
        final ThemeData theme = Theme.of(context);
        final bool parcel = share.isParcel(trip!);
        final List<TrustedContact> contacts = share.contacts ?? [];
        return Container(
          margin: widget.margin,
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.share_location_rounded, color: theme.primaryColor, size: 22),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(parcel ? 'trip_share_parcel_title'.tr : 'share_your_trip'.tr,
                    style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault)),
                const SizedBox(height: 2),
                Text(parcel ? 'trip_share_parcel_hint'.tr : 'trip_share_hint'.tr,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.3)),
              ])),
              if (share.loadingLink)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else if (share.shared)
                _LivePill(),
            ]),
            if (!parcel && !share.shared && contacts.isNotEmpty)
              GetBuilder<TripCheckinController>(builder: (checkin) => !checkin.isNight ? const SizedBox() : Padding(
                padding: const EdgeInsets.only(top: Dimensions.paddingSizeSmall),
                child: Row(children: [
                  Icon(Icons.nightlight_round, size: 16, color: theme.primaryColor),
                  const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                  Expanded(child: Text('night_share_card_hint'.tr,
                      style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor))),
                ]),
              )),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Wrap(spacing: Dimensions.paddingSizeExtraSmall, runSpacing: Dimensions.paddingSizeExtraSmall, children: [
              if (parcel && (share.receiverPhone ?? '').isNotEmpty)
                _ShareChip(
                  icon: Icons.chat_rounded, filled: true,
                  label: 'trip_share_to_receiver'.trParams({'name': _first(share.receiverName) ?? 'receiver'.tr}),
                  onTap: () => share.shareTo(trip, share.receiverPhone!),
                ),
              if (!parcel) ...[
                for (final TrustedContact contact in contacts)
                  _ShareChip(icon: Icons.chat_rounded, filled: true, label: contact.name, onTap: () => share.shareTo(trip, contact.phone)),
                if (share.contacts != null && contacts.isEmpty)
                  _ShareChip(icon: Icons.person_add_alt_1_rounded, label: 'add_trusted_contacts'.tr, onTap: () => Get.to(() => const TrustedContactsScreen())),
              ],
              _ShareChip(icon: Icons.ios_share_rounded, label: 'share_other_app'.tr, onTap: () => share.shareOther(trip)),
              _ShareChip(icon: Icons.link_rounded, label: 'copy_link'.tr, onTap: () => share.copyLink(trip)),
            ]),
            if (share.shared)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: share.stopping ? null : () => _confirmStop(context, share, trip),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall), minimumSize: const Size(0, 34)),
                  child: Text('stop_sharing'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.colorScheme.error)),
                ),
              ),
          ]),
        );
      });
    });
  }

  static String? _first(String? name) {
    final String n = (name ?? '').trim();
    return n.isEmpty ? null : n.split(' ').first;
  }

  Future<void> _confirmStop(BuildContext context, TripShareController share, TripDetails trip) async {
    final ThemeData theme = Theme.of(context);
    final bool? yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('stop_sharing_title'.tr),
      content: Text('stop_sharing_body'.tr),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('keep_sharing'.tr)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('stop_sharing'.tr),
        ),
      ],
    ));
    if (yes == true) share.stopSharing(trip);
  }
}

class _LivePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const Color green = Color(0xFF12A150);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: const BoxDecoration(color: green, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('trip_share_live'.tr, style: textSemiBold.copyWith(fontSize: 11, color: green)),
      ]),
    );
  }
}

class _ShareChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  const _ShareChip({required this.icon, required this.label, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color fg = filled ? Colors.white : theme.primaryColor;
    return Material(
      color: filled ? theme.primaryColor : theme.cardColor,
      shape: StadiumBorder(side: BorderSide(color: theme.primaryColor.withValues(alpha: filled ? 1 : 0.35))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: fg)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The same, as a sheet from the share button on the map.
class ShareTripSheet extends StatelessWidget {
  const ShareTripSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(height: 5, width: 36, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          const ShareTripCard(margin: EdgeInsets.zero),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text('note_link_expire'.tr, textAlign: TextAlign.center,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ]),
      ),
    );
  }
}
