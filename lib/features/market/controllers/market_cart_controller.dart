import 'dart:convert';

import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The E-Ride Market cart, kept on the phone. Grouped by shop: each shop gets its own
/// order request. The server checks stock and prices again when the order is sent.
class MarketCartController extends GetxController implements GetxService {
  static const String _key = 'market_cart';

  final List<MarketCartLine> lines = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw != null) {
      try {
        lines
          ..clear()
          ..addAll([for (final j in jsonDecode(raw) as List) MarketCartLine.fromJson(Map<String, dynamic>.from(j))]);
      } catch (_) {}
    }
    update();
  }

  Future<void> _save() async {
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode([for (final l in lines) l.toJson()]));
    update();
  }

  /// Adds a choice (or more of it). Returns the quantity now in the cart.
  Future<int> add(MarketCartLine line) async {
    await load();
    final i = lines.indexWhere((l) => l.key == line.key);
    if (i >= 0) {
      lines[i].qty = (lines[i].qty + line.qty).clamp(1, line.maxQty);
      await _save();
      return lines[i].qty;
    }
    line.qty = line.qty.clamp(1, line.maxQty);
    lines.add(line);
    await _save();
    return line.qty;
  }

  Future<void> setQty(MarketCartLine line, int qty) async {
    if (qty < 1) return remove(line);
    line.qty = qty.clamp(1, line.maxQty);
    await _save();
  }

  Future<void> remove(MarketCartLine line) async {
    lines.removeWhere((l) => l.key == line.key);
    await _save();
  }

  Future<void> clearShop(String slug) async {
    lines.removeWhere((l) => l.shopSlug == slug);
    await _save();
  }

  /// Lines per shop, in the order shops were first added.
  Map<String, List<MarketCartLine>> get byShop {
    final out = <String, List<MarketCartLine>>{};
    for (final l in lines) {
      out.putIfAbsent(l.shopSlug, () => []).add(l);
    }
    return out;
  }

  List<MarketCartLine> shopLines(String slug) => lines.where((l) => l.shopSlug == slug).toList();

  /// Every choice of one item in the cart.
  List<MarketCartLine> itemLines(String code) => lines.where((l) => l.itemCode == code).toList();

  /// Pieces of one item in the cart, all choices together.
  int itemPieces(String code) => lines.where((l) => l.itemCode == code).fold(0, (n, l) => n + l.qty);

  /// Pieces of one choice (colour and size) of an item in the cart.
  int choicePieces(String code, String? colour, String? size) =>
      lines.where((l) => l.itemCode == code && l.colour == colour && l.size == size).fold(0, (n, l) => n + l.qty);

  int get count => lines.length;

  int piecesOf(String slug) => shopLines(slug).fold(0, (n, l) => n + l.qty);

  /// The price of one piece of [line]: wholesale once the pieces of that item in this shop's cart reach the minimum.
  double unitPrice(MarketCartLine line) {
    final pieces = lines.where((l) => l.shopSlug == line.shopSlug && l.itemCode == line.itemCode).fold(0, (n, l) => n + l.qty);
    final w = line.wholesalePrice;
    final min = line.wholesaleMin;
    return w != null && min != null && pieces >= min && w < line.price ? w : line.price;
  }

  bool isWholesale(MarketCartLine line) => unitPrice(line) < line.price;

  double subtotal(String slug) => shopLines(slug).fold(0.0, (t, l) => t + unitPrice(l) * l.qty);

  /// The lines to send for a shop.
  List<Map<String, dynamic>> orderLines(String slug) => [
        for (final l in shopLines(slug)) {'item': l.itemCode, if (l.colour != null) 'colour': l.colour, if (l.size != null) 'size': l.size, 'qty': l.qty},
      ];
}
