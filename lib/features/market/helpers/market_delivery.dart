import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_chat_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/screens/parcel_screen.dart';

/// "Send with E-Ride": the seller books the parcel from a chat's delivery point or from an
/// order. It opens filled in (sender at the shop's pickup point, the buyer as receiver);
/// the seller pays the deposit, and the admin setting says who pays the rest of the fare.
/// The booked parcel is posted back to the chat, or attached to the order.
Future<void> startMarketDelivery({
  String? chatId,
  String? orderId,
  required double lat,
  required double lng,
  String? address,
  required String receiverName,
  String? receiverPhone,
}) async {
  final market = Get.find<MarketController>();
  final meta = await market.loadMeta(force: true);
  if (market.myShop == null) await market.loadMyShop();
  final shop = market.myShop ?? meta?.myShop;
  final String payer = meta?.deliveryPayer ?? 'buyer';
  Get.find<MarketChatController>().deliveryStarted(chatId, lat, lng, orderId: orderId);
  Get.to(() => ParcelScreen(prefill: ParcelPrefill(
        sender: shop?.pickupLat != null && shop?.pickupLng != null
            ? Address(latitude: shop!.pickupLat, longitude: shop.pickupLng, address: shop.pickupAddress ?? shop.area ?? shop.name)
            : null,
        receiver: Address(latitude: lat, longitude: lng, address: address ?? ''),
        receiverName: receiverName,
        receiverPhone: receiverPhone,
        payReceiver: payer == 'buyer' ? true : (payer == 'seller' ? false : null),
      )));
}
