import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_item_form_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_start_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_sell_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_service_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// "Sell on E-Ride Market": something I own (a person, no shop needed), or a shop.
/// No conditions either way.
class MarketSellChoiceScreen extends StatelessWidget {
  const MarketSellChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Scaffold(
      backgroundColor: theme.cardColor,
      appBar: AppBar(backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent, title: Text('market_sell_on'.tr)),
      body: GetBuilder<MarketController>(builder: (market) {
        final reason = market.meta?.cannotOpenReason;
        final max = market.meta?.privateMaxItems ?? 10;
        return ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeLarge), children: [
          Text('market_sell_choice_intro'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.hintColor, height: 1.45)),
          const SizedBox(height: Dimensions.paddingSizeLarge),
          if (reason != null) ...[MarketScamNotice(text: reason), const SizedBox(height: Dimensions.paddingSizeDefault)],
          _Door(
            color: marketPrivateFg,
            background: marketPrivateBg,
            icon: Icons.sell_outlined,
            title: 'market_sell_own'.tr,
            subtitle: 'market_sell_own_sub'.tr,
            body: 'market_sell_own_body'.tr,
            tags: ['market_private_seller'.tr, 'market_up_to_items'.trParams({'count': '$max'}), 'market_place_private'.tr],
            strong: true,
            onTap: reason != null ? null : () => Get.off(() => const MarketItemFormScreen(privateSeller: true)),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          _Door(
            color: theme.primaryColor,
            background: theme.primaryColor.withValues(alpha: 0.08),
            icon: Icons.storefront_rounded,
            title: 'market_open_shop'.tr,
            subtitle: 'market_open_shop_sub'.tr,
            body: 'market_open_shop_body'.tr,
            tags: ['market_shop_tag'.tr, 'market_unlimited_items'.tr, 'market_on_the_map'.tr],
            onTap: reason != null ? null : () => Get.off(() => const MarketStartScreen()),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          _Door(
            color: marketServiceFg,
            background: marketServiceBg,
            icon: Icons.event_available_outlined,
            title: 'market_offer_service'.tr,
            subtitle: 'market_offer_service_sub'.tr,
            body: 'market_offer_service_body'.tr,
            tags: ['market_service'.tr, 'market_book_time'.tr, 'market_ask_quote'.tr],
            onTap: reason != null ? null : () => Get.off(() => const MarketItemFormScreen(service: true, privateSeller: true)),
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
            child: Text('market_grow_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor, height: 1.45)),
          ),
        ]);
      }),
    );
  }
}

class _Door extends StatelessWidget {
  final Color color;
  final Color background;
  final IconData icon;
  final String title;
  final String subtitle;
  final String body;
  final List<String> tags;
  final bool strong;
  final VoidCallback? onTap;
  const _Door({required this.color, required this.background, required this.icon, required this.title, required this.subtitle,
      required this.body, required this.tags, this.strong = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
              border: Border.all(color: strong ? color : theme.hintColor.withValues(alpha: 0.25), width: strong ? 2 : 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: background, shape: BoxShape.circle), child: Icon(icon, color: color)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
                Text(subtitle, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: color)),
              ])),
              Icon(Icons.chevron_right_rounded, color: color),
            ]),
            const SizedBox(height: 10),
            Text(body, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.45)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (int i = 0; i < tags.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: i == 0 ? background : theme.hintColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                  child: Text(tags[i], style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: i == 0 ? color : theme.hintColor)),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}
