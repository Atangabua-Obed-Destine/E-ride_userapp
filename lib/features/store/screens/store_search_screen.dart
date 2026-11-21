import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/assistant/screens/assistant_screen.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_model.dart';
import 'package:ride_sharing_user_app/features/store/domain/services/store_service_interface.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_menu_screen.dart';
import 'package:ride_sharing_user_app/features/store/widgets/shop_widgets.dart';
import 'package:ride_sharing_user_app/features/store/widgets/store_widgets.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Search every store at once: "rice" shows each store that has it, with the products.
class StoreSearchScreen extends StatefulWidget {
  final String? initialQuery;
  const StoreSearchScreen({super.key, this.initialQuery});

  @override
  State<StoreSearchScreen> createState() => _StoreSearchScreenState();
}

class _StoreSearchScreenState extends State<StoreSearchScreen> {
  late final TextEditingController _search = TextEditingController(text: widget.initialQuery ?? '');
  Timer? _debounce;
  bool _loading = false;
  String _searched = '';
  List<StoreSearchGroup>? _results;

  static const List<String> _ideas = ['rice', 'water', 'chicken', 'bread', 'soap', 'pizza'];

  @override
  void initState() {
    super.initState();
    if ((widget.initialQuery ?? '').trim().length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run(widget.initialQuery!.trim()));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _run(v.trim()));
  }

  Future<void> _run(String q) async {
    if (q.length < 2) {
      setState(() {
        _results = null;
        _searched = '';
      });
      return;
    }
    setState(() => _loading = true);
    final here = Get.find<StoreController>().here;
    final Response r = await Get.find<StoreServiceInterface>().searchStores(q, latitude: here.lat, longitude: here.lng);
    if (!mounted || _search.text.trim() != q) return;
    setState(() {
      _loading = false;
      _searched = q;
      _results = r.statusCode == 200 && r.body is Map
          ? (((r.body['data'] ?? {})['results'] as List?) ?? []).whereType<Map>().map((e) => StoreSearchGroup.fromJson(Map<String, dynamic>.from(e))).toList()
          : [];
    });
  }

  void _open(StoreModel store, {String? query}) {
    final StoreController c = Get.find<StoreController>();
    c.openStore(store);
    Get.to(() => StoreMenuScreen(query: query));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.cardColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: theme.textTheme.bodyLarge?.color,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: Dimensions.paddingSizeDefault),
          child: TextField(
            controller: _search,
            autofocus: (widget.initialQuery ?? '').isEmpty,
            onChanged: _changed,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => _run(v.trim()),
            decoration: InputDecoration(
              hintText: 'shop_search_everything'.tr,
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: theme.hintColor.withValues(alpha: 0.08),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(shopRadius), borderSide: BorderSide.none),
            ),
          ),
        ),
      ),
      body: _loading && _results == null
          ? const Center(child: CircularProgressIndicator())
          : _results == null
              ? _Ideas(ideas: _ideas, onPick: (q) {
                  _search.text = q;
                  _run(q);
                })
              : _results!.isEmpty
                  ? _Nothing(query: _searched)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 40),
                      itemCount: _results!.length + (_loading ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i >= _results!.length) return const LinearProgressIndicator(minHeight: 2);
                        final g = _results![i];
                        return _Group(group: g, onOpen: () => _open(g.store, query: g.items.isNotEmpty ? _searched : null));
                      },
                    ),
    );
  }
}

/// One store and what it has for the search.
class _Group extends StatelessWidget {
  final StoreSearchGroup group;
  final VoidCallback onOpen;
  const _Group({required this.group, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final StoreModel s = group.store;
    return Padding(
      padding: const EdgeInsets.only(top: Dimensions.paddingSizeDefault),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: 6),
            child: Row(children: [
              StoreLogo(url: s.logo, size: 40, isShop: s.isShop),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name ?? '', style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
                Text([
                  s.openNow ? 'open_now'.tr : (s.opensAt != null ? '${'closed_opens_at'.tr} ${s.opensAt}' : 'closed_now'.tr),
                  if (s.distanceKm != null) '${s.distanceKm!.toStringAsFixed(1)} km',
                  if (group.count > 0) 'shop_n_matches'.trParams({'n': '${group.count}'}),
                ].join('  ·  '), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              ])),
              Text('shop_open_store'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
              Icon(Icons.chevron_right_rounded, color: theme.primaryColor),
            ]),
          ),
        ),
        if (group.items.isNotEmpty)
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
              itemCount: group.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: Dimensions.paddingSizeSmall),
              itemBuilder: (_, i) {
                final MenuItem it = group.items[i];
                final String aisle = group.sections[it.id] ?? '';
                return SizedBox(
                  width: 124,
                  child: Material(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(shopRadius),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onOpen,
                      child: Container(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(shopRadius), border: Border.all(color: theme.hintColor.withValues(alpha: 0.18))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(height: 92, width: double.infinity, child: ShopProductImage(item: it, aisle: aisle, iconSize: 30)),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(PriceConverter.convertPrice(it.price), style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
                              Text(it.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: theme.textTheme.bodyMedium?.color)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Divider(height: 1, color: theme.hintColor.withValues(alpha: 0.12)),
      ]),
    );
  }
}

class _Ideas extends StatelessWidget {
  final List<String> ideas;
  final ValueChanged<String> onPick;
  const _Ideas({required this.ideas, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('shop_search_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final q in ideas)
            ActionChip(
              avatar: const Icon(Icons.search_rounded, size: 16),
              label: Text(q),
              onPressed: () => onPick(q),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
        ]),
      ]),
    );
  }
}

class _Nothing extends StatelessWidget {
  final String query;
  const _Nothing({required this.query});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
      child: Column(children: [
        Icon(Icons.search_off_rounded, size: 52, color: theme.hintColor.withValues(alpha: 0.6)),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Text('shop_nothing_anywhere'.trParams({'query': query}), textAlign: TextAlign.center,
            style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyMedium?.color)),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        OutlinedButton.icon(
          onPressed: () => Get.to(() => AssistantScreen(question: query)),
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text('shop_ask_eride'.tr),
          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shopRadius))),
        ),
      ]),
    );
  }
}
