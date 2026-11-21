import 'package:ride_sharing_user_app/features/assistant/widgets/help_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_model.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// "Cooking at Romz Mile 6", why that branch, and a clear way to choose another.
class StoreBranchBanner extends StatelessWidget {
  final StoreController controller;
  const StoreBranchBanner({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final branch = controller.branch;
    final store = controller.store;
    if (branch == null || store == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color;
    final facts = [
      if (branch.distanceKm != null) '${branch.distanceKm!.toStringAsFixed(1)} km',
      if (branch.deliveryFee != null) 'delivery_fee_value'.trParams({'fee': PriceConverter.convertPrice(branch.deliveryFee!)}),
    ];
    // A passed-over branch or no open branch: the reason is the news, so it stands out.
    final warn = const ['preferred_closed', 'nearest_closed', 'all_closed'].contains(branch.reason);
    return Container(
      margin: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, 0),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.storefront_rounded, color: theme.primaryColor, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('cooking_at'.trParams({'branch': '${store.name ?? ''} ${branch.name}'}),
                style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
            if (controller.branchReason != null) ...[
              const SizedBox(height: 2),
              Text(controller.branchReason!, style: (warn ? textSemiBold : textRegular).copyWith(
                  fontSize: Dimensions.fontSizeSmall, color: warn ? const Color(0xFFB45309) : textColor)),
            ],
            if (facts.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(facts.join('  ·  '), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ],
          ])),
          const HelpButton(helpKey: 'food_branch', size: 18),
        ]),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Row(children: [
          Expanded(child: Text('brand_has_branches'.trParams({'brand': store.name ?? '', 'count': '${branch.count}'}),
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
          OutlinedButton.icon(
            onPressed: () => showStoreBranchSheet(context, controller),
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: Text('choose_a_branch'.tr),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.primaryColor,
              side: BorderSide(color: theme.primaryColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusOverLarge)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: textBold.copyWith(fontSize: Dimensions.fontSizeSmall),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Every branch, nearest first: distance, delivery fee, open or closed. Tap one to switch.
void showStoreBranchSheet(BuildContext context, StoreController controller) {
  controller.loadBranchOptions();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => GetBuilder<StoreController>(builder: (c) {
      final theme = Theme.of(context);
      final textColor = theme.textTheme.bodyMedium?.color;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('choose_a_branch'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('choose_a_branch_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ),
            if (c.branchesLoading) const LinearProgressIndicator(minHeight: 2),
            Flexible(child: ListView(shrinkWrap: true, children: [
              for (final b in c.branches) _BranchTile(branch: b, selected: b.id == c.branch?.id, onTap: () {
                Navigator.of(context).pop();
                if (b.id != c.branch?.id) c.chooseBranch(b.id);
              }),
            ])),
            const SizedBox(height: 8),
          ]),
        ),
      );
    }),
  );
}

class _BranchTile extends StatelessWidget {
  final StoreBranch branch;
  final bool selected;
  final VoidCallback onTap;
  const _BranchTile({required this.branch, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color;
    final usable = branch.openNow && branch.delivers;
    final String status;
    if (!branch.delivers) {
      status = 'branch_out_of_area'.tr;
    } else if (!branch.openNow) {
      status = branch.opensAt != null ? 'branch_closed_opens'.trParams({'time': branch.opensAt!}) : 'branch_closed'.tr;
    } else {
      status = [
        'open_now'.tr,
        if (branch.deliveryFee != null) 'delivery_fee_value'.trParams({'fee': PriceConverter.convertPrice(branch.deliveryFee!)}),
      ].join('  ·  ');
    }
    return InkWell(
      // A closed branch can still be picked to browse; ordering waits until it opens.
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(color: selected ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.2), width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(Icons.circle, size: 10, color: usable ? const Color(0xFF12A150) : theme.hintColor),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(branch.name, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: usable ? textColor : theme.hintColor)),
            if (branch.address != null && branch.address!.isNotEmpty)
              Text(branch.address!, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            const SizedBox(height: 2),
            Text(status, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall,
                color: usable ? const Color(0xFF12A150) : theme.hintColor)),
          ])),
          if (branch.distanceKm != null)
            Text('${branch.distanceKm!.toStringAsFixed(1)} km', style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          if (selected) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle_rounded, color: theme.primaryColor),
          ],
        ]),
      ),
    );
  }
}

/// Under a dish this branch can't serve now: "Available at Commercial Ave · 2.1 km   Switch".
class MenuElsewhereLine extends StatelessWidget {
  final MenuElsewhere elsewhere;
  final StoreController controller;
  const MenuElsewhereLine({super.key, required this.elsewhere, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const green = Color(0xFF12A150);
    final text = [
      'available_at_branch'.trParams({'branch': elsewhere.branchName}),
      if (elsewhere.distanceKm != null) '${elsewhere.distanceKm!.toStringAsFixed(1)} km',
      if (elsewhere.more > 0) 'and_more_branches'.trParams({'n': '${elsewhere.more}'}),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, size: 15, color: green),
        const SizedBox(width: 4),
        Flexible(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: green))),
        const SizedBox(width: 6),
        InkWell(
          borderRadius: BorderRadius.circular(Dimensions.radiusOverLarge),
          onTap: () => controller.chooseBranch(elsewhere.branchId),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.primaryColor,
              borderRadius: BorderRadius.circular(Dimensions.radiusOverLarge),
            ),
            child: Text('switch_branch'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}
