import 'package:ride_sharing_user_app/helper/image_size_helper.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/call_options_sheet.dart';
import 'package:ride_sharing_user_app/features/lost_item/controllers/lost_item_controller.dart';
import 'package:ride_sharing_user_app/features/lost_item/domain/models/lost_item_model.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/trip_details_model.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// On the trip details of a completed ride: "I left something in the car", or the case once reported.
class LostItemSection extends StatefulWidget {
  final TripDetails trip;
  const LostItemSection({super.key, required this.trip});

  @override
  State<LostItemSection> createState() => _LostItemSectionState();
}

class _LostItemSectionState extends State<LostItemSection> {
  @override
  void initState() {
    super.initState();
    if (widget.trip.id != null && widget.trip.currentStatus == 'completed') {
      // After the first frame: the load notifies GetBuilders, which cannot rebuild mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<LostItemController>().loadForTrip(widget.trip.id!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LostItemController>(builder: (lost) {
      final String? tripId = widget.trip.id;
      if (tripId == null || !lost.enabled) return const SizedBox();
      final LostItem? item = lost.byTrip[tripId];
      if (item != null) return LostItemCard(item: item);
      if (!lost.byTrip.containsKey(tripId) || !lost.canReport(widget.trip)) return const SizedBox();
      return Padding(
        padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
        child: Center(child: TextButton.icon(
          onPressed: () => showLostItemSheet(tripId),
          icon: Icon(Icons.work_history_outlined, size: 18, color: Theme.of(context).primaryColor),
          label: Text('lost_item_left_something'.tr, style: textMedium.copyWith(color: Theme.of(context).primaryColor)),
        )),
      );
    });
  }
}

Future<void> showLostItemSheet(String tripId) {
  Get.find<LostItemController>().clearPhoto();
  return Get.bottomSheet(_LostItemSheet(tripId: tripId), isScrollControlled: true, backgroundColor: Theme.of(Get.context!).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Dimensions.radiusLarge))));
}

class _LostItemSheet extends StatefulWidget {
  final String tripId;
  const _LostItemSheet({required this.tripId});

  @override
  State<_LostItemSheet> createState() => _LostItemSheetState();
}

class _LostItemSheetState extends State<_LostItemSheet> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        child: GetBuilder<LostItemController>(builder: (lost) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Text('lost_item_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text('lost_item_intro'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          TextField(
            controller: _text,
            maxLines: 3,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'lost_item_hint'.tr,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          if (lost.photo != null)
            Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                child: Image.file(File(lost.photo!.path), height: 110, width: 110, fit: BoxFit.cover),
              ),
              Positioned(top: 4, right: 4, child: InkWell(
                onTap: lost.clearPhoto,
                child: const CircleAvatar(radius: 13, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 16, color: Colors.white)),
              )),
            ])
          else
            Row(children: [
              OutlinedButton.icon(onPressed: () => lost.pickPhoto(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: Text('camera'.tr)),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              OutlinedButton.icon(onPressed: () => lost.pickPhoto(ImageSource.gallery), icon: const Icon(Icons.photo_outlined), label: Text('gallery'.tr)),
            ]),
          Padding(
            padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
            child: Text('lost_item_photo_optional'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),
          lost.submitting
              ? const Center(child: CircularProgressIndicator())
              : ButtonWidget(buttonText: 'lost_item_send'.tr, onPressed: () async {
                  // The sheet's own navigator: Get.back() would close the success message instead.
                  final NavigatorState navigator = Navigator.of(context);
                  final bool sent = await lost.report(widget.tripId, _text.text);
                  if (sent && navigator.canPop()) navigator.pop();
                }),
        ])),
      )),
    );
  }
}

/// The case: where it stands, the photo, the driver's number once found, and what the rider can do.
class LostItemCard extends StatelessWidget {
  final LostItem item;
  const LostItemCard({super.key, required this.item});

