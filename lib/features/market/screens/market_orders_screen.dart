import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_order_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_order_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_order_settings_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_order_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The buyer's orders ("buying") or the seller's order inbox ("selling"), by tab.
class MarketOrdersScreen extends StatefulWidget {
  final String role;
  final String? tab;
  const MarketOrdersScreen({super.key, this.role = 'buying', this.tab});

  @override
  State<MarketOrdersScreen> createState() => _MarketOrdersScreenState();
}

class _MarketOrdersScreenState extends State<MarketOrdersScreen> with SingleTickerProviderStateMixin {
  late final List<String> _tabs = widget.role == 'selling' ? const ['new', 'agree', 'confirmed', 'done'] : const ['active', 'done'];
  late final TabController _tab = TabController(length: _tabs.length, vsync: this, initialIndex: _tabs.contains(widget.tab) ? _tabs.indexOf(widget.tab!) : 0);

  bool get _selling => widget.role == 'selling';

  @override
  void initState() {
    super.initState();
    _tab.addListener(() {
      if (!_tab.indexIsChanging) _load();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      if (_selling) Get.find<MarketController>().loadMyShop();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() => Get.find<MarketOrderController>().loadList(widget.role, _tabs[_tab.index]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<MarketOrderController>(builder: (c) {
      String label(String t) {
        final base = 'market_tab_${widget.role}_$t'.tr;
        final n = t == 'new' ? c.sellingNew : (t == 'active' ? c.buyingOpen : 0);
        return n > 0 ? '$base ($n)' : base;
      }
      return Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
          title: Text((_selling ? 'market_shop_orders' : 'market_my_orders').tr),
          actions: [
            if (_selling)
              IconButton(tooltip: 'market_order_settings'.tr, icon: const Icon(Icons.tune_rounded),
                  onPressed: () => Get.to(() => const MarketOrderSettingsScreen())),
          ],
          bottom: TabBar(
            controller: _tab,
            isScrollable: _tabs.length > 2,
            tabAlignment: _tabs.length > 2 ? TabAlignment.start : null,
            labelColor: theme.primaryColor,
            unselectedLabelColor: theme.hintColor,
            indicatorColor: theme.primaryColor,
            tabs: [for (final t in _tabs) Tab(text: label(t))],
          ),
        ),
        body: Column(children: [
          if (_selling) const _TakingOrders(),
          Expanded(child: TabBarView(controller: _tab, children: [
            for (final t in _tabs)
              RefreshIndicator(
                onRefresh: () => c.loadList(widget.role, t),
                child: Builder(builder: (_) {
                  final list = c.list(widget.role, t);
                  if (c.isLoading(widget.role, t) && list.isEmpty) return const Center(child: CircularProgressIndicator());
                  if (list.isEmpty) {
                    return ListView(children: [
                      SizedBox(height: 360, child: MarketEmpty(icon: Icons.receipt_long_outlined, title: 'market_no_orders_$t'.tr,
                          body: _selling ? 'market_no_orders_seller_body'.tr : 'market_no_orders_buyer_body'.tr)),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _OrderRow(order: list[i], onBack: _load),
                  );
                }),
              ),
          ])),
        ]),
      );
    });
  }
}

/// The seller's quick switch, and what came in today.
class _TakingOrders extends StatelessWidget {
  const _TakingOrders();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<MarketController>(builder: (market) {
      final shop = market.myShop;
      if (shop == null) return const SizedBox();
      return Container(
        color: theme.cardColor,
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 8, Dimensions.paddingSizeDefault, 10),
        child: Column(children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('market_taking_orders'.tr, style: textSemiBold.copyWith(color: textColor)),
              Text('market_taking_orders_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ])),
            GetBuilder<MarketOrderController>(builder: (c) => Switch(
              value: shop.takingOrdersSwitch,
              onChanged: c.acting ? null : (on) => c.saveSettings({'taking_orders': on ? 1 : 0},
                  done: on ? 'market_taking_orders_on' : 'market_taking_orders_off'),
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _Stat(value: '${shop.todayOrders}', label: 'market_today_orders'.tr),
            _Stat(value: PriceConverter.convertPrice(shop.todayConfirmed), label: 'market_today_confirmed'.tr),
            _Stat(value: shop.replyMinutes == null ? '-' : marketMinutes(shop.replyMinutes!), label: 'market_avg_reply'.tr),
          ]),
        ]),
      );
    });
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        FittedBox(child: Text(value, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color))),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
      ]),
    ));
  }
}

class _OrderRow extends StatelessWidget {
  final MarketOrder order;
  final VoidCallback onBack;
  const _OrderRow({required this.order, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final o = order;
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Get.to(() => MarketOrderScreen(orderId: o.id));
          onBack();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.hintColor.withValues(alpha: 0.12))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            o.photo != null
                ? ImageWidget(image: o.photo!, width: 54, height: 54, radius: 10, fit: BoxFit.cover)
                : MarketShopAvatar(name: o.otherName, logo: o.shop?.logo, size: 54),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(o.otherName, maxLines: 1, overflow: TextOverflow.ellipsis, style: textBold.copyWith(color: textColor))),
                MarketOrderTag(order: o),
              ]),
              const SizedBox(height: 2),
              Text('${o.code} · ${marketPieces(o.status == MarketOrder.requested ? o.pieces : o.piecesConfirmed)} · ${PriceConverter.convertPrice(o.total)}',
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              Text(o.summary, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor)),
              if (o.deadline != null) ...[
                const SizedBox(height: 6),
                MarketCountdown(until: o.deadline, prefix: '${(o.isSeller ? 'market_answer_in' : 'market_left_to_agree').tr} '),
              ],
              if (o.canReview) Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('market_rate_shop'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
              ),
            ])),
          ]),
        ),
      ),
    );
  }
}
