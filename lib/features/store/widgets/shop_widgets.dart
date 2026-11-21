import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_model.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_checkout_screen.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Shops and supermarkets in Food & Shops: aisles, product cards, the product
/// sheet and the basket bar. Restaurants keep their menu list.

const double shopRadius = 10;

/// An aisle's icon and colour, from its name (English or French). Unknown names get a basket.
({IconData icon, Color color}) aisleStyle(String name) {
  final n = name.toLowerCase();
  bool has(List<String> words) => words.any(n.contains);
  if (has(['drink', 'boisson', 'water', 'eau', 'juice', 'jus', 'soda'])) return (icon: Icons.local_drink_rounded, color: const Color(0xFF0284C7));
  if (has(['beer', 'bière', 'biere', 'wine', 'vin', 'alcohol', 'alcool', 'spirit'])) return (icon: Icons.wine_bar_rounded, color: const Color(0xFF9333EA));
  if (has(['breakfast', 'petit', 'déjeuner', 'cereal', 'céréale', 'coffee', 'café', 'tea', 'thé'])) return (icon: Icons.free_breakfast_rounded, color: const Color(0xFFB45309));
  if (has(['bread', 'pain', 'bakery', 'boulangerie', 'pastr', 'pâtisserie', 'cake'])) return (icon: Icons.bakery_dining_rounded, color: const Color(0xFFD97706));
  if (has(['fruit', 'vegetable', 'légume', 'legume', 'fresh', 'frais'])) return (icon: Icons.eco_rounded, color: const Color(0xFF16A34A));
  if (has(['meat', 'viande', 'fish', 'poisson', 'chicken', 'poulet', 'butcher'])) return (icon: Icons.set_meal_rounded, color: const Color(0xFFDC2626));
  if (has(['dairy', 'lait', 'milk', 'cheese', 'fromage', 'yog', 'egg', 'oeuf', 'œuf'])) return (icon: Icons.egg_alt_rounded, color: const Color(0xFFCA8A04));
  if (has(['frozen', 'surgel', 'ice', 'glace'])) return (icon: Icons.ac_unit_rounded, color: const Color(0xFF0891B2));
  if (has(['snack', 'sweet', 'sucre', 'biscuit', 'candy', 'bonbon', 'chocolat'])) return (icon: Icons.cookie_rounded, color: const Color(0xFFEA580C));
  if (has(['baby', 'bébé', 'bebe', 'kid', 'enfant'])) return (icon: Icons.child_care_rounded, color: const Color(0xFFDB2777));
  if (has(['personal', 'beauty', 'beauté', 'hygien', 'care', 'soin', 'cosmet'])) return (icon: Icons.spa_rounded, color: const Color(0xFFC026D3));
  if (has(['household', 'ménage', 'menage', 'clean', 'entretien', 'home', 'maison', 'laundry'])) return (icon: Icons.cleaning_services_rounded, color: const Color(0xFF0D9488));
  if (has(['staple', 'grocer', 'épicerie', 'epicerie', 'food', 'rice', 'riz', 'pasta', 'oil', 'huile', 'aliment'])) return (icon: Icons.rice_bowl_rounded, color: const Color(0xFF65A30D));
  if (has(['phone', 'electr', 'tech', 'gadget'])) return (icon: Icons.devices_rounded, color: const Color(0xFF475569));
  if (has(['stationer', 'school', 'école', 'book', 'livre'])) return (icon: Icons.menu_book_rounded, color: const Color(0xFF4F46E5));
  return (icon: Icons.shopping_basket_rounded, color: const Color(0xFF15803D));
}

/// Adds one to the basket; from another store it asks first (one store per order).
void addToBasket(BuildContext context, MenuItem item) {
  final StoreController controller = Get.find<StoreController>();
  if (!controller.needsCartSwitch(controller.store!.id!)) {
    controller.addItem(item);
    return;
  }
  Get.dialog(AlertDialog(
    title: Text('start_new_cart'.tr),
    content: Text('start_new_cart_hint'.tr),
    actions: [
      TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
      TextButton(
        onPressed: () {
          Get.back();
          controller.clearCart();
          controller.addItem(item);
        },
        child: Text('start_new_cart_confirm'.tr, style: TextStyle(color: Theme.of(context).primaryColor)),
      ),
    ],
  ));
}

/// The product picture, or its aisle's icon on the aisle's colour.
class ShopProductImage extends StatelessWidget {
  final MenuItem item;
  final String aisle;
  final double iconSize;
  const ShopProductImage({super.key, required this.item, required this.aisle, this.iconSize = 40});

  @override
  Widget build(BuildContext context) {
    final style = aisleStyle(aisle);
    if (item.image != null && item.image!.isNotEmpty) return ImageWidget(image: item.image!, fit: BoxFit.cover);
    return Container(
      color: style.color.withValues(alpha: Get.isDarkMode ? 0.22 : 0.1),
      alignment: Alignment.center,
      child: Icon(style.icon, size: iconSize, color: style.color.withValues(alpha: 0.75)),
    );
  }
}

