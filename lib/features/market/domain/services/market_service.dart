import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/features/market/domain/repositories/market_repository_interface.dart';
import 'package:ride_sharing_user_app/features/market/domain/services/market_service_interface.dart';

class MarketService implements MarketServiceInterface {
  final MarketRepositoryInterface marketRepositoryInterface;
  MarketService({required this.marketRepositoryInterface});

  @override
  Future<dynamic> getMeta() => marketRepositoryInterface.getMeta();

  @override
  Future<dynamic> getFeed(Map<String, dynamic> query, int offset) => marketRepositoryInterface.getFeed(query, offset);

  @override
  Future<dynamic> getTagSuggestions(Map<String, dynamic> query) => marketRepositoryInterface.getTagSuggestions(query);

  @override
  Future<dynamic> getShop(String slug) => marketRepositoryInterface.getShop(slug);

  @override
  Future<dynamic> getItem(String code) => marketRepositoryInterface.getItem(code);

  @override
  Future<dynamic> follow(String slug, bool on, bool? notify) => marketRepositoryInterface.follow(slug, on, notify);

  @override
  Future<dynamic> block(String slug, bool on) => marketRepositoryInterface.block(slug, on);

  @override
  Future<dynamic> reportItem(String code, String reason, String? note, bool block) => marketRepositoryInterface.reportItem(code, reason, note, block);

  @override
  Future<dynamic> reportShop(String slug, String reason, String? note, bool block) => marketRepositoryInterface.reportShop(slug, reason, note, block);

  @override
  Future<dynamic> claimReferral(String target) => marketRepositoryInterface.claimReferral(target);

  @override
  Future<dynamic> getMyShop() => marketRepositoryInterface.getMyShop();

  @override
  Future<dynamic> saveShop(Map<String, String> fields, XFile? logo, {XFile? shopfront}) => marketRepositoryInterface.saveShop(fields, logo, shopfront: shopfront);

  @override
  Future<dynamic> getVenues({double? lat, double? lng}) => marketRepositoryInterface.getVenues(lat: lat, lng: lng);

  @override
  Future<dynamic> getVenue(String slug, {String query = '', bool verifiedOnly = false, String? block, String? building}) =>
      marketRepositoryInterface.getVenue(slug, query: query, verifiedOnly: verifiedOnly, block: block, building: building);

  @override
  Future<dynamic> requestVerification() => marketRepositoryInterface.requestVerification();

  @override
  Future<dynamic> createItem(Map<String, String> fields, List<XFile> photos, List<XFile> previews) => marketRepositoryInterface.createItem(fields, photos, previews);

  @override
  Future<dynamic> updateItem(String code, Map<String, String> fields, List<XFile> photos, List<int> removePhotoIds, List<XFile> previews) => marketRepositoryInterface.updateItem(code, fields, photos, removePhotoIds, previews);

  @override
  Future<dynamic> setSoldOut(String code, bool soldOut) => marketRepositoryInterface.setSoldOut(code, soldOut);

  @override
  Future<dynamic> deleteItem(String code) => marketRepositoryInterface.deleteItem(code);

  @override
  Future<dynamic> getChats() => marketRepositoryInterface.getChats();

  @override
  Future<dynamic> startChat(String code) => marketRepositoryInterface.startChat(code);

  @override
  Future<dynamic> getMessages(String chatId, String? after) => marketRepositoryInterface.getMessages(chatId, after);

  @override
  Future<dynamic> sendMessage(String chatId, Map<String, String> fields, XFile? photo) => marketRepositoryInterface.sendMessage(chatId, fields, photo);

  @override
  Future<dynamic> blockBuyer(String chatId, bool on) => marketRepositoryInterface.blockBuyer(chatId, on);

  @override
  Future<dynamic> placeOrder(Map<String, dynamic> body) => marketRepositoryInterface.placeOrder(body);

  @override
  Future<dynamic> getOrders(String role, String tab, int offset) => marketRepositoryInterface.getOrders(role, tab, offset);

  @override
  Future<dynamic> getOrder(String id) => marketRepositoryInterface.getOrder(id);

  @override
  Future<dynamic> respondOrder(String id, List<Map<String, dynamic>> lines) => marketRepositoryInterface.respondOrder(id, lines);

  @override
  Future<dynamic> declineOrder(String id, String reason, String? note, bool soldOut) => marketRepositoryInterface.declineOrder(id, reason, note, soldOut);

  @override
  Future<dynamic> agreeOrder(String id) => marketRepositoryInterface.agreeOrder(id);

  @override
  Future<dynamic> cancelOrder(String id, String? reason) => marketRepositoryInterface.cancelOrder(id, reason);

  @override
  Future<dynamic> readyOrder(String id) => marketRepositoryInterface.readyOrder(id);

  @override
  Future<dynamic> attachTrip(String id, String tripId) => marketRepositoryInterface.attachTrip(id, tripId);

  @override
  Future<dynamic> completeOrder(String id, String code) => marketRepositoryInterface.completeOrder(id, code);

  @override
  Future<dynamic> reviewOrder(String id, int stars, List<String> tags, String? comment) => marketRepositoryInterface.reviewOrder(id, stars, tags, comment);

  @override
  Future<dynamic> saveOrderSettings(Map<String, dynamic> body) => marketRepositoryInterface.saveOrderSettings(body);

  @override
  Future<dynamic> getReviews(String slug) => marketRepositoryInterface.getReviews(slug);

  @override
  Future<dynamic> bid(String code, double amount) => marketRepositoryInterface.bid(code, amount);

  @override
  Future<dynamic> getBids(String code) => marketRepositoryInterface.getBids(code);

  @override
  Future<dynamic> auctionOfferNext(String code) => marketRepositoryInterface.auctionOfferNext(code);

  @override
  Future<dynamic> auctionAnswer(String code, bool accept) => marketRepositoryInterface.auctionAnswer(code, accept);

  @override
  Future<dynamic> auctionRelist(String code, int days) => marketRepositoryInterface.auctionRelist(code, days);

  @override
  Future<dynamic> paymentArranged(String orderId) => marketRepositoryInterface.paymentArranged(orderId);

  @override
  Future<dynamic> noShow(String orderId) => marketRepositoryInterface.noShow(orderId);

  @override
  Future<dynamic> getSlots(String code, String? date, String? ignore) => marketRepositoryInterface.getSlots(code, date, ignore);

  @override
  Future<dynamic> book(String code, Map<String, dynamic> body) => marketRepositoryInterface.book(code, body);

  @override
  Future<dynamic> requestQuote(String code, Map<String, String> fields, List<XFile> photos) => marketRepositoryInterface.requestQuote(code, fields, photos);

  @override
  Future<dynamic> getBookings(String role, String tab, String? date) => marketRepositoryInterface.getBookings(role, tab, date);

  @override
  Future<dynamic> getBooking(String id) => marketRepositoryInterface.getBooking(id);

  @override
  Future<dynamic> bookingAction(String id, String action, Map<String, dynamic> body) => marketRepositoryInterface.bookingAction(id, action, body);

  @override
  Future<dynamic> saveServiceSettings(Map<String, dynamic> body) => marketRepositoryInterface.saveServiceSettings(body);
}
