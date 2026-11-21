import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_shop_form_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// "Sell on E-Ride Market": free, how it works, the rules, and agreeing to them.
class MarketStartScreen extends StatefulWidget {
  const MarketStartScreen({super.key});

  @override
  State<MarketStartScreen> createState() => _MarketStartScreenState();
}

class _MarketStartScreenState extends State<MarketStartScreen> {
  bool _agree = false;

  static const List<String> _rules = [
    'market_seller_rule_real',
    'market_seller_rule_banned',
    'market_seller_rule_app',
    'market_seller_rule_money',
    'market_seller_rule_digital',
    'market_seller_rule_reports',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<MarketController>(builder: (market) {
      final reason = market.meta?.cannotOpenReason;
      return Scaffold(
        backgroundColor: theme.cardColor,
        appBar: AppBar(backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent),
        body: ListView(padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 0, Dimensions.paddingSizeLarge, Dimensions.paddingSizeLarge), children: [
          Align(alignment: AlignmentDirectional.centerStart, child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Icon(Icons.storefront_rounded, color: theme.primaryColor, size: 34),
          )),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Text('market_start_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeOverLarge, color: textColor)),
          const SizedBox(height: 6),
          Text('market_start_body'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.hintColor, height: 1.45)),
          const SizedBox(height: Dimensions.paddingSizeLarge),
          for (final step in const [
            (Icons.add_business_outlined, 'market_how_open'),
            (Icons.add_a_photo_outlined, 'market_how_post'),
            (Icons.share_outlined, 'market_how_share'),
            (Icons.chat_bubble_outline_rounded, 'market_how_chat'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Icon(step.$1, size: 20, color: textColor),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(step.$2.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor))),
              ]),
            ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text('market_rules_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
          const SizedBox(height: 8),
          for (final r in _rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.check_circle_outline_rounded, size: 18, color: theme.primaryColor)),
                const SizedBox(width: 8),
                Expanded(child: Text(r.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor, height: 1.4))),
              ]),
            ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          if (reason != null)
            MarketScamNotice(text: reason)
          else
            CheckboxListTile(
              value: _agree,
              onChanged: (v) => setState(() => _agree = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('market_agree_rules'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
            ),
        ]),
        bottomNavigationBar: reason != null ? null : SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 8, Dimensions.paddingSizeLarge, 12),
          child: SizedBox(height: 52, child: FilledButton(
            onPressed: _agree ? () => Get.off(() => const MarketShopFormScreen()) : null,
            child: Text('market_open_my_shop'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
          )),
        )),
      );
    });
  }
}