/// A product on a shelf: picture, name, price, and "+" that becomes − 2 +.
class ShopProductCard extends StatelessWidget {
  final MenuItem item;
  final String aisle;
  final bool storeOpen;
  final double? width;
  const ShopProductCard({super.key, required this.item, required this.aisle, required this.storeOpen, this.width});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final StoreController controller = Get.find<StoreController>();
    final int qty = controller.cartStoreId == controller.store?.id ? controller.quantityOf(item.id) : 0;
    final bool canAdd = storeOpen && item.isAvailable;
    final String? note = item.unavailableNote;
    return SizedBox(
      width: width,
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(shopRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => ShopProductSheet.show(item, aisle, storeOpen),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(shopRadius),
              border: Border.all(color: qty > 0 ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.18), width: qty > 0 ? 1.5 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AspectRatio(
                aspectRatio: 1.15,
                child: Stack(fit: StackFit.expand, children: [
                  Opacity(opacity: item.isAvailable ? 1 : 0.45, child: ShopProductImage(item: item, aisle: aisle)),
                  if (note != null)
                    Positioned(left: 6, top: 6, right: 6, child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(4)),
                        child: Text(note, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white)),
                      ),
                    )),
                  Positioned(right: 6, bottom: 6, child: _AddControl(item: item, qty: qty, enabled: canAdd)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(PriceConverter.convertPrice(item.price),
                      style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
                  const SizedBox(height: 2),
                  Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, height: 1.25, color: theme.textTheme.bodyMedium?.color)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "+" on the picture; once in the basket, a small − n + on white.
class _AddControl extends StatelessWidget {
  final MenuItem item;
  final int qty;
  final bool enabled;
  const _AddControl({required this.item, required this.qty, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final StoreController controller = Get.find<StoreController>();
    Widget round(IconData icon, VoidCallback? onTap, String label, {bool filled = false}) => Semantics(
          button: true,
          label: label,
          child: Material(
            color: filled ? (onTap == null ? theme.disabledColor : theme.primaryColor) : Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 20, color: filled ? Colors.white : theme.primaryColor)),
            ),
          ),
        );
    if (qty == 0) {
      return Material(
        elevation: 2,
        shape: const CircleBorder(),
        color: Colors.transparent,
        child: round(Icons.add_rounded, enabled ? () => addToBasket(context, item) : null, '${'add'.tr} ${item.name}', filled: true),
      );
    }
    return Material(
      elevation: 2,
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(20),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        round(Icons.remove_rounded, () => controller.removeItem(item.id), '${'remove'.tr} ${item.name}'),
        Text('$qty', style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.primaryColor)),
        round(Icons.add_rounded, enabled ? () => addToBasket(context, item) : null, '${'add'.tr} ${item.name}'),
      ]),
    );
  }
}

/// A product, bigger: picture, aisle, description, price, and how many.
class ShopProductSheet extends StatelessWidget {
  final MenuItem item;
  final String aisle;
  final bool storeOpen;
  const ShopProductSheet({super.key, required this.item, required this.aisle, required this.storeOpen});

  static void show(MenuItem item, String aisle, bool storeOpen) => showModalBottomSheet(
        context: Get.context!,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Get.theme.cardColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(shopRadius))),
        builder: (_) => ShopProductSheet(item: item, aisle: aisle, storeOpen: storeOpen),
      );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GetBuilder<StoreController>(builder: (controller) {
      final int qty = controller.cartStoreId == controller.store?.id ? controller.quantityOf(item.id) : 0;
      final bool canAdd = storeOpen && item.isAvailable;
      final style = aisleStyle(aisle);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          ClipRRect(
            borderRadius: BorderRadius.circular(shopRadius),
            child: SizedBox(height: 220, width: double.infinity, child: ShopProductImage(item: item, aisle: aisle, iconSize: 72)),
          ),
          const SizedBox(height: Dimensions.paddingSize),
          Row(children: [
            Icon(style.icon, size: 16, color: style.color),
            const SizedBox(width: 4),
            Text(aisle, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: style.color)),
          ]),
          const SizedBox(height: 4),
          Text(item.name, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 4),
          Text(PriceConverter.convertPrice(item.price), style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.primaryColor)),
          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text(item.description!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, height: 1.4, color: theme.textTheme.bodyMedium?.color)),
          ],
          if (item.unavailableNote != null) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text(item.unavailableNote!, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
          ] else if (!storeOpen) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text('store_closed_browse_only'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ],
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Row(children: [
            if (qty > 0) ...[
              Container(
                decoration: BoxDecoration(border: Border.all(color: theme.primaryColor), borderRadius: BorderRadius.circular(shopRadius)),
                child: Row(children: [
                  IconButton(onPressed: () => controller.removeItem(item.id), icon: Icon(Icons.remove_rounded, color: theme.primaryColor), tooltip: 'remove'.tr),
                  Text('$qty', style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.primaryColor)),
                  IconButton(onPressed: canAdd ? () => addToBasket(context, item) : null, icon: Icon(Icons.add_rounded, color: theme.primaryColor), tooltip: 'add'.tr),
                ]),
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
            ],
            Expanded(child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: qty > 0 ? () => Navigator.of(context).pop() : (canAdd ? () => addToBasket(context, item) : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shopRadius)),
                ),
                child: Text(
                  qty > 0 ? 'shop_in_basket_total'.trParams({'total': PriceConverter.convertPrice(item.price * qty)}) : 'shop_add_to_basket'.tr,
                  style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: Colors.white),
                ),
              ),
            )),
          ]),
        ]),
      );
    });
  }
}

/// The basket at the bottom: how many things and the total, to checkout.
class ShopBasketBar extends StatelessWidget {
  const ShopBasketBar({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GetBuilder<StoreController>(builder: (c) {
      if (c.cartIsEmpty || c.cartStoreId != c.store?.id) return const SizedBox.shrink();
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall),
          child: Material(
            color: theme.primaryColor,
            elevation: 6,
            borderRadius: BorderRadius.circular(shopRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(shopRadius),
              onTap: () => Get.to(() => const StoreCheckoutScreen()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(children: [
                  const Icon(Icons.shopping_basket_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c.cartCount == 1 ? 'shop_basket_one'.tr : 'shop_basket_count'.trParams({'n': '${c.cartCount}'}),
                      style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeDefault))),
                  Text(PriceConverter.convertPrice(c.cartSubtotal), style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeLarge)),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ]),
              ),
            ),
          ),
        ),
      );
    });
  }
}
