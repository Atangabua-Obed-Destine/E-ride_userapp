import 'package:image_picker/image_picker.dart';

abstract class MarketRepositoryInterface {
  Future<dynamic> getMeta();
  Future<dynamic> getFeed(Map<String, dynamic> query, int offset);
  Future<dynamic> getTagSuggestions(Map<String, dynamic> query);
  Future<dynamic> getShop(String slug);
  Future<dynamic> getItem(String code);
  Future<dynamic> follow(String slug, bool on, bool? notify);
  Future<dynamic> block(String slug, bool on);
  Future<dynamic> reportItem(String code, String reason, String? note, bool block);
  Future<dynamic> reportShop(String slug, String reason, String? note, bool block);
  Future<dynamic> claimReferral(String target);

  Future<dynamic> getMyShop();
  Future<dynamic> saveShop(Map<String, String> fields, XFile? logo, {XFile? shopfront});
  Future<dynamic> getVenues({double? lat, double? lng});
  Future<dynamic> getVenue(String slug, {String query = '', bool verifiedOnly = false, String? block, String? building});
  Future<dynamic> requestVerification();
  Future<dynamic> createItem(Map<String, String> fields, List<XFile> photos, List<XFile> previews);
  Future<dynamic> updateItem(String code, Map<String, String> fields, List<XFile> photos, List<int> removePhotoIds, List<XFile> previews);
  Future<dynamic> setSoldOut(String code, bool soldOut);
  Future<dynamic> deleteItem(String code);

  Future<dynamic> getChats();
  Future<dynamic> startChat(String code);
  Future<dynamic> getMessages(String chatId, String? after);
  Future<dynamic> sendMessage(String chatId, Map<String, String> fields, XFile? photo);
  Future<dynamic> blockBuyer(String chatId, bool on);

  Future<dynamic> placeOrder(Map<String, dynamic> body);
  Future<dynamic> getOrders(String role, String tab, int offset);
  Future<dynamic> getOrder(String id);
  Future<dynamic> respondOrder(String id, List<Map<String, dynamic>> lines);
  Future<dynamic> declineOrder(String id, String reason, String? note, bool soldOut);
  Future<dynamic> agreeOrder(String id);
  Future<dynamic> cancelOrder(String id, String? reason);
  Future<dynamic> readyOrder(String id);
  Future<dynamic> attachTrip(String id, String tripId);
  Future<dynamic> completeOrder(String id, String code);
  Future<dynamic> reviewOrder(String id, int stars, List<String> tags, String? comment);
  Future<dynamic> saveOrderSettings(Map<String, dynamic> body);
  Future<dynamic> getReviews(String slug);

  Future<dynamic> bid(String code, double amount);
  Future<dynamic> getBids(String code);
  Future<dynamic> auctionOfferNext(String code);
  Future<dynamic> auctionAnswer(String code, bool accept);
  Future<dynamic> auctionRelist(String code, int days);
  Future<dynamic> paymentArranged(String orderId);
  Future<dynamic> noShow(String orderId);

  Future<dynamic> getSlots(String code, String? date, String? ignore);
  Future<dynamic> book(String code, Map<String, dynamic> body);
  Future<dynamic> requestQuote(String code, Map<String, String> fields, List<XFile> photos);
  Future<dynamic> getBookings(String role, String tab, String? date);
  Future<dynamic> getBooking(String id);
  Future<dynamic> bookingAction(String id, String action, Map<String, dynamic> body);
  Future<dynamic> saveServiceSettings(Map<String, dynamic> body);
}
