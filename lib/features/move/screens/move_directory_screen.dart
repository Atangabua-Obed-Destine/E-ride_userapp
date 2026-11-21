import 'package:ride_sharing_user_app/helper/image_size_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/features/move/controllers/move_controller.dart';
import 'package:ride_sharing_user_app/features/move/domain/models/move_listing_model.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/phone_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:url_launcher/url_launcher.dart';

/// Truck owners to call when no truck is available in the app. E-Ride lists
/// them; the job and the price are agreed between the customer and the owner.
class MoveDirectoryScreen extends StatefulWidget {
  final String? vehicleCategoryId;
  const MoveDirectoryScreen({super.key, this.vehicleCategoryId});

  @override
  State<MoveDirectoryScreen> createState() => _MoveDirectoryScreenState();
}

class _MoveDirectoryScreenState extends State<MoveDirectoryScreen> {
  static const Color _whatsAppGreen = Color(0xFF25D366);

  @override
  void initState() {
    super.initState();
    // After the first frame: the load notifies GetBuilders, which cannot rebuild mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<MoveController>().getDirectory(widget.vehicleCategoryId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BodyWidget(
        appBar: AppBarWidget(title: 'move_truck_owners'.tr, showBackButton: true),
        body: GetBuilder<MoveController>(builder: (move) {
          final List<MoveListing>? listings = move.directory;
          if (listings == null || (move.loadingDirectory && listings.isEmpty)) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () => move.getDirectory(widget.vehicleCategoryId),
            child: ListView(
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              children: [
                Text('move_directory_intro'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor, height: 1.4)),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                if (listings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Column(children: [
                      Image.asset(Images.moveTile, width: 120),
                      const SizedBox(height: Dimensions.paddingSizeSmall),
                      Text('move_directory_empty'.tr, textAlign: TextAlign.center, style: textMedium.copyWith(color: Theme.of(context).hintColor)),
                    ]),
                  ),
                for (final MoveListing listing in listings)
                  _ListingCard(
                    listing: listing,
                    matches: widget.vehicleCategoryId == null || listing.vehicleCategoryId == widget.vehicleCategoryId,
                    onCall: () => _call(move, listing),
                    onWhatsApp: () => _whatsApp(move, listing),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Future<void> _call(MoveController move, MoveListing listing) async {
    move.logContact(listing, 'call');
    await _open(Uri.parse('tel:${listing.phone}'));
  }

  Future<void> _whatsApp(MoveController move, MoveListing listing) async {
    final String digits = PhoneHelper.waDigits(listing.whatsapp);
    if (digits.isEmpty) return;
    move.logContact(listing, 'whatsapp');
    final String text = Uri.encodeComponent('move_whatsapp_message'.trParams({'name': listing.ownerName}));
    await _open(Uri.parse('https://wa.me/$digits?text=$text'));
  }

  Future<void> _open(Uri uri) async {
    try {
      final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) showCustomSnackBar('could_not_open_link'.tr);
    } catch (_) {
      showCustomSnackBar('could_not_open_link'.tr);
    }
  }
}

class _ListingCard extends StatelessWidget {
  final MoveListing listing;
  final bool matches;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  const _ListingCard({required this.listing, required this.matches, required this.onCall, required this.onWhatsApp});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(Dimensions.paddingSize),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.hintColor.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72, height: 56,
              child: listing.photo != null
                  ? CachedNetworkImage(imageUrl: listing.photo!, fit: BoxFit.cover,
                      memCacheWidth: ImageSizeHelper.decodeWidth(context, 72, 56),
                      errorWidget: (_, __, ___) => Image.asset(Images.moveTile, fit: BoxFit.contain))
                  : Container(color: theme.hintColor.withValues(alpha: 0.08), child: Image.asset(Images.moveTile, fit: BoxFit.contain)),
            ),
          ),
          const SizedBox(width: Dimensions.paddingSize),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(listing.ownerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
            const SizedBox(height: 2),
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (listing.vehicleName != null)
                Text(listing.vehicleName!, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: matches ? theme.primaryColor : theme.hintColor)),
              if (listing.onEride)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text('move_on_eride'.tr, style: textSemiBold.copyWith(fontSize: 10, color: theme.primaryColor)),
                ),
            ]),
            if (listing.areas != null) ...[
              const SizedBox(height: 2),
              Text(listing.areas!, maxLines: 2, overflow: TextOverflow.ellipsis, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ],
          ])),
        ]),
        if (listing.note != null) ...[
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(listing.note!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, height: 1.35)),
        ],
        const SizedBox(height: Dimensions.paddingSize),
        Row(children: [
          Expanded(child: FilledButton.icon(
            onPressed: onCall,
            icon: const Icon(Icons.call_rounded, size: 18),
            label: Text('call'.tr),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          )),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(child: FilledButton.icon(
            onPressed: onWhatsApp,
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: const Text('WhatsApp'),
            style: FilledButton.styleFrom(backgroundColor: _MoveDirectoryScreenState._whatsAppGreen, minimumSize: const Size.fromHeight(44)),
          )),
        ]),
      ]),
    );
  }
}