  static Color statusColor(BuildContext context, LostItem item) => switch (item.status) {
    'found' => Colors.green,
    'returned' => Colors.green,
    'not_found' => Theme.of(context).colorScheme.error,
    'reported' => Colors.orange,
    _ => Theme.of(context).hintColor,
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = statusColor(context, item);
    return GetBuilder<LostItemController>(builder: (lost) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.work_history_outlined, color: color),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(child: Text('lost_item_title'.tr, style: textBold)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text('lost_status_${item.status}'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: color)),
          ),
        ]),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (item.photo != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              child: Image.network(item.photo!, width: 64, height: 64, fit: BoxFit.cover, cacheWidth: ImageSizeHelper.decodeWidth(context, 64, 64),
                  errorBuilder: (_, __, ___) => const SizedBox(width: 64, height: 64, child: Icon(Icons.image_not_supported_outlined))),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
          ],
          Expanded(child: Text('"${item.description}"', style: textMedium)),
        ]),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Text(item.message, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, height: 1.4)),
        if (item.driverNote != null) ...[
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text('${'lost_item_driver_says'.tr}: ${item.driverNote}', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ],
        if (item.otherPhone != null) ...[
          const SizedBox(height: Dimensions.paddingSizeSmall),
          InkWell(
            onTap: () => CallOptionsSheet.show(phone: item.otherPhone, name: item.otherName),
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            child: Container(
              padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
              child: Row(children: [
                const Icon(Icons.call_rounded, color: Colors.green),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('lost_item_call_driver'.trParams({'name': item.otherName}), style: textSemiBold),
                  Text([item.otherPhone, if (item.otherVehicle != null) item.otherVehicle].join('  ·  '),
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                ])),
              ]),
            ),
          ),
        ],
        if (item.needsSupport && item.supportPhone != null) ...[
          const SizedBox(height: Dimensions.paddingSizeSmall),
          InkWell(
            onTap: () => CallOptionsSheet.show(phone: item.supportPhone, name: item.supportName),
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            child: Container(
              padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
              decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
              child: Row(children: [
                Icon(Icons.support_agent_rounded, color: theme.primaryColor),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('lost_item_call_driver'.trParams({'name': item.supportName ?? 'E-Ride'}), style: textSemiBold),
                  Text(
                    '${item.supportOpenNow ? 'lost_item_support_open'.tr : 'lost_item_support_closed'.tr} (${item.supportHours ?? ''})',
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor),
                  ),
                ])),
              ]),
            ),
          ),
        ],
        if (item.can('collect') || item.can('deliver')) ...[
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Text('lost_item_how_back'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall)),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          _Choice(selected: item.returnMethod == 'collect', busy: lost.acting == 'collect', title: 'lost_item_collect'.tr,
              subtitle: 'lost_item_collect_sub'.tr, onTap: () => lost.act(item, 'collect')),
          _Choice(selected: item.returnMethod == 'deliver', busy: lost.acting == 'deliver', title: 'lost_item_deliver'.tr,
              subtitle: 'lost_item_deliver_sub'.trParams({'fee': PriceConverter.convertPrice(item.deliverFee)}), onTap: () => lost.act(item, 'deliver')),
        ],
        if (item.can('returned')) ...[
          const SizedBox(height: Dimensions.paddingSizeSmall),
          lost.acting == 'returned'
              ? const Center(child: CircularProgressIndicator())
              : ButtonWidget(buttonText: 'lost_item_have_it'.tr, onPressed: () => lost.act(item, 'returned')),
        ],
        if (item.can('support') || item.can('cancel'))
          Padding(
            padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
            child: Wrap(alignment: WrapAlignment.spaceBetween, children: [
              if (item.can('support'))
                TextButton(onPressed: lost.acting != null ? null : () => lost.act(item, 'support'), child: Text('lost_item_ask_support'.tr)),
              if (item.can('cancel'))
                TextButton(
                  onPressed: lost.acting != null ? null : () => _confirmCancel(context, lost, item),
                  child: Text('lost_item_close'.tr, style: TextStyle(color: theme.hintColor)),
                ),
            ]),
          ),
      ]),
    ));
  }

  void _confirmCancel(BuildContext context, LostItemController lost, LostItem item) {
    Get.dialog(AlertDialog(
      title: Text('lost_item_close'.tr),
      content: Text('lost_item_close_confirm'.tr),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text('no'.tr)),
        TextButton(onPressed: () {
          Get.back();
          lost.act(item, 'cancel');
        }, child: Text('yes'.tr)),
      ],
    ));
  }
}

class _Choice extends StatelessWidget {
  final bool selected;
  final bool busy;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Choice({required this.selected, required this.busy, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeExtraSmall),
      child: InkWell(
        onTap: selected || busy ? null : onTap,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        child: Container(
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            border: Border.all(color: selected ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.25), width: selected ? 1.5 : 1),
            color: selected ? theme.primaryColor.withValues(alpha: 0.06) : null,
          ),
          child: Row(children: [
            busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? theme.primaryColor : theme.hintColor),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: textSemiBold),
              Text(subtitle, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ])),
          ]),
        ),
      ),
    );
  }
}

