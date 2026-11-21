import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_order_controller.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// How the seller takes orders: on or paused, ways to get items, ways to be paid,
/// opening hours, and a minimum order.
class MarketOrderSettingsScreen extends StatefulWidget {
  const MarketOrderSettingsScreen({super.key});

  @override
  State<MarketOrderSettingsScreen> createState() => _MarketOrderSettingsScreenState();
}

class _MarketOrderSettingsScreenState extends State<MarketOrderSettingsScreen> {
  static const _ways = ['pickup', 'eride', 'seller'];
  static const _pays = ['cash_delivery', 'momo_delivery', 'pickup', 'before'];
  bool _taking = true;
  final Set<String> _fulfilment = {};
  final Set<String> _pay = {};
  TimeOfDay? _from;
  TimeOfDay? _to;
  final TextEditingController _min = TextEditingController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final market = Get.find<MarketController>();
      if (market.myShop == null) await market.loadMyShop();
      final shop = market.myShop;
      if (shop == null || !mounted) return;
      TimeOfDay? parse(String? t) {
        if (t == null || !t.contains(':')) return null;
        final p = t.split(':');
        return TimeOfDay(hour: int.tryParse(p[0]) ?? 0, minute: int.tryParse(p[1]) ?? 0);
      }
      setState(() {
        _taking = shop.takingOrdersSwitch;
        _fulfilment.addAll(shop.fulfilment);
        _pay.addAll(shop.payMethods);
        _from = parse(shop.openFrom);
        _to = parse(shop.openTo);
        _min.text = shop.minOrder == null ? '' : shop.minOrder!.round().toString();
        _ready = true;
      });
    });
  }

  @override
  void dispose() {
    _min.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(bool from) async {
    final t = await showTimePicker(context: context, initialTime: (from ? _from : _to) ?? TimeOfDay(hour: from ? 8 : 19, minute: 0));
    if (t != null) setState(() => from ? _from = t : _to = t);
  }

  Future<void> _save() async {
    if (_fulfilment.isEmpty) return showCustomSnackBar('market_keep_one_way'.tr);
    if (_pay.isEmpty) return showCustomSnackBar('market_keep_one_pay'.tr);
    final ok = await Get.find<MarketOrderController>().saveSettings({
      'taking_orders': _taking ? 1 : 0,
      'fulfilment': _fulfilment.join(','),
      'pay_methods': _pay.join(','),
      'open_from': _from == null || _to == null ? '' : _fmt(_from!),
      'open_to': _from == null || _to == null ? '' : _fmt(_to!),
      'min_order': _min.text.trim().isEmpty ? 0 : int.tryParse(_min.text.trim()) ?? 0,
    }, done: 'market_settings_saved');
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final title = textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor);
    final verified = Get.find<MarketController>().myShop?.verified ?? false;
    return Scaffold(
      backgroundColor: theme.cardColor,
      appBar: AppBar(backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
          title: Text('market_order_settings'.tr)),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
              SwitchListTile(
                value: _taking,
                onChanged: (v) => setState(() => _taking = v),
                contentPadding: EdgeInsets.zero,
                title: Text('market_accept_orders'.tr, style: textSemiBold.copyWith(color: textColor)),
                subtitle: Text('market_accept_orders_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              ),
              const Divider(height: 28),
              Text('market_ways_get'.tr, style: title),
              for (final w in _ways)
                CheckboxListTile(
                  value: _fulfilment.contains(w),
                  onChanged: (v) => setState(() => v == true ? _fulfilment.add(w) : _fulfilment.remove(w)),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text((w == 'seller' ? 'market_way_seller_self' : 'market_fulfilment_$w').tr),
                ),
              const Divider(height: 28),
              Text('market_ways_pay'.tr, style: title),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in _pays)
                  FilterChip(
                    label: Text('market_pay_$p'.tr),
                    selected: _pay.contains(p),
                    selectedColor: theme.primaryColor.withValues(alpha: 0.12),
                    checkmarkColor: theme.primaryColor,
                    labelStyle: textMedium.copyWith(color: _pay.contains(p) ? theme.primaryColor : textColor),
                    onSelected: p == 'before' && !verified ? null : (on) => setState(() => on ? _pay.add(p) : _pay.remove(p)),
                  ),
              ]),
              const SizedBox(height: 8),
              MarketScamNotice(text: 'market_before_verified_only'.tr),
              const Divider(height: 28),
              Text('market_opening_hours'.tr, style: title),
              const SizedBox(height: 4),
              Text('market_opening_hours_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => _pick(true), child: Text(_from == null ? 'market_from'.tr : _fmt(_from!)))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => _pick(false), child: Text(_to == null ? 'market_to'.tr : _fmt(_to!)))),
                if (_from != null || _to != null)
                  IconButton(tooltip: 'market_always_open'.tr, onPressed: () => setState(() => _from = _to = null), icon: const Icon(Icons.close_rounded)),
              ]),
              const Divider(height: 28),
              Text('market_minimum_order'.tr, style: title),
              const SizedBox(height: 8),
              TextField(
                controller: _min,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                decoration: InputDecoration(hintText: 'market_no_minimum'.tr, suffixText: 'FCFA',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault))),
              ),
              const SizedBox(height: 90),
            ]),
      bottomNavigationBar: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 8, Dimensions.paddingSizeDefault, 12),
        child: GetBuilder<MarketOrderController>(builder: (c) => SizedBox(height: 52, child: FilledButton(
          onPressed: c.acting || !_ready ? null : _save,
          child: c.acting
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('market_save'.tr),
        ))),
      )),
    );
  }
}
